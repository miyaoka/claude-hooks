# PostToolUse/Bash フック

Bash コマンドの実行後処理を行う PostToolUse フック

## 概要

このフックは Claude Code が Bash ツールを使用した後に介入し、コマンドの実行結果に基づいてアクションを実行します。実行結果のログ記録、警告表示などが可能です。

## 動作

1. Claude Code が Bash コマンドを実行
2. コマンドが成功した場合、PostToolUse フックが呼ばれる
3. 設定ファイルのルールに基づいて評価
4. アクション（無視、ログ、警告）を実行

## アクションの種類

- **ignore** - 何もしない（デフォルト）
- **log** - コマンドと結果をログファイルに記録
- **warn** - 警告メッセージを表示
- **error** - エラーメッセージを表示

## 設定例

```json
{
  "PostToolUse": {
    "Bash": {
      "rm": [
        {
          "action": "warn",
          "reason": "削除操作が成功した場合に警告"
        }
      ],
      "git": [
        {
          "pattern": "^(commit|push)",
          "action": "log",
          "reason": "Git の変更操作を記録"
        }
      ],
      "npm": [
        {
          "output_pattern": "vulnerability",
          "action": "warn",
          "reason": "脆弱性が検出された場合に警告"
        }
      ],
      "echo": [
        {
          "pattern": "log",
          "action": "log",
          "reason": "ログ出力を記録"
        }
      ]
    }
  }
}
```

## ルールのマッチング条件

- **pattern** - コマンド引数に対する正規表現パターン
- **output_pattern** - 標準出力に対する正規表現パターン
- **error_pattern** - 標準エラー出力に対する正規表現パターン

すべての条件が AND で評価されます。

## ログファイル

ログは以下の場所に保存されます：
- デフォルト: `~/.claude/hooks-command.log`
- 環境変数 `CLAUDE_HOOKS_LOG` で変更可能

ログ形式：
```
=== 2025-07-11 07:20:18 ===
Command: echo log
Output:
log

```

## 重要な注意事項

- **エラーが発生したコマンドでは PostToolUse フックは呼ばれません**
- PreToolUse でブロックされたコマンドも対象外です
- 成功したコマンドのみが PostToolUse の対象となります