# PreToolUse/Bash フック

Bash コマンドの実行を制御する PreToolUse フック

## ドキュメント

- [**docs/user-guide.md**](docs/user-guide.md) - ユーザー向け設定ガイド
- [**docs/development.md**](docs/development.md) - 開発者向け実装仕様

## 概要

このフックは Claude Code が Bash ツールを使用する前に介入し、コマンドの実行を制御します。ルールファイルに基づいて、コマンドを自動承認、ブロック、またはユーザー確認を要求できます。

## ファイル構成

```
hooks/pretooluse/bash/
├── hook.sh          # エントリーポイント
├── evaluator.sh     # 評価エンジン
└── docs/
    ├── README.md    # このファイル
    ├── user-guide.md
    └── development.md
```