#!/bin/bash

# PostToolUse/Bash 評価エンジン
# Bashツール実行後の結果を評価し、適切なアクションを決定する
#
# PostToolUseで利用可能なマッチング条件:
# - pattern: コマンド引数に対する正規表現パターン
# - output_pattern: stdoutに対する正規表現パターン
# - error_pattern: stderrに対する正規表現パターン
#
# 利用可能なアクション:
# - log: コマンドと結果をログファイルに記録
# - warn/error: 警告メッセージを表示（フックがexit 1で終了）
# - block: ブロック（ツールは既に実行済みなので効果は限定的）
# - ignore: 何もしない（デフォルト）

# カレントディレクトリを取得
EVALUATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリをロード
source "$EVALUATOR_DIR/../../lib/common.sh"

# 定数定義
readonly ACTION_BLOCK="block"
readonly ACTION_LOG="log"
readonly ACTION_WARN="warn"
readonly ACTION_IGNORE="ignore"
readonly ACTION_ERROR="error"

# ログファイルのパス（設定ファイルと同じディレクトリ）
get_log_file_path() {
    local config_dir=$(find_claude_config_dir)
    if [ -n "$config_dir" ]; then
        echo "$config_dir/hooks-command.log"
    else
        echo "$HOME/.claude/hooks-command.log"
    fi
}
LOG_FILE="${CLAUDE_HOOKS_LOG:-$(get_log_file_path)}"

# アクションの優先順位を判定
# 引数: 現在のアクション, 新しいアクション
# 戻り値: 0 (新しいアクションを採用) または 1 (現在のアクションを維持)
should_update_action() {
    should_update_by_priority "$1" "$2" "$ACTION_BLOCK $ACTION_ERROR $ACTION_WARN $ACTION_LOG $ACTION_IGNORE"
}

# コマンド実行結果をログに記録
# 引数: $1=コマンド, $2=出力, $3=エラー出力
log_command_result() {
    local command="$1"
    local output="$2"
    local stderr_output="$3"
    
    # ログディレクトリを作成
    local log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir"
    
    # タイムスタンプを付けてログに記録
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "Command: $command"
        [ -n "$stderr_output" ] && [ "$stderr_output" != "empty" ] && echo "Stderr: $stderr_output"
        echo "Output:"
        echo "$output"
        echo ""
    } >> "$LOG_FILE"
}

# ルールを評価する
# 引数: $1=コマンド, $2=出力, $3=エラー出力, $4=ルール配列JSON
# 戻り値: JSON形式 {"action": "...", "reason": "..."}
evaluate_rules() {
    local parsed_cmd="$1"
    local output="$2"
    local stderr_output="$3"
    local rules="$4"
    
    local matched_action=""
    local matched_reason=""
    
    # コマンド名を取得して、引数部分のみを抽出
    local cmd_name=$(extract_command_name "$parsed_cmd")
    local cmd_args=$(extract_command_args "$parsed_cmd")
    
    # ルール配列の長さを取得
    local rules_count=$(echo "$rules" | jq 'length')
    
    for i in $(seq 0 $((rules_count - 1))); do
        local rule=$(echo "$rules" | jq ".[$i]")
        local pattern=$(echo "$rule" | jq -r '.pattern // empty')
        local output_pattern=$(echo "$rule" | jq -r '.output_pattern // empty')
        local error_pattern=$(echo "$rule" | jq -r '.error_pattern // empty')
        local action=$(echo "$rule" | jq -r '.action // "log"')
        local reason=$(echo "$rule" | jq -r '.reason // empty')
        
        # マッチング判定
        local match=true
        
        # コマンドパターンのチェック
        if [ -n "$pattern" ] && [ "$pattern" != "empty" ]; then
            if ! match_pattern "$cmd_args" "$pattern"; then
                match=false
            fi
        fi
        
        
        # 出力パターンのチェック
        if [ -n "$output_pattern" ] && [ "$output_pattern" != "empty" ]; then
            if ! match_pattern "$output" "$output_pattern"; then
                match=false
            fi
        fi
        
        # エラーパターンのチェック
        if [ -n "$error_pattern" ] && [ "$error_pattern" != "empty" ]; then
            if ! match_pattern "$stderr_output" "$error_pattern"; then
                match=false
            fi
        fi
        
        # マッチした場合
        if [ "$match" = true ]; then
            if should_update_action "$matched_action" "$action"; then
                matched_action="$action"
                matched_reason="$reason"
            fi
            
            # blockの場合は即座に終了
            if [ "$matched_action" = "$ACTION_BLOCK" ]; then
                break
            fi
        fi
    done
    
    # 結果を返す
    create_result_json "action" "$matched_action" "$matched_reason"
}

