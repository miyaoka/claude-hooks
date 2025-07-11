#!/bin/bash

# PreToolUse/Bash Hook

# 定数定義
readonly HOOK_TYPE="PreToolUse"
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
    local working_dir=$(extract_json_value "$input" '.tool_input.working_directory // empty')
    
    # 設定ファイルを読み込む
    local config=$(load_and_validate_config)
    
    # コマンドを評価
    local result=$(evaluate_bash_command "$command" "$config")
    
    # 結果を出力
    echo "$result"
}

# フックを実行
run_hook