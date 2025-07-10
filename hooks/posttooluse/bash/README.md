# PostToolUse/Bash フック

Bash コマンドの実行後処理を行う PostToolUse フック

## 概要

このフックは Claude Code が Bash ツールを使用した後に介入し、コマンドの実行結果に基づいてアクションを実行します。実行結果のログ記録、警告表示、危険な操作のブロックなどが可能です。

## 動作

1. Claude Code が Bash コマンドを実行
2. ツールが成功した場合、PostToolUse フックが呼ばれる
3. 設定ファイルのルールに基づいて評価
4. アクション（無視、ログ、警告、ブロック）を実行

## アクションの種類

- **ignore** - 何もしない（デフォルト）
- **log** - コマンドと結果をログファイルに記録
- **warn** - 警告メッセージを表示
- **block** - 処理をブロック（危険な操作の検出時）

## 設定例

```json
{
  "PostToolUse": {
    "Bash": {
      "rm": [
        {
          "exit_code": "0",
          "action": "warn",
          "reason": "削除操作が成功した場合に警告"
        }
      ],
      "git": [
        {
          "pattern": "^(commit|push)",
          "exit_code": "0",
          "action": "log",
          "reason": "Git の変更操作を記録"
        }
      ],
      "*": [
        {
          "error_pattern": "Permission denied",
          "action": "error",
          "reason": "権限エラーが発生した場合にエラー"
        }
      ],
      "default_action": "ignore"
    }
  }
}
```

## ルールのマッチング条件

- **pattern** - コマンド引数に対する正規表現パターン
- **exit_code** - 終了コード（数値または "non-zero"）
- **output_pattern** - 標準出力に対する正規表現パターン
- **error_pattern** - 標準エラー出力に対する正規表現パターン

すべての条件が AND で評価されます。

## ログファイル

ログは設定ファイルと同じディレクトリに保存されます：
- `~/.config/claude/hooks-command.log` （~/.config/claude を使用している場合）
- `~/.claude/hooks-command.log` （~/.claude を使用している場合）
- `$CLAUDE_CONFIG_DIR/hooks-command.log` （CLAUDE_CONFIG_DIR が設定されている場合）

環境変数 `CLAUDE_HOOKS_LOG` で任意の場所に変更することも可能です。