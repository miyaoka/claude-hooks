# PostToolUse Hook 実装仕様書

## 概要

Claude Code の PostToolUse フックシステムの内部実装仕様。一般的な使用方法については [README.md](../README.md) を参照

この実装は [Claude Code Hooks API](https://docs.anthropic.com/en/docs/claude-code/hooks) に基づいている

## PreToolUse との主な違い

1. **実行タイミング**: コマンド実行**後**に呼ばれる（成功時のみ）
2. **入力形式**: `tool_response` に実行結果が含まれる
3. **戻り値**: `action` を返し、実際の処理も実行する
4. **制約**: エラーが発生したコマンドでは呼ばれない

## ファイル構成

### 設定ファイル

```
# グローバル設定（以下の優先順位で検索）
$CLAUDE_CONFIG_DIR/hooks.config.json      # 環境変数で指定された場合
~/.config/claude/hooks.config.json
~/.claude/hooks.config.json

# ローカル設定（未実装）
プロジェクトディレクトリ/
└── .claude/
    └── hooks.config.json
```

### 本リポジトリ

```
claude-hooks/
├── hooks/
│   ├── lib/
│   │   ├── common.sh       # 共通ライブラリ
│   │   └── hook_base.sh    # フック共通ベース
│   └── posttooluse/bash/
│       ├── hook.sh         # フックスクリプト（エントリーポイント）
│       ├── evaluator.sh    # 評価エンジン
│       └── README.md       # ユーザーガイド
```

## hook.sh の仕様

### 入力

標準入力から JSON 形式でツール実行結果を受け取る

#### 入力形式

```json
{
  "session_id": "6f02b9c8-25fc-457a-92f0-12006944c9bc",
  "transcript_path": "/home/user/.claude/projects/...",
  "hook_event_name": "PostToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "echo log",
    "description": "コマンドの説明（オプション）"
  },
  "tool_response": {
    "stdout": "標準出力の内容",
    "stderr": "標準エラー出力の内容",
    "interrupted": false,
    "isImage": false
  }
}
```

### Claude Code API の仕様

- **exit_code は提供されない**: Claude Code の仕様により、終了コードは含まれない
- **エラー時は呼ばれない**: コマンドがエラーになった場合、PostToolUse フックは実行されない
- **success フィールドなし**: PreToolUse とは異なり、成功/失敗の明示的なフラグはない

### 処理フロー

1. **入力検証**
   - JSON の読み取りと検証
   - `interrupted` が true の場合は処理をスキップ

2. **設定読み込み**
   - グローバル設定から PostToolUse/Bash セクションを取得
   - ローカル設定のマージは現在未実装

3. **コマンド評価**
   - evaluator.sh に処理を委譲
   - コマンド、stdout、stderr に基づいてルールマッチング

4. **アクション実行**
   - evaluator.sh 内でアクションを実行（ログ記録、警告表示など）

### 出力

```json
// 通常の場合
{}

// ブロックする場合（ツールは既に実行済み）
{"decision": "block", "reason": "ブロック理由"}
```

フックが exit 1 で終了した場合、stderr の内容が Claude に表示される

## evaluator.sh の仕様

### アクション定義

```bash
readonly ACTION_BLOCK="block"
readonly ACTION_LOG="log"
readonly ACTION_WARN="warn"
readonly ACTION_IGNORE="ignore"
readonly ACTION_ERROR="error"
```

### 評価関数

#### evaluate_posttooluse_command()

メイン評価関数。以下の処理を行う：

1. tool_response から情報を抽出
2. 各コマンドに対してルール評価
3. 最も優先度の高いアクションを決定
4. アクションを実行

#### evaluate_rules()

個別のルール評価：

1. パターンマッチング（コマンド引数、stdout、stderr）
2. すべての条件が AND で評価
3. マッチした場合、優先度に基づいてアクションを更新

### アクション実行

- **log**: `log_command_result()` でファイルに記録
- **warn/error**: stderr に警告メッセージを出力、exit 1
- **block**: decision を返す（Claudeに自動的にreasonをプロンプトし、後続処理を停止）
- **ignore**: 何もしない

### ログファイル

デフォルト: `~/.claude/hooks-command.log`

形式：
```
=== 2025-07-11 07:20:18 ===
Command: echo log
Output:
log

```

環境変数 `CLAUDE_HOOKS_LOG` で変更可能

## hooks.config.json の仕様

### 構造

```json
{
  "PostToolUse": {
    "Bash": {
      "コマンド名": [
        {
          "pattern": "コマンド引数の正規表現",
          "output_pattern": "標準出力の正規表現",
          "error_pattern": "標準エラー出力の正規表現",
          "action": "log|warn|error|ignore",
          "reason": "アクションの理由"
        }
      ],
      "*": [
        // ワイルドカードルール（すべてのコマンドにマッチ）
      ]
    }
  }
}
```

### マッチング条件

- `pattern`: コマンド引数に対する正規表現
- `output_pattern`: stdout に対する正規表現
- `error_pattern`: stderr に対する正規表現

すべての指定された条件が AND で評価される

### アクションの優先順位

`block` > `error` > `warn` > `log` > `ignore`

複数のルールがマッチした場合、最も優先度の高いアクションが採用される

## 共通ライブラリ (common.sh)

PostToolUse は以下の共通関数を使用：

- `extract_json_value()`: JSON から値を抽出
- `find_claude_config_dir()`: 設定ディレクトリを検索
- `parse_commands()`: 複合コマンドをパース
- `extract_command_name()`: コマンド名を抽出
- `extract_command_args()`: コマンド引数を抽出
- `should_update_by_priority()`: 優先順位判定
- `match_pattern()`: パターンマッチング
- `create_result_json()`: 結果 JSON 生成

## テスト方法

### 手動テスト

```bash
# テスト用 JSON を作成
echo '{"tool_input": {"command": "echo log"}, "tool_response": {"stdout": "log", "stderr": "", "interrupted": false, "isImage": false}}' | ./hooks/posttooluse/bash/hook.sh
```

### 実環境での確認

1. Claude Code で対象コマンドを実行
2. ログファイルまたは警告メッセージを確認

## 既知の制限

1. **warn/error アクションが無効**: stderrへの出力はClaude Codeでは表示されない

## デバッグ

環境変数でデバッグログを有効化（未実装）：
```bash
export CLAUDE_HOOKS_DEBUG=1
```

現在は必要に応じて `echo "debug" >&2` を追加してデバッグ