# TODO

## 改善案

### 設定ファイルのフラット化

現在のコマンドごとの階層構造を、フラットな配列構造に変更する。

#### 現在の構造
```json
{
  "PreToolUse": {
    "Bash": {
      "rm": [
        { "pattern": "...", "decision": "block" }
      ],
      "git": [
        { "pattern": "push", "decision": "block" }
      ]
    }
  }
}
```

#### 提案する構造
```json
{
  "PreToolUse": {
    "Bash": [
      { "command": "rm", "args": "-rf.*", "decision": "block" },
      { "command": "git", "args": "push", "decision": "block" },
      { "command": "sudo", "decision": "block" },  // sudoコマンド全体をブロック
      { "args": "--force", "decision": "block" }   // commandを省略 = 全コマンドの--forceオプションをブロック
    ]
  },
  "PostToolUse": {
    "Bash": [
      { "command": "npm", "stdout": "vulnerability", "action": "log" },
      { "stdout": "password.*=", "action": "block" }  // 全コマンドの出力を監視
    ]
  }
}
```

#### メリット
- ルール管理が簡潔になる
- ワイルドカード（`*`）も通常のルールとして扱える
- 複数コマンドへの適用が容易（`command: ["rm", "cp", "mv"]`）
- ルールの優先順位が明確になる（配列の順序）
- フィールド名が明確になる（`pattern` → `args`, `output_pattern` → `stdout`, `error_pattern` → `stderr`）
- グローバル/ローカル設定のマージが単純化（配列の結合のみ）
- 実装コードが簡潔になる（単純な配列走査）

### PostToolUse アクションの整理

- `warn`/`error` アクションを削除（Claude Code上で表示されないため）
- `log` アクションのみを残す
- 必要に応じてログレベル（info/warn/error）を追加検討

### その他

- デバッグモード（`CLAUDE_HOOKS_DEBUG=1`）の実装
- テストスイートの追加
- パフォーマンス最適化（大量のルールがある場合の処理速度）