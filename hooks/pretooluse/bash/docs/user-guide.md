# Bash コマンドルール設定ガイド

## 概要

Claude Code で実行される bash コマンドを制御するためのルール設定。コマンドと引数のパターンに基づいて、自動承認・ブロック・確認要求を設定できる

このシステムは Claude Code の [Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) 機能を利用している。具体的には [PreToolUse](https://docs.anthropic.com/en/docs/claude-code/hooks#pretooluse) フックで Bash コマンドの実行を制御する

## 基本構造

`hooks.config.json` ファイルの基本構造：

```json
{
  "PreToolUse": {
    "Bash": [
      {
        "command": "コマンド名", // オプション（省略時は全コマンドに適用）
        "args": "引数の正規表現パターン", // オプション
        "reason": "理由の説明",
        "decision": "block|approve" // オプション（省略時は undefined）
      }
    ]
  }
}
```

各ルールは配列の要素として定義される。各要素は：

- `command`（オプション）: 対象コマンド名。省略時は全コマンドに適用
- `args`（オプション）: コマンドの引数部分に対する正規表現パターン
- `reason`: 理由の説明
- `decision`（オプション）: `"block"` または `"approve"`。省略時は `undefined`（確認要求）

### 入力と出力の例

設定例：

```json
{
  "PreToolUse": {
    "Bash": [
      {
        "command": "rm",
        "args": "-rf",
        "reason": "強制削除は危険",
        "decision": "block"
      },
      {
        "command": "rm",
        "reason": "通常の削除は確認が必要"
      },
      {
        "args": "--force",
        "reason": "全コマンドの--forceオプションは確認が必要"
      }
    ]
  }
}
```

コマンド実行時の動作：

| 入力コマンド        | 結果     | 理由                                           |
| ------------------- | -------- | ---------------------------------------------- |
| `rm file.txt`       | 確認要求 | `command: "rm"` のみのルールにマッチ           |
| `rm -rf dir/`       | ブロック | `command: "rm", args: "-rf"` にマッチ          |
| `npm install --force` | 確認要求 | `args: "--force"` にマッチ（全コマンド対象）   |

### 複合コマンドの扱い

以下のようなコマンドは個別に評価される：

- `cd /tmp && rm file.txt` → `cd /tmp` と `rm file.txt` を別々に評価
- `ls || echo error` → `ls` と `echo error` を別々に評価
- `git add . ; git commit -m "update"` → `git add .` と `git commit -m "update"` を別々に評価

それぞれのコマンドに対して個別にルールが適用され、いずれかが `block` された場合は実行が中断される

## ルールファイルの場所

以下の 2 つのファイルがマージされて使用される：

1. **グローバル設定**: 以下の優先順位で検索される
   - `$CLAUDE_CONFIG_DIR/hooks.config.json`（環境変数が設定されている場合）
   - `~/.config/claude/hooks.config.json`
   - `~/.claude/hooks.config.json`
2. **ローカル設定**: `.claude/hooks.config.json`（カレントディレクトリ）

### マージの仕組み

ルールは配列として定義され、ローカル → グローバルの順で結合される（ローカル優先）。以下の例で具体的な動作を示す：

```json
// グローバル (例: ~/.config/claude/hooks.config.json)
{
  "PreToolUse": {
    "Bash": [
      {
        "command": "rm",
        "args": "-rf",
        "reason": "強制削除は危険",
        "decision": "block"
      }
    ]
  }
}

// ローカル (.claude/hooks.config.json)
{
  "PreToolUse": {
    "Bash": [
      {
        "command": "rm",
        "args": "\\.tmp$",
        "reason": "一時ファイルの削除はOK",
        "decision": "approve"
      }
    ]
  }
}

// 実際に評価される結合結果
[
  // ローカルルールが先（優先）
  {
    "command": "rm",
    "args": "\\.tmp$",
    "reason": "一時ファイルの削除はOK",
    "decision": "approve"
  },
  // グローバルルールが後
  {
    "command": "rm",
    "args": "-rf",
    "reason": "強制削除は危険",
    "decision": "block"
  }
]
```

この例では、グローバル設定とローカル設定が結合され、評価時は結合された配列の全てのルールが対象となる

プロジェクト固有のルールを設定したい場合は、プロジェクトのルートディレクトリに `.claude/hooks.config.json` を配置する

## 評価の仕組み

### 配列内のルール評価

PreToolUse フックは、マージ後の配列を順番に評価し、最終的に **1 つの decision と reason** を Claude Code に返す

複数のルールがマッチした場合、優先順位に基づいて最も重要な decision が選ばれる：

```json
[
  {
    "command": "rm",
    "args": "\\.tmp$",
    "reason": "一時ファイル（.tmp）の削除はOK",
    "decision": "approve"
  },
  {
    "command": "rm",
    "args": "-rf",
    "reason": "強制削除は要確認"
  },
  {
    "command": "rm",
    "args": "/etc",
    "reason": "システムファイルは削除禁止",
    "decision": "block"
  }
]
```

`rm -rf /etc/test.tmp` の場合：

- `command: "rm", args: "\\.tmp$"` にマッチ → `approve`
- `command: "rm", args: "-rf"` にマッチ → `undefined`
- `command: "rm", args: "/etc"` にマッチ → `block`
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

### 全コマンド対象のルール

`command` フィールドを省略することで、全てのコマンドに適用されるルールを定義できる：

```json
[
  {
    "command": "touch",
    "reason": "touchコマンドは基本的に承認",
    "decision": "approve"
  },
  {
    "command": "touch",
    "args": "/etc",
    "reason": "システムファイルへのtouchは禁止",
    "decision": "block"
  },
  {
    "args": "--force",
    "reason": "全コマンドの--forceオプションは要確認"
  }
]
```

この場合の動作：

- `touch file.txt` → 自動承認（`command: "touch"` のみのルールにマッチ）
- `touch /etc/hosts` → ブロック（`command: "touch", args: "/etc"` にマッチ）
- `npm install --force` → 確認要求（`args: "--force"` にマッチ、全コマンド対象）

> **重要**: パターンマッチングはコマンドの引数部分に対して行われる。例えば `touch file.txt /etc/hosts` というコマンドの場合、パターンは `"file.txt /etc/hosts"` という引数部分に対して評価される。そのため `/etc` というパターンは、引数のどこかに `/etc` が含まれていればマッチする

## 設定例

### 危険なコマンドをブロック

```json
{
  "PreToolUse": {
    "Bash": {
      "rm": [
        {
          "pattern": "-rf\\s+\\*",
          "reason": "現在のディレクトリ全削除は禁止",
          "decision": "block"
        },
        {
          "pattern": "-rf\\s+~",
          "reason": "ホームディレクトリの削除は禁止",
          "decision": "block"
        }
      ]
    }
  }
}
```

### 安全なコマンドを自動承認

```json
{
  "PreToolUse": {
    "Bash": {
      "git": [
        {
          "pattern": "^(status|log|diff|branch)",
          "reason": "読み取り専用のgitコマンド",
          "decision": "approve"
        }
      ]
    }
  }
}
```

### コマンド全体に適用（パターン未指定）

```json
{
  "PreToolUse": {
    "Bash": {
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
}
```

## パターンの書き方

### 基本

- 正規表現（grep -E 形式）を使用
- JSON 内でのエスケープに注意（`\\` でエスケープ）

### よく使うパターン

| パターン   | 説明               | 例                                   |
| ---------- | ------------------ | ------------------------------------ |
| `^pattern` | 引数の先頭にマッチ | `^status` → `status -v` にマッチ     |
| `pattern$` | 引数の末尾にマッチ | `\.txt$` → `file.txt` にマッチ       |
| `\\s+`     | 空白文字           | `-rf\\s+\\*` → `-rf *` にマッチ      |
| `(A\|B)`   | A または B         | `^(add\|commit)` → `add` か `commit` |
| `.*`       | 任意の文字列       | `.*password.*` → パスワードを含む    |
| `[~/]`     | 文字クラス         | `[~/]` → `~` か `/` を含む           |

### セキュリティ上の注意事項

**コマンド置換に注意**：フックシステムはコマンド実行前の文字列のみを評価するため、コマンド置換 `$(...)` や `` `...` `` の中身は検査されません。

例：

- `echo $(rm -rf *)` → `echo` として評価され、承認される可能性がある
- 実行時にシェルが `$(rm -rf *)` を展開し、危険なコマンドが実行される

このため、`echo` などの一見安全なコマンドを無条件で approve する際は、コマンド置換による意図しない実行に注意が必要です

## ⚠️ 安全な動作テスト

Claude Code で実際に hooks として使用する前に、危険なコマンドが確実にブロックされるかテストすることを強く推奨します。特に `rm -rf ~/` などの破壊的なコマンドは、一度実行されると取り返しがつきません。

以下の方法で設定が意図通りに動作するか確認してください：

### 確認例

```bash
# 危険なコマンドの確認
echo '{"tool_input": {"command": "rm -rf ~/"}}' | ./hooks/pretooluse/bash/hook.sh
# 期待される出力: {"decision": "block", "reason": "⚠️ ホームディレクトリの削除は禁止"}

# 安全なコマンドの確認
echo '{"tool_input": {"command": "ls -la"}}' | ./hooks/pretooluse/bash/hook.sh
# lsがapprove設定の場合: {"decision": "approve", "reason": "lsコマンドは安全なので自動承認"}

# ルールにマッチしないコマンド
echo '{"tool_input": {"command": "echo hello"}}' | ./hooks/pretooluse/bash/hook.sh
# 期待される出力: {} （通常の確認フロー）
```
