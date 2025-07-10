#!/bin/bash

# 定数定義
readonly RULES_FILE_NAME="hooks.config.json"
readonly HOOK_TYPE="PreToolUse"
readonly TOOL_NAME="Bash"
readonly EMPTY_RESULT="{}"

# 評価エンジンをsource
source "$(dirname "$0")/evaluator.sh"

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

# ルールファイルをマージする
# 引数: なし
# 戻り値: マージされたルールJSON
merge_rules_files() {
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
            :
        fi
    fi
    
    # ローカルルールを読み込む
    if [ -f "$local_rules" ]; then
        local_json=$(cat "$local_rules" 2>/dev/null || echo "{}")
        :
    fi
    
    # 両方とも空の場合
    if [ "$global_json" = "{}" ] && [ "$local_json" = "{}" ]; then
        :
        echo "{}"
        return
    fi
    
    # 新しい構造に対応したjqマージ
    echo "$global_json" | jq -s --argjson local "$local_json" \
        --arg hook_type "$HOOK_TYPE" \
        --arg tool_name "$TOOL_NAME" '
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

# メイン処理
main() {
    # 標準入力からJSONを読み取る
    local input=$(cat)
    
    # 必要な値を抽出
    local command=$(extract_json_value "$input" '.tool_input.command // empty')
    local working_dir=$(extract_json_value "$input" '.tool_input.working_directory // empty')
    
    # コマンドが空の場合は何もしない
    if [ -z "$command" ] || [ "$command" = "empty" ]; then
        echo "$EMPTY_RESULT"
        exit 0
    fi
    
    # ルールファイルをマージして取得
    local rules_json=$(merge_rules_files)
    
    # ルールが空の場合
    if [ "$rules_json" = "{}" ] || [ -z "$rules_json" ]; then
        echo "$EMPTY_RESULT"
        exit 0
    fi
    
    # コマンドを評価
    local result=$(evaluate_bash_command "$command" "$rules_json")
    
    # 結果を出力
    echo "$result"
}

# メイン処理を実行
main