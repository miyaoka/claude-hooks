# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Claude Code の各種フック処理を管理するシステム。

## アーキテクチャ

### ディレクトリ構造

```
hooks/
└── pretooluse/      # PreToolUseフック
    └── bash/        # Bashツール用
```

### 実装済みフック

- [PreToolUse/Bash](hooks/pretooluse/bash/README.md) - Bash コマンドの実行制御
