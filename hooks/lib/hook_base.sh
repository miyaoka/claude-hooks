#!/bin/bash

# フック共通のベース処理
# PreToolUse/PostToolUse フックで共有される基本的な処理フロー

# 定数定義
readonly EMPTY_RESULT="{}"

# フックの初期化
# 引数: なし
# グローバル変数: HOOK_DIR, HOOK_TYPE, TOOL_NAME を設定する必要がある
init_hook() {
    # 必須変数のチェック
    if [ -z "$HOOK_TYPE" ] || [ -z "$TOOL_NAME" ]; then
        echo "Error: HOOK_TYPE and TOOL_NAME must be set" >&2
        exit 1
    fi
    
    # カレントディレクトリを取得（呼び出し元で設定済みの場合はスキップ）
    if [ -z "$HOOK_DIR" ]; then
        HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
}

# 標準入力からツール入力を読み取り、基本的な検証を行う
# 引数: なし
# 戻り値: 入力JSON（標準出力）、コマンドが空の場合は終了
read_and_validate_input() {
    local input=$(cat)
    
    # コマンドを抽出
    local command=$(extract_json_value "$input" '.tool_input.command // empty')
    
    # コマンドが空の場合は何もしない
    if [ -z "$command" ] || [ "$command" = "empty" ]; then
        echo "$EMPTY_RESULT"
        exit 0
    fi
    
    # 入力を返す
    echo "$input"
}

# 設定ファイルを読み込み、検証する（フラット構造版）
# 引数: なし
# 戻り値: 設定配列JSON（標準出力）、設定が空の場合は終了
load_and_validate_config_flat() {
    # 設定ファイルを読み込む（フラット構造）
    local config=$(load_config_flat "$HOOK_TYPE" "$TOOL_NAME")
    
    # 設定が空の場合
    if [ "$config" = "[]" ] || [ -z "$config" ]; then
        echo "$EMPTY_RESULT"
        exit 0
    fi
    
    # 設定を返す
    echo "$config"
}

# 設定ファイルを読み込み、検証する（階層構造版 - 後方互換性のため残す）
# 引数: なし
# 戻り値: 設定JSON（標準出力）、設定が空の場合は終了
load_and_validate_config() {
    # 設定ファイルを読み込む
    local config=$(load_config "$HOOK_TYPE" "$TOOL_NAME")
    
    # 設定が空の場合
    if [ "$config" = "{}" ] || [ -z "$config" ]; then
        echo "$EMPTY_RESULT"
        exit 0
    fi
    
    # 設定を返す
    echo "$config"
}

# デフォルトのメイン処理
# 各フックでカスタマイズが必要な場合はこの関数をオーバーライドする
hook_main() {
    echo "Error: hook_main must be implemented" >&2
    exit 1
}

# フックの実行
# 引数: なし
run_hook() {
    # フックを初期化
    init_hook
    
    # メイン処理を実行
    hook_main
}