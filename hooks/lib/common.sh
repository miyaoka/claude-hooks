#!/bin/bash

# 共通ライブラリ
# PreToolUse/PostToolUse フックで共有される関数

# 定数定義
readonly RULES_FILE_NAME="hooks.config.json"
readonly EMPTY_JSON="{}"
readonly NULL_VALUE="null"

# JSONから値を安全に抽出
# 引数: JSON文字列, jqパス
# 戻り値: 抽出された値 (エラー時は空文字列)
extract_json_value() {
    local json="$1"
    local path="$2"
    echo "$json" | jq -r "$path" 2>/dev/null || echo ""
}

# Claudeの設定ディレクトリを検索する
# 引数: なし
# 戻り値: 設定ディレクトリのパス（見つからない場合は空文字列）
find_claude_config_dir() {
    # 優先順位: CLAUDE_CONFIG_DIR > ~/.config/claude > ~/.claude
    if [ -n "$CLAUDE_CONFIG_DIR" ] && [ -d "$CLAUDE_CONFIG_DIR" ]; then
        echo "$CLAUDE_CONFIG_DIR"
    elif [ -d "$HOME/.config/claude" ]; then
        echo "$HOME/.config/claude"
    elif [ -d "$HOME/.claude" ]; then
        echo "$HOME/.claude"
    else
        echo ""
    fi
}

# 設定ファイルを読み込む
# 引数: フックタイプ (PreToolUse/PostToolUse), ツール名 (Bash)
# 戻り値: マージされたルールJSON
load_config() {
    local hook_type="$1"
    local tool_name="$2"
    local local_rules=".claude/$RULES_FILE_NAME"
    local claude_config_dir=$(find_claude_config_dir)
    local global_rules=""
    local global_json="{}"
    local local_json="{}"
    
    # グローバルルールを読み込む
    if [ -n "$claude_config_dir" ]; then
        global_rules="$claude_config_dir/$RULES_FILE_NAME"
        if [ -f "$global_rules" ]; then
            global_json=$(cat "$global_rules" 2>/dev/null || echo "{}")
        fi
    fi
    
    # ローカルルールを読み込む
    if [ -f "$local_rules" ]; then
        local_json=$(cat "$local_rules" 2>/dev/null || echo "{}")
    fi
    
    # 両方とも空の場合
    if [ "$global_json" = "{}" ] && [ "$local_json" = "{}" ]; then
        echo "{}"
        return
    fi
    
    # 指定されたフックタイプとツール名のセクションをマージ
    echo "$global_json" | jq -s --argjson local "$local_json" \
        --arg hook_type "$hook_type" \
        --arg tool_name "$tool_name" '
        .[0] as $global |
        $local as $local |
        ($global[$hook_type][$tool_name] // {}) as $g |
        ($local[$hook_type][$tool_name] // {}) as $l |
        (
            ($g | keys) + ($l | keys) | unique | map(. as $cmd |
                {($cmd): (($g[$cmd] // []) + ($l[$cmd] // []))}
            ) | add
        )'
}

# 文字列の前後の空白を削除する
# 引数: 文字列
# 戻り値: トリムされた文字列
trim_string() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# クォートの状態を切り替える
# 引数: 現在の状態 (true/false の文字列)
# 戻り値: 切り替え後の状態
toggle_boolean() {
    [ "$1" = "true" ] && echo "false" || echo "true"
}

# クォートを考慮したコマンドパーサー
parse_commands() {
    local input="$1"
    local -a commands=()
    local current_command=""
    local in_single_quote=false
    local in_double_quote=false
    local escaped=false
    local i=0
    
    while [ $i -lt ${#input} ]; do
        char="${input:$i:1}"
        next_char="${input:$((i+1)):1}"
        
        if $escaped; then
            current_command+="$char"
            escaped=false
        elif [ "$char" = "\\" ] && ! $in_single_quote; then
            current_command+="$char"
            escaped=true
        elif [ "$char" = "'" ] && ! $in_double_quote && ! $escaped; then
            current_command+="$char"
            in_single_quote=$(toggle_boolean "$in_single_quote")
        elif [ "$char" = '"' ] && ! $in_single_quote && ! $escaped; then
            current_command+="$char"
            in_double_quote=$(toggle_boolean "$in_double_quote")
        elif ! $in_single_quote && ! $in_double_quote; then
            if [ "$char" = "&" ] && [ "$next_char" = "&" ]; then
                if [ -n "$current_command" ]; then
                    commands+=("$(trim_string "$current_command")")
                fi
                current_command=""
                ((i++))
            elif [ "$char" = "|" ] && [ "$next_char" = "|" ]; then
                if [ -n "$current_command" ]; then
                    commands+=("$(trim_string "$current_command")")
                fi
                current_command=""
                ((i++))
            elif [ "$char" = "|" ]; then
                if [ -n "$current_command" ]; then
                    commands+=("$(trim_string "$current_command")")
                fi
                current_command=""
            elif [ "$char" = ";" ]; then
                if [ -n "$current_command" ]; then
                    commands+=("$(trim_string "$current_command")")
                fi
                current_command=""
            else
                current_command+="$char"
            fi
        else
            current_command+="$char"
        fi
        
        ((i++))
    done
    
    if [ -n "$current_command" ]; then
        commands+=("$(trim_string "$current_command")")
    fi
    
    for cmd in "${commands[@]}"; do
        echo "$cmd"
    done
}

# コマンド名を抽出する
# 引数: コマンド文字列
# 戻り値: コマンド名
extract_command_name() {
    echo "$1" | awk '{print $1}'
}

# コマンドから引数部分のみを抽出する
# 引数: コマンド文字列
# 戻り値: 引数部分（先頭の空白は削除済み）
extract_command_args() {
    local command="$1"
    local cmd_name=$(extract_command_name "$command")
    local cmd_args="${command#$cmd_name}"
    # 先頭の空白を削除
    echo "$cmd_args" | sed 's/^[[:space:]]*//'
}

# 優先順位に基づいて値を更新すべきか判定
# 引数: $1=現在の値, $2=新しい値, $3=優先順位リスト（高い順）
# 戻り値: 0（更新すべき）または 1（更新すべきでない）
# 使用例: should_update_by_priority "$current" "$new" "block approve undefined"
should_update_by_priority() {
    local current="$1"
    local new="$2"
    local priorities="$3"
    
    # 空の場合の処理
    [ -z "$current" ] && return 0
    [ -z "$new" ] && return 1
    
    # 優先順位リストを配列に変換
    local -a priority_array=($priorities)
    
    # 新しい値の優先順位を取得
    local new_priority=-1
    local current_priority=-1
    local i
    
    for i in "${!priority_array[@]}"; do
        [ "${priority_array[$i]}" = "$new" ] && new_priority=$i
        [ "${priority_array[$i]}" = "$current" ] && current_priority=$i
    done
    
    # 優先順位が高い（数値が小さい）場合は更新
    if [ $new_priority -ne -1 ] && [ $current_priority -ne -1 ]; then
        [ $new_priority -lt $current_priority ] && return 0
    fi
    
    return 1
}