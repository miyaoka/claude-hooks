# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Claude Code の [Hooks 機能](https://docs.anthropic.com/en/docs/claude-code/hooks)を利用して、各種ツールの実行を設定ファイルベースで制御するシステム

## アーキテクチャ

### ディレクトリ構造

```
hooks/
├── lib/             # 共通ライブラリ
│   └── common.sh    # 共通関数
├── pretooluse/      # PreToolUseフック
│   └── bash/        # Bashツール用
└── posttooluse/     # PostToolUseフック
    └── bash/        # Bashツール用
```

### 実装済みフック

- [PreToolUse/Bash](hooks/pretooluse/bash/README.md) - Bash コマンドの実行制御
- [PostToolUse/Bash](hooks/posttooluse/bash/README.md) - Bash コマンドの実行後処理
