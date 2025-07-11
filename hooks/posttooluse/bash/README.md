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

### 標準機能（Claude Code API）
- **action未指定** - 何もしない（デフォルト動作、reasonも無視される）
- **block** - Claudeに通知し、後続処理を中断。危険で後続処理を止めるべき操作（機密情報漏洩、破壊的操作など）

### 独自実装
- **log** - コマンドと結果をログファイルに記録。後で確認したい重要な操作（git commit、deployなど）

### 削除予定（実装の不具合）
- **warn** - 想定：警告をユーザーに表示 → 実際：Claude Code上では表示されない
- **error** - 想定：エラーをユーザーに表示 → 実際：Claude Code上では表示されない

※ warn/errorはstderrに出力してもClaude Codeでは表示されず、実質的にlogと同じ動作になっているため削除予定

## 設定例

```json
{
  "PostToolUse": {
    "Bash": [
      {
        "command": "rm",
        "action": "log",
        "reason": "削除操作を記録"
      },
      {
        "command": "git",
        "args": "^(commit|push)",
        "action": "log",
        "reason": "Git の変更操作を記録"
      },
      {
        "command": "npm",
        "stdout": "vulnerability",
        "action": "log",
        "reason": "脆弱性が検出された場合に記録"
      },
      {
        "stdout": "(password|secret|api_key)\\s*[:=]",
        "action": "block",
        "reason": "機密情報が出力に含まれています"
      },
      {
        "command": "echo",
        "args": "log",
        "action": "log",
        "reason": "ログ出力を記録"
      }
    ]
  }
}
```

## ルールのマッチング条件

- **command** - 対象コマンド名（省略時は全コマンド）
- **args** - コマンド引数に対する正規表現パターン
- **stdout** - 標準出力に対する正規表現パターン
- **stderr** - 標準エラー出力に対する正規表現パターン

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