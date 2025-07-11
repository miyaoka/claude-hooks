import { describe, expect, test } from 'bun:test'
import type { EvaluationContext, Rule } from './evaluator'
import { evaluateRule, evaluateRules } from './evaluator'

describe('evaluateRule', () => {
  test('コマンド名が一致する場合、ルールがマッチする', () => {
    // 仕様: コマンド名（最初の単語）でマッチング
    // "rm -rf /" → コマンド名: "rm", 引数: "-rf /"
    const rule: Rule = {
      command: 'rm',
      decision: 'block',
      reason: 'rm command is dangerous'
    }

    const context: EvaluationContext = {
      input: { command: 'rm -rf /' }
    }

    expect(evaluateRule(rule, context)).toBe(true)
  })

  test('コマンド名が一致しない場合、ルールがマッチしない', () => {
    // 仕様: コマンド名が異なる場合はマッチしない
    const rule: Rule = {
      command: 'rm',
      decision: 'block',
      reason: 'rm is dangerous'
    }

    const context: EvaluationContext = {
      input: { command: 'rmdir /tmp/test' } // rmdir != rm
    }

    expect(evaluateRule(rule, context)).toBe(false)
  })

  test('引数パターンがマッチする場合、ルールがマッチする', () => {
    // 仕様: args は引数部分に対する正規表現マッチング
    // "rm -rf ~/projects" → コマンド名: "rm", 引数: "-rf ~/projects"
    // args: "-rf\\s+~" は引数部分 "-rf ~/projects" にマッチ
    const rule: Rule = {
      command: 'rm',
      args: '-rf\\s+~',
      decision: 'block',
      reason: 'Deleting home directory is dangerous'
    }

    const context: EvaluationContext = {
      input: { command: 'rm -rf ~/projects' }
    }

    expect(evaluateRule(rule, context)).toBe(true)
  })

  test('コマンドと引数の両方が指定されている場合、両方マッチする必要がある', () => {
    // 仕様: 複数の条件が指定されている場合はAND条件
    // command が一致しない場合、args が一致してもマッチしない
    const rule: Rule = {
      command: 'rm', // コマンド名の完全一致
      args: '-rf',
      decision: 'block',
      reason: 'rm -rf is dangerous'
    }

    const context: EvaluationContext = {
      input: { command: 'rmdir -rf /' } // rmdir != rm
    }

    expect(evaluateRule(rule, context)).toBe(false)
  })

  test('全コマンドに適用されるルール（commandなし）', () => {
    // 仕様: command を省略すると全コマンドに適用（ドキュメント179-182行目の例）
    // {
    //   "args": "--force",
    //   "reason": "全コマンドの--forceオプションは危険",
    //   "decision": "block"
    // }
    const rule: Rule = {
      args: '--force',
      reason: '全コマンドの--forceオプションは危険',
      decision: 'block'
    }

    const context: EvaluationContext = {
      input: { command: 'git push --force origin main' }
    }

    // "git push --force origin main" の引数部分 "push --force origin main" に "--force" が含まれる
    expect(evaluateRule(rule, context)).toBe(true)
  })
})

