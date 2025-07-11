# Claude Hooks TypeScript実装

このディレクトリにはClaude Code Hooksのシェルスクリプト版をTypeScriptに移植した実装が含まれています。

## セットアップ

### 1. Bunのインストール

```bash
# macOS/Linux
curl -fsSL https://bun.sh/install | bash

# Windows (WSL)
curl -fsSL https://bun.sh/install | bash
```

### 2. 依存関係のインストール

```bash
bun install
```

### 3. Claude Code設定

Claude Codeの設定ファイル（`~/.claude/settings.json` または `~/.config/claude/settings.json`）に以下を追加：

```json
{
  "tools": {
    "hooks": [
      {
        "hook_type": "PreToolUse",
        "tool_name": "Bash",
        "command": "/path/to/claude-hooks/src/hooks/pretooluse/bash.ts"
      },
      {
        "hook_type": "PostToolUse",
        "tool_name": "Bash",
        "command": "/path/to/claude-hooks/src/hooks/posttooluse/bash.ts"
      }
    ]
  }
}
```

### 4. フック設定

フック設定ファイル（`~/.claude/hooks.config.json`）を作成：

```json
{
  "PreToolUse": {
    "Bash": [
      {
        "command": "rm",
        "args": "^-rf",
        "reason": "強制削除は危険な操作です",
        "decision": "block"
      }
    ]
  },
  "PostToolUse": {
    "Bash": [
      {
        "stdout": "password|secret",
        "action": "block",
        "reason": "機密情報が含まれています"
      }
    ]
  }
}
```

## テスト

```bash
# すべてのテストを実行
bun test

# ウォッチモードでテスト
bun test:watch

# カバレッジ付きでテスト
bun test:coverage
```

## アーキテクチャ

```
src/
├── types/           # 型定義
├── lib/            # 共通ライブラリ
│   ├── evaluator.ts     # ルール評価エンジン
│   ├── command-parser.ts # コマンドパーサー
│   └── config-loader.ts  # 設定ファイルローダー
└── hooks/          # フック実装
    ├── pretooluse/
    │   └── bash.ts      # PreToolUse/Bashフック
    └── posttooluse/
        └── bash.ts      # PostToolUse/Bashフック
```

## 開発

### TDDアプローチ

このプロジェクトはTest-Driven Development (TDD)で開発されています：

1. **型定義** - まず型を定義
2. **空実装** - 型が通る最小限の実装
3. **テスト** - 仕様を満たすテストを記述
4. **実装** - テストが通る実装を追加

### 設定ファイルの優先順位

1. ローカル設定: `.claude/hooks.config.json`
2. グローバル設定（環境変数）: `$CLAUDE_CONFIG_DIR/hooks.config.json`
3. グローバル設定: `~/.config/claude/hooks.config.json`
4. グローバル設定: `~/.claude/hooks.config.json`

ローカル設定が最優先され、グローバル設定の内容を上書きします。