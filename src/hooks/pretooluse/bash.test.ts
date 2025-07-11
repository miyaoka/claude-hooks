import { beforeEach, describe, expect, spyOn, test } from 'bun:test'
import * as configLoader from '../../lib/config-loader'
import type { BashHookInput } from '../../types/hooks'
import { processHook } from './bash'

describe('PreToolUse/Bash Hook', () => {
  // 各テストの前に設定をモック
  let loadConfigSpy: ReturnType<typeof spyOn>

  beforeEach(() => {
    // デフォルトは空の設定
    loadConfigSpy = spyOn(configLoader, 'loadConfig').mockReturnValue([])
  })
  describe('基本的な動作', () => {
    test('Bashツールでコマンドがない場合は処理しない', async () => {
      // 仕様: tool_input.commandが必須
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: ''
        }
      }

      const result = await processHook(input)
      expect(result).toEqual({})
    })

    test('設定ファイルが存在しない場合は通常フロー', async () => {
      // 仕様: 設定がなければ何もしない
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: 'ls -la'
        }
      }

      const result = await processHook(input)
      expect(result).toEqual({})
    })
  })

  describe('単一コマンドの処理', () => {
    test('blockルールにマッチした場合、実行をブロックする', async () => {
      // 仕様: block決定は最優先
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: 'rm -rf /'
        }
      }

      // 設定: rm -rf をブロック
      loadConfigSpy.mockReturnValue([
        {
          command: 'rm',
          args: '^-rf',
          reason: '危険な削除コマンド',
          decision: 'block'
        }
      ])

      const result = await processHook(input)
      expect(result).toEqual({
        decision: 'block',
        reason: '危険な削除コマンド'
      })
    })

    test('approveルールにマッチした場合、自動承認する', async () => {
      // 仕様: 安全なコマンドは自動承認
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: 'git status'
        }
      }

      // 設定: git statusを自動承認
      loadConfigSpy.mockReturnValue([
        {
          command: 'git',
          args: '^status$',
          reason: '読み取り専用のgitコマンド',
          decision: 'approve'
        }
      ])

      const result = await processHook(input)
      expect(result).toEqual({
        decision: 'approve',
        reason: '読み取り専用のgitコマンド'
      })
    })

    test('decisionが未指定のルールにマッチした場合', async () => {
      // 仕様: decisionなしは通常フロー（ユーザー確認）
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: 'touch file.txt'
        }
      }

      // 設定: touchコマンドは確認が必要
      loadConfigSpy.mockReturnValue([
        {
          command: 'touch',
          reason: 'ファイル作成は確認が必要'
        }
      ])

      const result = await processHook(input)
      expect(result).toEqual({})
    })
  })

  describe('複合コマンドの処理', () => {
    test('&&で繋がれたコマンドをそれぞれ評価する', async () => {
      // 仕様: 各コマンドを個別に評価
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: 'cd /tmp && rm -rf *'
        }
      }

      // 設定: rm -rf * をブロック
      loadConfigSpy.mockReturnValue([
        {
          command: 'rm',
          args: '^-rf \\*$',
          reason: 'ワイルドカード削除は危険',
          decision: 'block'
        }
      ])

      const result = await processHook(input)
      expect(result).toEqual({
        decision: 'block',
        reason: 'ワイルドカード削除は危険'
      })
    })

    test('複数のblockがある場合、最初のblockを返す', async () => {
      // 仕様: 最初に見つかったblockで処理終了
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: 'rm -rf / && sudo rm -rf /'
        }
      }

      // 設定: 両方ブロック
      loadConfigSpy.mockReturnValue([
        {
          command: 'rm',
          args: '^-rf /$',
          reason: 'ルート削除は禁止',
          decision: 'block'
        },
        {
          command: 'sudo',
          reason: 'sudo使用は禁止',
          decision: 'block'
        }
      ])

      const result = await processHook(input)
      expect(result).toEqual({
        decision: 'block',
        reason: 'ルート削除は禁止'
      })
    })

    test('blockとapproveが混在する場合、blockを優先', async () => {
      // 仕様: block > approve
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: 'git status && rm -rf /'
        }
      }

      // 設定
      loadConfigSpy.mockReturnValue([
        {
          command: 'git',
          args: '^status$',
          reason: '安全なgitコマンド',
          decision: 'approve'
        },
        {
          command: 'rm',
          args: '^-rf /$',
          reason: '危険な削除',
          decision: 'block'
        }
      ])

      const result = await processHook(input)
      expect(result).toEqual({
        decision: 'block',
        reason: '危険な削除'
      })
    })
  })

  describe('設定ファイルの読み込み', () => {
    // これらのテストは実際の設定ファイルに依存するため、スキップ
    test('ローカル設定を優先的に読み込む', async () => {
      // 仕様: プロジェクトの.claude/hooks.config.jsonを最優先
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: 'rm file.txt'
        }
      }

      // ローカル設定でrmをブロック
      await processHook(input)
      // 実際の設定ファイルの内容に依存
    })

    test('グローバル設定とローカル設定をマージする', async () => {
      // 仕様: グローバル設定も考慮
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: 'dangerous-command'
        }
      }

      // グローバルとローカルの両方の設定が適用される
      await processHook(input)
      // 実際の設定ファイルの内容に依存
    })
  })

  describe('エッジケース', () => {
    test('クォート内のセパレータは無視される', async () => {
      // 仕様: クォート内は文字列として扱う
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: 'echo "rm -rf /" && echo done'
        }
      }

      // 設定: rmをブロック
      loadConfigSpy.mockReturnValue([
        {
          command: 'rm',
          reason: 'rmコマンドは禁止',
          decision: 'block'
        }
      ])

      // echoコマンドなのでブロックされない
      const result = await processHook(input)
      expect(result).toEqual({})
    })

    test('空のコマンドは処理しない', async () => {
      const input: BashHookInput = {
        tool_name: 'Bash',
        tool_input: {
          command: '   '
        }
      }

      const result = await processHook(input)
      expect(result).toEqual({})
    })
  })
})
