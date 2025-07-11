# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Claude Code の [Hooks 機能](https://docs.anthropic.com/en/docs/claude-code/hooks)を利用して、各種ツールの実行を設定ファイルベースで制御するシステム

## Claude Code 設定

Claude Code の設定ファイル (settings.json) は以下の優先順位で読み込まれる：

1. `CLAUDE_CONFIG_DIR` 環境変数で指定されたディレクトリ
2. `~/.config/claude`
3. `~/.claude`

## アーキテクチャ

### ディレクトリ構造

```
hooks/              # シェルスクリプト実装（オリジナル）
├── lib/             # 共通ライブラリ
│   └── common.sh    # 共通関数
├── pretooluse/      # PreToolUseフック
│   └── bash/        # Bashツール用
└── posttooluse/     # PostToolUseフック
    └── bash/        # Bashツール用

src/                # TypeScript実装（新規）
├── types/          # 型定義
├── lib/            # 共通ライブラリ
│   ├── evaluator.ts     # ルール評価エンジン
│   ├── command-parser.ts # コマンドパーサー
│   └── config-loader.ts  # 設定ローダー
└── hooks/          # フック実装
    ├── pretooluse/
    │   └── bash.ts      # PreToolUse/Bashフック
    └── posttooluse/
        └── bash.ts      # PostToolUse/Bashフック
```

### 実装済みフック

#### シェルスクリプト版（安定版）
- [PreToolUse/Bash](hooks/pretooluse/bash/README.md) - Bash コマンドの実行制御
- [PostToolUse/Bash](hooks/posttooluse/bash/README.md) - Bash コマンドの実行後処理

#### TypeScript版（開発中）
- [TypeScript実装](src/README.md) - Bunランタイムを使用したTypeScript版
