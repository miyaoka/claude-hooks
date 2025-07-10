# Claude Hooks

Claude Code の動作を拡張・制御するフックコレクション

## 概要

このリポジトリは、Claude Code の [Hooks 機能](https://docs.anthropic.com/en/docs/claude-code/hooks)を利用して、各種ツールの実行を制御するシステムを提供します。

## セットアップ

1. このリポジトリをクローン

```bash
git clone https://github.com/miyaoka/claude-hooks.git
```

2. Claude Code の設定ファイル（settings.json）でフックのパスを指定

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

```bash
# ローカル設定（プロジェクト固有のルール）
cp .claude/hooks.config.example.json .claude/hooks.config.json
# 必要に応じて編集

# グローバル設定（全プロジェクト共通のルール）も追加する場合
# Claude Code の設定ディレクトリにもコピー
# cp .claude/hooks.config.example.json ~/path/to/claude/config/hooks.config.json
```

※ グローバルとローカルの両方を設定した場合、両方のルールがマージされ、ローカルルールが優先されます

## 利用可能なフック

### [PreToolUse/Bash](hooks/pretooluse/bash/)

Bash コマンドの実行を制御するフック

- 危険なコマンドをブロック
- 特定のコマンドを自動承認
- パターンマッチングによる柔軟な制御

## 設定例

設定例は [`.claude/hooks.config.example.json`](.claude/hooks.config.example.json) を参照してください。

詳細な設定方法は各フックのドキュメントを参照してください。

## ライセンス

MIT