describe('evaluateRules', () => {
  test('マッチするルールがない場合、マッチなしを示す', () => {
    // 仕様: ルールにマッチしない場合、フックは何も出力せず正常終了する
    // → evaluateRules は matched_rule が undefined を返す必要がある
    const rules: Rule[] = [
      {
        command: 'rm',
        decision: 'block',
        reason: 'rm is dangerous'
      }
    ]

    const context: EvaluationContext = {
      input: { command: 'ls -la' }
    }

    const result = evaluateRules(rules, context)
    expect(result.matched_rule).toBeUndefined()
    // フックの実装では、この場合何も出力せずに process.exit(0) する
  })

  test('blockが最優先される', () => {
    // 仕様: 優先順位は block > undefined > approve（ドキュメント87行目）
    // 仕様: block が見つかったら即座に処理終了（ドキュメント89行目）
    const rules: Rule[] = [
      {
        command: 'rm',
        decision: 'approve',
        reason: 'rm is allowed'
      },
      {
        command: 'rm',
        args: '-rf',
        decision: 'block',
        reason: 'rm -rf is dangerous'
      }
    ]

    const context: EvaluationContext = {
      input: { command: 'rm -rf /tmp' }
    }

    const result = evaluateRules(rules, context)
    expect(result.decision).toBe('block')
    expect(result.reason).toBe('rm -rf is dangerous')
    expect(result.matched_rule).toBeDefined()
  })

  test('ルールに decision が指定されていない場合', () => {
    // 仕様: decision が未指定の場合は undefined（ドキュメント148行目）
    // 仕様: undefined は「通常の権限フローを使用（ユーザーに確認）」を意味する
    const rules: Rule[] = [
      {
        command: 'touch',
        reason: 'touchコマンドは要確認'
        // decision は未指定
      }
    ]

    const context: EvaluationContext = {
      input: { command: 'touch file.txt' }
    }

    const result = evaluateRules(rules, context)
    expect(result.matched_rule).toBeDefined()
    expect(result.decision).toBeUndefined()
    expect(result.reason).toBe('touchコマンドは要確認')
  })

  test('approveルールのみがマッチした場合', () => {
    // 仕様: approve は「権限確認をスキップして自動実行」を意味する（ドキュメント147行目）
    // ドキュメントの例（173-177行目）:
    // {
    //   "command": "git",
    //   "args": "^(status|log|diff)",
    //   "reason": "読み取り専用のgitコマンドは自動承認",
    //   "decision": "approve"
    // }
    const rules: Rule[] = [
      {
        command: 'git',
        args: '^(status|log|diff)',
        decision: 'approve',
        reason: '読み取り専用のgitコマンドは自動承認'
      }
    ]

    const context: EvaluationContext = {
      input: { command: 'git status' }
    }

    // "git status" → コマンド名: "git", 引数: "status"
    // args の正規表現 "^(status|log|diff)" は "status" にマッチ
    const result = evaluateRules(rules, context)
    expect(result.matched_rule).toBeDefined()
    expect(result.decision).toBe('approve')
    expect(result.reason).toBe('読み取り専用のgitコマンドは自動承認')
  })

  test('複数のundefinedルールがマッチした場合、最初のルールが選ばれる', () => {
    // 仕様: 同じ優先度の場合は最初にマッチしたルールを採用
    // 根拠: blockは一つでも見つかれば即座に処理終了するため、
    // approve/undefinedも同様に前者優先とすることで一貫性を保つ
    const rules: Rule[] = [
      {
        command: 'touch',
        reason: 'touchコマンドは要確認'
        // decision は未指定
      },
      {
        args: '.txt$',
        reason: 'テキストファイルの作成は要確認'
        // decision は未指定
      }
    ]

    const context: EvaluationContext = {
      input: { command: 'touch file.txt' }
    }

    const result = evaluateRules(rules, context)
    expect(result.matched_rule).toBeDefined()
    expect(result.decision).toBeUndefined()
    expect(result.reason).toBe('touchコマンドは要確認')
  })

  test('複数のblockルールがマッチした場合、最初のルールが選ばれる', () => {
    // 仕様: blockは一つでも見つかれば即座に処理終了
    // そのため、最初にマッチしたblockルールが採用される
    const rules: Rule[] = [
      {
        command: 'rm',
        decision: 'block',
        reason: 'rmコマンドは危険'
      },
      {
        args: '-rf',
        decision: 'block',
        reason: '強制削除オプションは危険'
      }
    ]

    const context: EvaluationContext = {
      input: { command: 'rm -rf /tmp' }
    }

    const result = evaluateRules(rules, context)
    expect(result.matched_rule).toBeDefined()
    expect(result.decision).toBe('block')
    expect(result.reason).toBe('rmコマンドは危険')
  })

  test('複数のapproveルールがマッチした場合、最初のルールが選ばれる', () => {
    // 仕様: 同じ優先度の場合は最初にマッチしたルールを採用
    const rules: Rule[] = [
      {
        command: 'git',
        decision: 'approve',
        reason: 'gitコマンドは安全'
      },
      {
        args: '^status',
        decision: 'approve',
        reason: 'git statusは読み取り専用'
      }
    ]

    const context: EvaluationContext = {
      input: { command: 'git status' }
    }

    const result = evaluateRules(rules, context)
    expect(result.matched_rule).toBeDefined()
    expect(result.decision).toBe('approve')
    expect(result.reason).toBe('gitコマンドは安全')
  })
})
