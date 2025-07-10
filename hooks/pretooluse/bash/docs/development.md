# PreToolUse Hook 実装仕様書

## 概要

Claude Code の PreToolUse フックシステムの内部実装仕様。一般的な使用方法については [bash-command-rules.md](bash-command-rules.md) を参照

この実装は [Claude Code Hooks API](https://docs.anthropic.com/en/docs/claude-code/hooks) に基づいている

## ファイル構成

### 設定ファイル

```
# グローバル設定（以下の優先順位で検索）
$CLAUDE_CONFIG_DIR/hooks.config.json      # 環境変数で指定された場合
~/.config/claude/hooks.config.json
~/.claude/hooks.config.json

# ローカル設定
プロジェクトディレクトリ/
└── .claude/
    └── hooks.config.json
```

### 本リポジトリ

```
claude-hooks/
└── hooks/pretooluse/bash/
    ├── hook.sh             # フックスクリプト（エントリーポイント）
    └── evaluator.sh        # 評価エンジン（純粋関数）
```

## hook.sh の仕様

### 入力

標準入力から JSON 形式でツール呼び出し情報を受け取る

#### 入力例

```json
{
  "tool_input": {
    "command": "git status",
    "working_directory": "/home/user/project"
  }
}
```

- Bash ツールの場合、`.tool_input.command` にコマンドが含まれる

### 処理フロー

1. **コマンドパース**

   - クォートを考慮した高度なパーサーで複合コマンドを分解
   - `&&`、`||`、`;`、`|` で区切られたコマンドを個別に処理

2. **ルールマッチング**

   - コマンド名（最初の単語）でルールを検索
   - ルートレベルの decision をチェック
   - patterns 配列の各パターンをチェック

3. **優先順位**
   - `block` > `undefined` > `approve`
   - `block` が見つかったら即座に処理終了

### 出力

```json
// ブロックする場合
{"decision": "block", "reason": "ブロック理由"}

// 承認する場合
{"decision": "approve", "reason": "承認理由"}

// 通常フロー（undefined または該当なし）
{}
```

## hooks.config.json の仕様

### 構造

```json
{
  "PreToolUse": {
    "Bash": {
      "コマンド名": [
        {
          "pattern": "正規表現パターン", // オプション（省略時はデフォルト）
          "reason": "理由の説明",
          "decision": "block|approve" // オプション（省略時は undefined）
        }
      ]
    }
  }
}
```

### 内部でのマージ後の形式

hook.sh がグローバルとローカルのルールをマージした後、evaluator.sh に渡される形式：

```json
{
  "コマンド名": [
    {
      "pattern": "正規表現パターン",
      "reason": "理由の説明",
      "decision": "block|approve"
    }
  ]
}
```

各コマンドのルールは配列として定義される。配列の各要素は以下のフィールドを持つ：

- `pattern`（オプション）: 正規表現パターン。省略時はデフォルト動作を定義
- `reason`: 理由の説明文
- `decision`（オプション）: `"block"` または `"approve"`。省略時は `undefined`

### decision の意味

- **`block`**: コマンド実行を阻止
- **`approve`**: 権限確認をスキップして自動実行（安全なコマンドを自動承認）
- **未指定（undefined）**: 通常の権限フローを使用（ユーザーに確認）

### パターンマッチング

- `pattern` フィールドが空の場合、すべてのケースにマッチ
- 正規表現は `grep -E` で評価される
- エスケープに注意（JSON 内でのエスケープ + 正規表現のエスケープ）

### 例

```json
{
  "PreToolUse": {
    "Bash": {
      "rm": [
        {
          "pattern": "-rf\\s+\\*",
          "reason": "rm -rf * は危険",
          "decision": "block"
        },
        {
          "pattern": "-rf\\s+.*(\\s|^)(/|~/|/home|/usr|/etc)",
          "reason": "システムディレクトリの削除は禁止",
          "decision": "block"
        }
      ],
      "touch": [
        {
          "reason": "touchコマンドは一時的に禁止",
          "decision": "block"
        }
      ],
      "git": [
        {
          "pattern": "^(status|log|diff)",
          "reason": "読み取り専用のgitコマンドは自動承認",
          "decision": "approve"
        }
      ]
    }
  }
}
```

## 技術的詳細

### コマンドパーサーの実装

- クォート（シングル・ダブル）を考慮した解析
- エスケープ文字の処理
- 複合コマンドの分割（`&&`、`||`、`;`、`|`）

### 優先順位の実装

1. すべてのマッチするパターンを評価
2. 最も高い優先順位の decision を採用
3. `block` が見つかった時点で即座に処理終了

## 注意事項

- jq の `//` 演算子は `false` を falsy として扱うため、`has()` での存在確認が必要
- パターンは実行順序通りに評価され、最初に見つかった `block` で処理終了
- 複数のパターンがマッチした場合、最も高い優先順位の decision が採用される
