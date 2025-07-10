#!/bin/bash

# PostToolUse/Bash Hook

# PostToolUse/Bashで受け取るJSONの形式:
# {
#   "session_id": "...",
#   "transcript_path": "...",
#   "hook_event_name": "PostToolUse",
#   "tool_name": "Bash",
#   "tool_input": {
#     "command": "実行されたコマンド",
#     "description": "コマンドの説明（オプション）"
#   },
#   "tool_response": {
#     "stdout": "標準出力の内容",
#     "stderr": "標準エラー出力の内容",
#     "interrupted": false,  // ユーザーによる中断の有無
#     "isImage": false       // 画像出力かどうか
#   }
# }
# 
# 重要な注意点:
# - エラーが発生したコマンドではPostToolUseフックは呼ばれない（成功時のみ）


# 定数定義
readonly HOOK_TYPE="PostToolUse"
readonly TOOL_NAME="Bash"

# カレントディレクトリを取得
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリをロード
source "$HOOK_DIR/../../lib/common.sh"

# フック共通ベースをロード
source "$HOOK_DIR/../../lib/hook_base.sh"

# 評価エンジンをロード
source "$HOOK_DIR/evaluator.sh"

# メイン処理の実装
hook_main() {
    # 標準入力からJSONを読み取る
    local input=$(read_and_validate_input)
    
    # 必要な値を抽出
    local command=$(extract_json_value "$input" '.tool_input.command // empty')
    local tool_response=$(extract_json_value "$input" '.tool_response // {}')
    
    # interruptedの場合は何もしない
    local interrupted=$(extract_json_value "$tool_response" '.interrupted // false')
    if [ "$interrupted" = "true" ]; then
        echo "$EMPTY_RESULT"
        exit 0
    fi
    
    # 設定ファイルを読み込む（PostToolUse用）
    local claude_config_dir=$(find_claude_config_dir)
    local global_rules=""
    local config="{}"
    
    # グローバルルールを読み込む
    if [ -n "$claude_config_dir" ]; then
        global_rules="$claude_config_dir/$RULES_FILE_NAME"
        if [ -f "$global_rules" ]; then
            config=$(cat "$global_rules" 2>/dev/null | jq --arg hook_type "$HOOK_TYPE" --arg tool_name "$TOOL_NAME" '.[$hook_type][$tool_name] // {}')
        fi
    fi
    
    # ローカルルールを読み込む（今回は省略）
    
    # 設定が空の場合
    if [ "$config" = "{}" ] || [ -z "$config" ]; then
        echo "$EMPTY_RESULT"
        exit 0
    fi
    
    # コマンドを評価
    local result=$(evaluate_posttooluse_command "$command" "$tool_response" "$config")
    
    # 結果を出力
    echo "$result"
}

# フックを実行
run_hook