# TODO

## 改善案

### PostToolUse アクションの整理

- `warn`/`error` アクションを削除（Claude Code上で表示されないため）
- `log` アクションのみを残す
- 必要に応じてログレベル（info/warn/error）を追加検討


### その他

- デバッグモード（`CLAUDE_HOOKS_DEBUG=1`）の実装
- テストスイートの追加
- パフォーマンス最適化（大量のルールがある場合の処理速度）

## 完了済み

### 設定ファイルのフラット化 ✅ (2025-07-10)

現在のコマンドごとの階層構造を、フラットな配列構造に変更しました。

#### 旧構造（階層型）
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

#### 新構造（フラット配列）
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

#### 実装完了内容

- ✅ ルール管理が簡潔になった
- ✅ ワイルドカード（`*`）も通常のルールとして扱える
- ✅ 複数コマンドへの適用が容易（将来的に`command: ["rm", "cp", "mv"]`をサポート予定）
- ✅ ルールの優先順位が明確になった（配列の順序）
- ✅ フィールド名が明確になった（`pattern` → `args`, `output_pattern` → `stdout`, `error_pattern` → `stderr`）
- ✅ グローバル/ローカル設定のマージが単純化（配列の結合のみ）
- ✅ 実装コードが簡潔になった（単純な配列走査）
- ✅ 後方互換性のため階層型の実装も保持（`*_hierarchical.sh`）

### 配列の畳み込み処理実装 ✅ (2025-07-11)

グローバルとローカルの設定マージ時に、重複するルールを適切に上書きする畳み込み処理を実装しました。

#### 実装内容
- command が同じで args がないルール → 後続のルールで上書き
- command と args が完全一致するルール → 後続のルールで上書き
- グローバル + ローカルの順でマージし、ローカルが優先される

#### 動作例
```json
// グローバル: { "command": "echo", "args": "hello", "decision": "block" }
// ローカル:   { "command": "echo", "args": "hello", "decision": "approve" }
// 結果:       ローカルのapproveが適用される
```

これにより：
- ✅ 重複ルールの明確な上書き
- ✅ ローカル設定でのプロジェクト固有の例外設定が可能
- ✅ 実装の簡素化（単純な配列走査）