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
            if match_pattern "$cmd_args" "$pattern"; then
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
    
    # 結果JSONを生成
    create_result_json "decision" "$final_decision" "$final_reason"
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
    create_result_json "decision" "$final_decision" "$final_reason"
}


# コマンドライン引数として実行する場合
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # 引数の検証
    if ! validate_arguments $#; then
        exit 1
    fi
    
    command="$1"
    rules_file="$2"
    
    # ルールファイルを読み込んで検証
    rules_json=$(load_and_validate_rules_file "$rules_file")
    
    # 評価の実行
    evaluate_bash_command "$command" "$rules_json"
fi