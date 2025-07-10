# Bash コマンドルール設定ガイド

## 概要

Claude Code で実行される bash コマンドを制御するためのルール設定。コマンドと引数のパターンに基づいて、自動承認・ブロック・確認要求を設定できる

このシステムは Claude Code の [Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) 機能を利用している。具体的には [PreToolUse](https://docs.anthropic.com/en/docs/claude-code/hooks#pretooluse) フックで Bash コマンドの実行を制御する

## ルールファイルの場所

以下の 2 つのファイルがマージされて使用される：

1. **グローバル設定**: 以下の優先順位で検索される
   - `$CLAUDE_CONFIG_DIR/hooks.config.json`（環境変数が設定されている場合）
   - `~/.config/claude/hooks.config.json`
   - `~/.claude/hooks.config.json`
2. **ローカル設定**: `.claude/hooks.config.json`（カレントディレクトリ）

### マージの仕組み

- 同じコマンドに対するルールは、グローバル → ローカルの順で配列に結合される
- ローカルルールが後に評価されるため、ローカル設定が優先される
- プロジェクト固有のルールを設定したい場合は、プロジェクトのルートディレクトリに `.claude/hooks.config.json` を配置する

#### マージの例

```json
// グローバル (例: ~/.config/claude/hooks.config.json)
{
  "PreToolUse": {
    "Bash": {
      "rm": [
        {
          "pattern": "-rf",
          "reason": "強制削除は危険",
          "decision": "block"
        }
      ]
    }
  }
}

// ローカル (.claude/hooks.config.json)
{
  "PreToolUse": {
    "Bash": {
      "rm": [
        {
          "pattern": "\\.tmp$",
          "reason": "一時ファイルの削除はOK",
          "decision": "approve"
        }
      ]
    }
  }
}

// 実際に評価される結合結果
{
  "rm": [
    // グローバルルールが先
    {
      "pattern": "-rf",
      "reason": "強制削除は危険",
      "decision": "block"
    },
    // ローカルルールが後
    {
      "pattern": "\\.tmp$",
      "reason": "一時ファイルの削除はOK",
      "decision": "approve"
    }
  ]
}
```

この例では：

- `rm -rf file.tmp` → 両方のパターンにマッチするが、`block` が優先される（安全側に倒す）
- `rm file.tmp` → `.tmp$` パターンのみマッチし、`approve` される

## 基本構造

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

各コマンドのルールは配列として定義される。各要素は：

- `pattern`（オプション）: 正規表現パターン。省略時はパターン未指定のデフォルト動作を定義
- `reason`: 理由の説明
- `decision`（オプション）: `"block"` または `"approve"`。省略時は `undefined`（確認要求）

## 基本的な動作

PreToolUse フックは、最終的に **1 つの decision と reason** を Claude Code に返す仕組みです。

- 複数のパターンがマッチした場合でも、最終的に採用されるのは 1 つだけ
- 優先順位に基づいて最も重要な decision が選ばれる
- 選ばれた decision に対応する reason が表示される

例：

```json
{
  "rm": [
    {
      "pattern": "\\.tmp$",
      "reason": "一時ファイル（.tmp）の削除はOK",
      "decision": "approve"
    },
    {
      "pattern": "-rf",
      "reason": "強制削除は要確認"
    },
    {
      "pattern": "/etc",
      "reason": "システムファイルは削除禁止",
      "decision": "block"
    }
  ]
}
```

`rm -rf /etc/test.tmp` の場合：

- `.tmp$` パターン（末尾が .tmp）にマッチ → `approve`
- `-rf` パターンにマッチ → `undefined`
- `/etc` パターンにマッチ → `block`
- 優先順位により `block` が選ばれる
- 最終的に返される結果：`{"decision": "block", "reason": "システムファイルは削除禁止"}`

## decision の種類

| 値          | 動作                   | 使用例                   |
| ----------- | ---------------------- | ------------------------ |
| `"block"`   | コマンドを実行しない   | 危険なコマンドをブロック |
| `"approve"` | 確認なしで自動実行     | 安全なコマンドを自動承認 |
| 未指定      | ユーザーに確認を求める | 判断が必要なコマンド     |

## 優先順位

### 基本の優先順位

複数のルールがマッチした場合の優先順位：

1. `block` （最優先）
2. 未指定（ユーザー確認）
3. `approve` （最低優先）

### デフォルトとパターンの関係

**重要な概念**：

- **パターンなし**（`pattern` フィールドが省略）= デフォルト動作
- **パターンあり**（`pattern` フィールドに正規表現）= 特定条件での動作

処理の流れ：

1. 配列を順番に評価
2. パターンなしエントリーが見つかるたびに、デフォルトを更新
3. パターンありエントリーでマッチしたものがあれば、優先順位に基づいて選択
4. 最終的に、パターンマッチがあればそれを使用、なければデフォルトを使用

#### 例: デフォルトとパターンの組み合わせ

```json
{
  "touch": [
    {
      "reason": "touchコマンドのデフォルトは承認",
      "decision": "approve"
    },
    {
      "pattern": "/etc",
      "reason": "システムファイルへのtouchは禁止",
      "decision": "block"
    },
    {
      "pattern": "\\.conf$",
      "reason": "設定ファイルの作成は要確認"
    }
  ]
}
```

この場合の動作：

- `touch file.txt` → 自動承認（最初のエントリーがデフォルトで `approve`）
- `touch /etc/hosts` → ブロック（パターンの `block` が優先）
- `touch app.conf` → ユーザー確認（パターンの未指定が `approve` より優先）
- `touch file.txt /etc/hosts app.conf` → ブロック（`/etc` パターンがコマンド全体にマッチ）

> **重要**: パターンマッチングは「コマンド名 + 引数」の文字列全体に対して行われる。例えば `touch file.txt /etc/hosts` というコマンドの場合、パターンは `"touch file.txt /etc/hosts"` という文字列全体に対して評価される。そのため `/etc` というパターンは、この文字列のどこかに `/etc` が含まれていればマッチする

## 設定例

### 危険なコマンドをブロック

```json
{
  "rules": {
    "rm": [
      {
        "pattern": "-rf\\s+\\*",
        "reason": "rm -rf * は現在のディレクトリをすべて削除します",
        "decision": "block"
      },
      {
        "pattern": "-rf\\s+.*(\\s|^)(/|~/|/home|/usr|/etc)",
        "reason": "システムディレクトリの削除は禁止されています",
        "decision": "block"
      }
    ]
  }
}
```

### 安全なコマンドを自動承認

```json
{
  "rules": {
    "git": [
      {
        "pattern": "^(status|log|diff|branch)",
        "reason": "読み取り専用のgitコマンド",
        "decision": "approve"
      }
    ],
    "ls": [
      {
        "reason": "通常のlsコマンドは安全",
        "decision": "approve"
      },
      {
        "pattern": "[~/]",
        "reason": "ルートやホームディレクトリの一覧は要確認"
      }
    ]
  }
}
```

### コマンド全体を制御

```json
{
  "rules": {
    "sudo": [
      {
        "reason": "管理者権限での実行は常に確認が必要"
      }
    ],
    "curl": [
      {
        "decision": "block",
        "reason": "外部へのアクセスは禁止"
      }
    ]
  }
}
```

## パターンの書き方

### 基本

- 正規表現（grep -E 形式）を使用
- JSON 内でのエスケープに注意（`\\` でエスケープ）

### よく使うパターン

| パターン   | 説明             | 例                                   |
| ---------- | ---------------- | ------------------------------------ |
| `^command` | コマンドで始まる | `^status` → `status -v` にマッチ     |
| `\\s+`     | 空白文字         | `-rf\\s+\\*` → `-rf *` にマッチ      |
| `(A\|B)`   | A または B       | `^(add\|commit)` → `add` か `commit` |
| `.*`       | 任意の文字列     | `.*password.*` → パスワードを含む    |
| `[~/]`     | 文字クラス       | `[~/]` → `~` か `/` を含む           |

### 複合コマンドの扱い

以下のようなコマンドは個別に評価される：

- `cd /tmp && rm file.txt` → `cd /tmp` と `rm file.txt` を別々に評価
- `ls || echo error` → `ls` と `echo error` を別々に評価

### セキュリティ上の注意事項

**コマンド置換に注意**：フックシステムはコマンド実行前の文字列のみを評価するため、コマンド置換 `$(...)` や `` `...` `` の中身は検査されません。

例：

- `echo $(rm -rf *)` → `echo` として評価され、承認される可能性がある
- 実行時にシェルが `$(rm -rf *)` を展開し、危険なコマンドが実行される

このため、`echo` などの一見安全なコマンドを無条件で approve する際は、コマンド置換による意図しない実行に注意が必要です

## デバッグとテスト

### evaluator.sh の直接テスト

評価エンジンを直接テストして、ルールの動作を確認できる：

```bash
# テスト用のルールファイルを作成（マージ後の形式）
cat > test-rules.json << 'EOF'
{
  "rm": [
    {
      "pattern": "^-rf",
      "reason": "強制削除は危険",
      "decision": "block"
    }
  ]
}
EOF

# evaluator.sh を直接実行
./hooks/pretooluse/bash/evaluator.sh "rm -rf /tmp/test" test-rules.json
# 出力: {"decision": "block", "reason": "強制削除は危険"}

./hooks/pretooluse/bash/evaluator.sh "rm /tmp/test" test-rules.json
# 出力: {}
```

### hook.sh の直接テスト

hooks.config.json を用意した状態で、フックスクリプト全体をテスト：

```bash
# Claude Code が送る JSON 形式でテスト
echo '{"tool_input": {"command": "git status"}}' | ~/.claude/hooks/pretooluse/bash/hook.sh
# 出力: {"decision": "approve", "reason": "読み取り専用のgitコマンドは自動承認"}

# 複雑なコマンドのテスト
echo '{"tool_input": {"command": "cd /tmp && rm -rf *"}}' | ~/.claude/hooks/pretooluse/bash/hook.sh
# 出力: {"decision": "block", "reason": "⚠️ rm -rf * で現在のディレクトリすべてを削除は禁止"}
```

### ローカルルールのテスト

プロジェクト固有のルールをテスト：

```bash
# ローカルルールを作成
mkdir -p .claude
cat > .claude/hooks.config.json << 'EOF'
{
  "PreToolUse": {
    "Bash": {
      "npm": [
        {
          "pattern": "^install",
          "reason": "このプロジェクトではpnpmを使用",
          "decision": "block"
        }
      ]
    }
  }
}
EOF

# テスト実行
echo '{"tool_input": {"command": "npm install"}}' | ~/.claude/hooks/pretooluse/bash/hook.sh
# 出力: {"decision": "block", "reason": "このプロジェクトではpnpmを使用"}
```

## 実践的な例

### 開発環境用の設定

```json
{
  "PreToolUse": {
    "Bash": {
      "npm": [
        {
          "pattern": "^(test|lint|typecheck|build)",
          "reason": "開発用コマンドは自動実行",
          "decision": "approve"
        },
        {
          "pattern": "^install",
          "reason": "パッケージインストールは確認が必要"
        }
      ],
      "rm": [
        {
          "pattern": "node_modules",
          "reason": "node_modules の削除は許可",
          "decision": "approve"
        },
        {
          "pattern": "-rf",
          "reason": "強制削除は要確認"
        }
      ]
    }
  }
}
```
