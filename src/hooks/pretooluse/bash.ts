#!/usr/bin/env bun

import { parseCommands } from '../../lib/command-parser'
import { loadConfig } from '../../lib/config-loader'
import { evaluateRules } from '../../lib/evaluator'
import type { BashHookInput, HookOutput } from '../../types/hooks'

/**
 * PreToolUse/Bash フック
 * Bash コマンドの実行前に評価し、必要に応じてブロックまたは承認する
 *
 * @param input - Claude Codeから受け取るJSON
 * @example
 * {
 *   "tool_name": "Bash",
 *   "tool_input": {
 *     "command": "rm -rf /tmp/test",
 *     "description": "テストディレクトリを削除",
 *     "working_directory": "/home/user/project"
 *   }
 * }
 */
export async function processHook(input: BashHookInput): Promise<HookOutput> {
  const bashInput = input.tool_input

  // コマンドがない場合は処理しない
  if (!bashInput.command.trim()) {
    return {}
  }

  // 設定を読み込む
  const rules = loadConfig()

  // 設定がない場合は通常フロー
  if (rules.length === 0) {
    return {}
  }

  // 複合コマンドをパース
  const commands = parseCommands(bashInput.command)

  // 最初のapproveを記録
  let firstApprove: { decision: 'approve'; reason: string } | null = null

  // 各コマンドを評価
  for (const parsedCommand of commands) {
    // コマンド名と引数を分離（現在は使用していないが、将来の拡張のため）
    // const parts = parsedCommand.command.trim().split(/\s+/)
    // const commandName = parts[0]
    // const args = parts.slice(1).join(' ')

    // ルールを評価
    const result = evaluateRules(rules, {
      input: {
        command: parsedCommand.command,
        description: bashInput.description || ''
      }
    })

    // blockが見つかったら即座に返す
    if (result.decision === 'block') {
      return {
        decision: 'block',
        reason: result.reason
      }
    }

    // approveは記録しておく（blockがなければ最後に返す）
    if (result.decision === 'approve' && !firstApprove) {
      firstApprove = {
        decision: 'approve',
        reason: result.reason
      }
    }
  }

  // blockがなくapproveがあった場合
  if (firstApprove) {
    return firstApprove
  }

  // decisionが未指定またはマッチしなかった場合は通常フロー
  return {}
}

// エントリーポイント
if (import.meta.main) {
  // 標準入力からJSONを読み込む
  const input = (await Bun.stdin.json()) as BashHookInput

  // フック処理を実行
  const output = await processHook(input)

  // 結果を標準出力に出力
  console.log(JSON.stringify(output))
}
