#!/bin/bash

# Bash コマンド評価エンジン（フラット構造版）
# 引数: コマンド文字列、ルール配列JSON
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

# フラット構造のルールを評価する
# 引数: コマンド文字列, ルール配列JSON
# 戻り値: JSON形式 {"decision": "...", "reason": "..."}
evaluate_rules_flat() {
    local parsed_cmd="$1"
    local rules="$2"
    
    local final_decision=""
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
        local rule_decision=$(echo "$rule" | jq -r '.decision // empty')
        local rule_reason=$(echo "$rule" | jq -r '.reason // empty')
        
        # コマンド名のマッチング（commandフィールドが空の場合は全コマンドにマッチ）
        local command_matches=false
        if [ -z "$rule_command" ] || [ "$rule_command" = "$cmd_name" ]; then
            command_matches=true
        fi
        
        # コマンドがマッチした場合のみ評価を続ける
        if [ "$command_matches" = true ]; then
            # 引数のマッチング
            local args_match=false
            if [ -z "$rule_args" ]; then
                # argsフィールドがない場合は常にマッチ
                args_match=true
            elif match_pattern "$cmd_args" "$rule_args"; then
                args_match=true
            fi
            
            # 両方マッチした場合
            if [ "$args_match" = true ]; then
                local new_decision="$rule_decision"
                if [ -z "$new_decision" ] && [ -n "$rule_reason" ]; then
                    new_decision="$DECISION_UNDEFINED"
                fi
                
                if should_update_decision "$final_decision" "$new_decision"; then
                    final_decision="$new_decision"
                    final_reason="$rule_reason"
                fi
                
                # blockが見つかったら即座に終了
                if [ "$final_decision" = "$DECISION_BLOCK" ]; then
                    break
                fi
            fi
        fi
    done
    
    # 結果JSONを生成
    create_result_json "decision" "$final_decision" "$final_reason"
}

# メイン評価関数
evaluate_bash_command() {
    local command="$1"
    local rules_array="$2"
    
    # 最終結果の初期化
    local final_decision=""
    local final_reason=""
    
    # コマンドをパースして各コマンドをチェック
    while IFS= read -r parsed_cmd; do
        # ルールを評価
        local result=$(evaluate_rules_flat "$parsed_cmd" "$rules_array")
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
    
    # ルールファイルを読み込んで検証（フラット構造として読み込む）
    rules_json=$(cat "$rules_file" 2>/dev/null || echo "[]")
    if ! echo "$rules_json" | jq -e . >/dev/null 2>&1; then
        error_exit "ルールファイルが無効なJSONです: $rules_file"
    fi
    
    # 評価の実行
    evaluate_bash_command "$command" "$rules_json"
fi