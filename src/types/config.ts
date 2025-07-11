/**
 * Hook 設定ファイルの型定義
 */

import type { HookDecision } from './hooks'

// ルール（PreToolUse用）
export interface Rule {
  // コマンド名（オプション、省略時は全コマンドに適用）
  command?: string
  // 引数の正規表現パターン（オプション）
  args?: string
  // 理由の説明
  reason: string
  // 決定（オプション、省略時は undefined = 通常フロー）
  decision?: 'block' | 'approve'
}

// ルール（PostToolUse用）
export interface PostRule {
  // コマンド名（オプション、省略時は全コマンドに適用）
  command?: string
  // 引数の正規表現パターン（オプション）
  args?: string
  // 標準出力に対する正規表現パターン（オプション）
  stdout?: string
  // 標準エラー出力に対する正規表現パターン（オプション）
  stderr?: string
  // アクション（オプション、省略時は何もしない）
  action?: 'block' | 'log'
  // 理由の説明
  reason: string
}

// ツール固有の設定
export interface ToolConfig {
  // ルールの配列
  rules: Rule[]
  // デフォルトの決定（ルールにマッチしない場合）
  default_decision?: HookDecision
  // デフォルトの理由
  default_reason?: string
}

// Hook タイプごとの設定
export interface HookTypeConfig {
  [toolName: string]: Rule[] | ToolConfig
}

// 設定ファイル全体の構造
export interface HookConfig {
  // Hook タイプごとの設定
  PreToolUse?: HookTypeConfig
  PostToolUse?: HookTypeConfig
  Notification?: HookTypeConfig
  Stop?: HookTypeConfig
  SubagentStop?: HookTypeConfig
  PreCompact?: HookTypeConfig

  // グローバル設定
  global?: {
    // ログレベル
    log_level?: 'debug' | 'info' | 'warn' | 'error'
    // ログファイルのパス
    log_file?: string
    // タイムアウト（ミリ秒）
    timeout?: number
  }
}

// フラット構造のルール（後方互換性のため）
export type FlatRule = Rule

// フラット構造の設定（後方互換性のため）
export interface FlatHookConfig {
  PreToolUse?: {
    [toolName: string]: FlatRule[]
  }
  PostToolUse?: {
    [toolName: string]: FlatRule[]
  }
}
