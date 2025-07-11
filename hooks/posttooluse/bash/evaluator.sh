#!/bin/bash

# PostToolUse/Bash 評価エンジン（フラット構造版）
# Bashツール実行後の結果を評価し、適切なアクションを決定する
#
# PostToolUseで利用可能なマッチング条件:
# - command: コマンド名（省略時は全コマンド）
# - args: コマンド引数に対する正規表現パターン
# - stdout: 標準出力に対する正規表現パターン
# - stderr: 標準エラー出力に対する正規表現パターン
#
# 利用可能なアクション:
# - block: 後続処理をブロック
# - log: コマンドと結果をログファイルに記録
# - (undefined): 何もしない（デフォルト）

# カレントディレクトリを取得
EVALUATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリをロード
source "$EVALUATOR_DIR/../../lib/common.sh"

# 定数定義
readonly ACTION_BLOCK="block"
readonly ACTION_LOG="log"

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
    should_update_by_priority "$1" "$2" "$ACTION_BLOCK $ACTION_LOG"
}

# コマンド実行結果をログに記録
# 引数: $1=コマンド, $2=stdout, $3=stderr
log_command_result() {
    local command="$1"
    local stdout="$2"
    local stderr="$3"
    
    # ログディレクトリを作成
    local log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir"
    
    # タイムスタンプを付けてログに記録
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "Command: $command"
        [ -n "$stderr" ] && [ "$stderr" != "empty" ] && echo "Stderr: $stderr"
        echo "Output:"
        echo "$stdout"
        echo ""
    } >> "$LOG_FILE"
}

# フラット構造のルールを評価する
# 引数: $1=コマンド, $2=stdout, $3=stderr, $4=ルール配列JSON
# 戻り値: JSON形式 {"action": "...", "reason": "..."}
evaluate_rules_flat() {
    local parsed_cmd="$1"
    local stdout="$2"
    local stderr="$3"
    local rules="$4"
    
    local final_action=""
    local final_reason=""
    
    # コマンド名と引数を抽出
    local cmd_name=$(extract_command_name "$parsed_cmd")
    local cmd_args=$(extract_command_args "$parsed_cmd")
    
    # ルール配列の長さを取得
    local rules_count=$(echo "$rules" | jq 'length')
    
    for i in $(seq 0 $((rules_count - 1))); do
        local rule=$(echo "$rules" | jq ".[$i]")
        local rule_command=$(echo "$rule" | jq -r '.command // empty')
        local rule_args=$(echo "$rule" | jq -r '.args // empty')
        local rule_stdout=$(echo "$rule" | jq -r '.stdout // empty')
        local rule_stderr=$(echo "$rule" | jq -r '.stderr // empty')
        local rule_action=$(echo "$rule" | jq -r '.action // empty')
        local rule_reason=$(echo "$rule" | jq -r '.reason // empty')
        
        # コマンド名のマッチング（commandフィールドが空の場合は全コマンドにマッチ）
        local command_matches=false
        if [ -z "$rule_command" ] || [ "$rule_command" = "$cmd_name" ]; then
            command_matches=true
        fi
        
        # コマンドがマッチした場合のみ評価を続ける
        if [ "$command_matches" = true ]; then
            local match=true
            
            # 引数パターンのチェック
            if [ -n "$rule_args" ] && [ "$rule_args" != "empty" ]; then
                if ! match_pattern "$cmd_args" "$rule_args"; then
                    match=false
                fi
            fi
            
            # stdout パターンのチェック
            if [ -n "$rule_stdout" ] && [ "$rule_stdout" != "empty" ]; then
                if ! match_pattern "$stdout" "$rule_stdout"; then
                    match=false
                fi
            fi
            
            # stderr パターンのチェック
            if [ -n "$rule_stderr" ] && [ "$rule_stderr" != "empty" ]; then
                if ! match_pattern "$stderr" "$rule_stderr"; then
                    match=false
                fi
            fi
            
            # 全条件がマッチした場合
            if [ "$match" = true ]; then
                # アクションが指定されていない場合はスキップ
                if [ -z "$rule_action" ] || [ "$rule_action" = "empty" ]; then
                    continue
                fi
                
                if should_update_action "$final_action" "$rule_action"; then
                    final_action="$rule_action"
                    final_reason="$rule_reason"
                fi
                
                # blockが見つかったら即座に終了
                if [ "$final_action" = "$ACTION_BLOCK" ]; then
                    break
                fi
            fi
        fi
    done
    
    # 結果JSONを生成
    create_result_json "action" "$final_action" "$final_reason"
}

# PostToolUse コマンドを評価
# 引数: $1=コマンド, $2=tool_response JSON, $3=ルール配列JSON
# 戻り値: JSON形式の結果
evaluate_posttooluse_command() {
    local command="$1"
    local tool_response="$2"
    local rules_array="$3"
    
    # tool_responseから情報を抽出
    local stdout=$(extract_json_value "$tool_response" '.stdout // empty')
    local stderr=$(extract_json_value "$tool_response" '.stderr // empty')
    
    # 最終的なアクションとreason
    local final_action=""
    local final_reason=""
    
    # コマンドをパースして各コマンドをチェック
    while IFS= read -r parsed_cmd; do
        # ルールを評価
        local result=$(evaluate_rules_flat "$parsed_cmd" "$stdout" "$stderr" "$rules_array")
        local action=$(echo "$result" | jq -r '.action // empty')
        local reason=$(echo "$result" | jq -r '.reason // empty')
        
        if [ -n "$action" ] && should_update_action "$final_action" "$action"; then
            final_action="$action"
            final_reason="$reason"
        fi
        
        # blockの場合は即座に終了
        if [ "$final_action" = "$ACTION_BLOCK" ]; then
            break
        fi
    done < <(parse_commands "$command")
    
    # アクションに基づいて処理
    case "$final_action" in
        "$ACTION_BLOCK")
            # ブロック (decision: block)
            echo "{\"decision\": \"block\", \"reason\": \"$final_reason\"}"
            ;;
        "$ACTION_LOG")
            # ログに記録
            log_command_result "$command" "$stdout" "$stderr"
            echo "$EMPTY_JSON"
            ;;
        *)
            # 何もしない
            echo "$EMPTY_JSON"
            ;;
    esac
}

# コマンドライン引数として実行する場合（テスト用）
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # 引数の検証
    if [ $# -ne 3 ]; then
        echo "Usage: $0 <command> <tool_response_json> <rules_file>" >&2
        exit 1
    fi
    
    command="$1"
    tool_response="$2"
    rules_file="$3"
    
    # ルールファイルを読み込んで検証
    rules_json=$(cat "$rules_file" 2>/dev/null || echo "[]")
    if ! echo "$rules_json" | jq -e . >/dev/null 2>&1; then
        error_exit "ルールファイルが無効なJSONです: $rules_file"
    fi
    
    # 評価の実行
    evaluate_posttooluse_command "$command" "$tool_response" "$rules_json"
fi