#!/bin/bash

# Bash コマンド評価エンジン
# 引数: コマンド文字列、ルールJSON
# 戻り値: JSON形式 {"decision": "...", "reason": "..."}

# カレントディレクトリを取得
EVALUATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリをロード
source "$EVALUATOR_DIR/../../lib/common.sh"

# 定数定義
readonly DECISION_BLOCK="block"
readonly DECISION_APPROVE="approve"
readonly DECISION_UNDEFINED="undefined"
readonly NULL_VALUE="null"
readonly EMPTY_JSON="{}"

# ルールの優先順位を判定する
# 引数: 現在の決定, 新しい決定
# 戻り値: 0 (新しい決定を採用) または 1 (現在の決定を維持)
should_update_decision() {
    should_update_by_priority "$1" "$2" "$DECISION_BLOCK $DECISION_UNDEFINED $DECISION_APPROVE"
}


# ルールを評価する
# 引数: コマンド文字列, ルール配列JSON
# 戻り値: JSON形式 {"decision": "...", "reason": "..."}
evaluate_rules() {
    local parsed_cmd="$1"
    local rules="$2"
    
    local default_decision=""
    local default_reason=""
    local matched_decision=""
    local matched_reason=""
    
    # コマンド名を取得して、引数部分のみを抽出
    local cmd_name=$(extract_command_name "$parsed_cmd")
    local cmd_args=$(extract_command_args "$parsed_cmd")
    
    # ルール配列の長さを取得
    local rules_count=$(echo "$rules" | jq 'length')
    
    for i in $(seq 0 $((rules_count - 1))); do
        local pattern=$(echo "$rules" | jq -r ".[$i].pattern // empty")
        local rule_reason=$(echo "$rules" | jq -r ".[$i].reason // empty")
        local rule_decision=$(echo "$rules" | jq -r "if .[$i] | has(\"decision\") then .[$i].decision else empty end")
        
        # パターンなしの場合はデフォルトを更新
        if [ -z "$pattern" ]; then
            if [ -n "$rule_decision" ]; then
                default_decision="$rule_decision"
                default_reason="$rule_reason"
            elif [ -n "$rule_reason" ]; then
                default_decision="$DECISION_UNDEFINED"
                default_reason="$rule_reason"
            fi
        else
            # パターンありの場合は、引数部分に対してマッチを行う
            if echo "$cmd_args" | grep -qE -- "$pattern" 2>/dev/null; then
                local new_decision="$rule_decision"
                if [ -z "$new_decision" ] && [ -n "$rule_reason" ]; then
                    new_decision="$DECISION_UNDEFINED"
                fi
                
                if should_update_decision "$matched_decision" "$new_decision"; then
                    matched_decision="$new_decision"
                    matched_reason="$rule_reason"
                fi
                
                # blockが見つかったら即座に終了
                if [ "$matched_decision" = "$DECISION_BLOCK" ]; then
                    break
                fi
            fi
        fi
    done
    
    # 最終的な決定：パターンマッチがあればそれを使用、なければデフォルト
    local final_decision="${matched_decision:-$default_decision}"
    local final_reason="${matched_reason:-$default_reason}"
    
    if [ "$final_decision" = "$DECISION_UNDEFINED" ] && [ -n "$final_reason" ]; then
        # decisionが未定義の場合はreasonのみ返す
        echo "{\"reason\": \"$final_reason\"}"
    elif [ -n "$final_decision" ] && [ "$final_decision" != "$DECISION_UNDEFINED" ]; then
        # decisionが定義されている場合
        echo "{\"decision\": \"$final_decision\", \"reason\": \"$final_reason\"}"
    else
        # 何もマッチしない場合
        echo "{}"
    fi
}

# メイン評価関数
evaluate_bash_command() {
    local command="$1"
    local rules_json="$2"
    
    # 最終結果の初期化
    local final_decision=""
    local final_reason=""
    
    # コマンドをパースして各コマンドをチェック
    while IFS= read -r parsed_cmd; do
        # コマンド名を抽出
        local cmd_name=$(extract_command_name "$parsed_cmd")
        
        # ルールをチェック（配列として取得）
        local rules=$(echo "$rules_json" | jq -r --arg cmd "$cmd_name" '.[$cmd] // null')
        
        if [ "$rules" != "$NULL_VALUE" ]; then
            # ルールを評価
            local result=$(evaluate_rules "$parsed_cmd" "$rules")
            local decision=$(echo "$result" | jq -r '.decision // empty')
            local reason=$(echo "$result" | jq -r '.reason // empty')
            
            if [ -n "$decision" ]; then
                final_decision="$decision"
                final_reason="$reason"
            elif [ -n "$reason" ]; then
                # decisionが無くてもreasonがある場合
                final_decision="$DECISION_UNDEFINED"
                final_reason="$reason"
            fi
            
            # blockの場合は他のコマンドをチェックする必要がない
            if [ "$final_decision" = "$DECISION_BLOCK" ]; then
                break
            fi
        fi
    done < <(parse_commands "$command")
    
    # 結果を返す
    if [ "$final_decision" = "$DECISION_UNDEFINED" ] && [ -n "$final_reason" ]; then
        # decisionが未定義の場合はreasonのみ返す
        echo "{\"reason\": \"$final_reason\"}"
    elif [ -n "$final_decision" ] && [ "$final_decision" != "$DECISION_UNDEFINED" ]; then
        # decisionが定義されている場合
        echo "{\"decision\": \"$final_decision\", \"reason\": \"$final_reason\"}"
    else
        # 該当なしの場合は通常の権限フローを使用
        echo "$EMPTY_JSON"
    fi
}


# エラーメッセージを出力して終了
# 引数: エラーメッセージ
# 戻り値: なし (エラーコード1で終了)
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# 使用方法を表示
# 引数: なし
# 戻り値: なし
show_usage() {
    echo "Usage: $0 <command> <rules-json-file>" >&2
}

# コマンドライン引数を検証
# 引数: 引数の数
# 戻り値: 0 (成功) または 1 (失敗)
validate_arguments() {
    if [ $1 -ne 2 ]; then
        show_usage
        return 1
    fi
    return 0
}

# コマンドライン引数として実行する場合
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # 引数の検証
    if ! validate_arguments $#; then
        exit 1
    fi
    
    command="$1"
    rules_file="$2"
    
    # ルールファイルの存在確認
    if [ ! -f "$rules_file" ]; then
        error_exit "Rules file not found: $rules_file"
    fi
    
    # ルールJSONの読み込み
    rules_json=$(cat "$rules_file" 2>/dev/null) || error_exit "Failed to read rules file: $rules_file"
    
    # JSONの検証
    if ! echo "$rules_json" | jq . >/dev/null 2>&1; then
        error_exit "Invalid JSON in rules file: $rules_file"
    fi
    
    # 評価の実行
    evaluate_bash_command "$command" "$rules_json"
fi