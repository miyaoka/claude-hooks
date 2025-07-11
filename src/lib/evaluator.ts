/**
 * ルール評価エンジン
 */

import type { BashToolInput, Rule } from '../types'

export type { Rule } from '../types'

// 評価コンテキスト（PreToolUse用）
export interface EvaluationContext {
  input: BashToolInput
  working_directory?: string
}

// 評価結果
export interface EvaluationResult {
  decision?: 'block' | 'approve'
  reason: string
  matched_rule?: Rule
}

/**
 * 単一のルールを評価する（PreToolUse用）
 */
export function evaluateRule(rule: Rule, context: EvaluationContext): boolean {
  const { input } = context

  // コマンドをパース: "rm -rf /" → ["rm", "-rf", "/"]
  const parts = input.command.split(/\s+/)
  const commandName = parts[0]
  const args = parts.slice(1).join(' ')

  // command フィールドのチェック
  if (rule.command !== undefined) {
    if (commandName !== rule.command) return false
  }

  // args フィールドのチェック（正規表現）
  if (rule.args !== undefined) {
    try {
      const regex = new RegExp(rule.args)
      if (!regex.test(args)) return false
    } catch {
      return false
    }
  }

  return true
}

/**
 * ルールセットを評価して決定を返す
 */
export function evaluateRules(rules: Rule[], context: EvaluationContext): EvaluationResult {
  let matchedRule: Rule | undefined
  let matchedDecision: 'block' | 'approve' | undefined
  let matchedReason: string = ''

  // すべてのルールを評価
  for (const rule of rules) {
    if (evaluateRule(rule, context)) {
      // block が見つかったら即座に返す
      if (rule.decision === 'block') {
        return {
          decision: 'block',
          reason: rule.reason,
          matched_rule: rule
        }
      }

      // block以外で最初にマッチしたルールを記録
      if (!matchedRule) {
        matchedRule = rule
        matchedDecision = rule.decision
        matchedReason = rule.reason
      }
    }
  }

  // マッチしたルールがあれば返す
  if (matchedRule) {
    return {
      decision: matchedDecision,
      reason: matchedReason,
      matched_rule: matchedRule
    }
  }

  // マッチするルールがない場合
  return {
    decision: undefined,
    reason: '',
    matched_rule: undefined
  }
}