# PostToolUse コマンドを評価
# 引数: $1=コマンド, $2=tool_response JSON, $3=設定JSON
# 戻り値: JSON形式の結果
evaluate_posttooluse_command() {
    local command="$1"
    local tool_response="$2"
    local config="$3"
    
    # tool_responseから情報を抽出
    local output=$(extract_json_value "$tool_response" '.stdout // empty')
    local stderr_output=$(extract_json_value "$tool_response" '.stderr // empty')
    
    # 最終的なアクションとreason
    local final_action=""
    local final_reason=""
    
    # コマンドをパースして各コマンドをチェック
    while IFS= read -r parsed_cmd; do
        # コマンド名を抽出
        local cmd_name=$(extract_command_name "$parsed_cmd")
        
        # コマンド固有のルールを取得
        local cmd_rules=$(echo "$config" | jq -r --arg cmd "$cmd_name" '.[$cmd] // null')
        
        # ワイルドカードルールも取得
        local wildcard_rules=$(echo "$config" | jq -r '.["*"] // null')
        
        # コマンド固有のルールを評価
        if [ "$cmd_rules" != "$NULL_VALUE" ] && [ "$cmd_rules" != "null" ]; then
            local result=$(evaluate_rules "$parsed_cmd" "$output" "$stderr_output" "$cmd_rules")
            local action=$(echo "$result" | jq -r '.action // empty')
            local reason=$(echo "$result" | jq -r '.reason // empty')
            
            if [ -n "$action" ] && should_update_action "$final_action" "$action"; then
                final_action="$action"
                final_reason="$reason"
            fi
        fi
        
        # ワイルドカードルールを評価
        if [ "$wildcard_rules" != "$NULL_VALUE" ] && [ "$wildcard_rules" != "null" ]; then
            local result=$(evaluate_rules "$parsed_cmd" "$output" "$stderr_output" "$wildcard_rules")
            local action=$(echo "$result" | jq -r '.action // empty')
            local reason=$(echo "$result" | jq -r '.reason // empty')
            
            if [ -n "$action" ] && should_update_action "$final_action" "$action"; then
                final_action="$action"
                final_reason="$reason"
            fi
        fi
        
        # blockの場合は即座に終了
        if [ "$final_action" = "$ACTION_BLOCK" ]; then
            break
        fi
    done < <(parse_commands "$command")
    
    # デフォルトアクションを取得
    if [ -z "$final_action" ]; then
        final_action=$(echo "$config" | jq -r '.default_action // "ignore"')
    fi
    
    # アクションに基づいて処理
    case "$final_action" in
        "$ACTION_BLOCK")
            # ブロック (exit code 2で終了)
            echo "{\"decision\": \"block\", \"reason\": \"$final_reason\"}"
            ;;
        "$ACTION_LOG")
            # ログに記録
            log_command_result "$command" "$output" "$stderr_output"
            echo "$EMPTY_JSON"
            ;;
        "$ACTION_WARN"|"$ACTION_ERROR")
            # 警告を表示 (stderrに出力)
            echo "⚠️  $final_reason" >&2
            echo "コマンド: $command" >&2
            [ -n "$stderr_output" ] && [ "$stderr_output" != "empty" ] && echo "エラー出力: $stderr_output" >&2
            echo "$EMPTY_JSON"
            ;;
        *)
            # 無視
            echo "$EMPTY_JSON"
            ;;
    esac
}