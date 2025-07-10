# Claude Hooks

Claude Code の動作を拡張・制御するフックコレクション

## 概要

このリポジトリは、Claude Code の [Hooks 機能](https://docs.anthropic.com/en/docs/claude-code/hooks)を利用して、各種ツールの実行を制御するシステムを提供します。

<img width="929" height="426" alt="image" src="https://github.com/user-attachments/assets/e4e07a05-0d40-4c20-8c8e-d5f266253e65" />


## セットアップ

1. このリポジトリをクローン

```bash
git clone https://github.com/miyaoka/claude-hooks.git
```

2. Claude Code の設定ファイル（settings.json）でフックスクリプトのパスを指定

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "[本リポジトリのパス]/hooks/pretooluse/bash/hook.sh" // ← 実際のパスを指定
          }
        ]
      }
    ]
  }
}
```

3. ルールファイルを設定

本リポジトリには設定のサンプルとして [`.claude/hooks.config.example.json`](.claude/hooks.config.example.json) が含まれています。これを参考に `hooks.config.json` を配置してください：

- **グローバルルール**: Claude Code の設定ディレクトリ（`~/.claude/` など）に `hooks.config.json` を配置
- **ローカルルール**: プロジェクトのルートに `.claude/hooks.config.json` を配置

※ グローバルとローカルの両方を設定した場合、両方のルールがマージされ、ローカルルールが優先されます

## 利用可能なフック

### [PreToolUse/Bash](hooks/pretooluse/bash/docs/user-guide.md)

Bash コマンドの実行を制御するフック

- 危険なコマンドをブロック
- 特定のコマンドを自動承認
- パターンマッチングによる柔軟な制御

**⚠️ 重要**: 実際に Claude で実行する前に、設定したルールが確実にマッチするかテストすることをお勧めします：

→ 詳細は [安全な動作テスト](hooks/pretooluse/bash/docs/user-guide.md#安全な動作テスト) を参照してください。

## ライセンス

[MIT](LICENSE)
