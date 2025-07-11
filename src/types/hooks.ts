/**
 * Claude Code Hooks の型定義
 */

// Hook のタイプ
export type HookType = 'PreToolUse' | 'PostToolUse' | 'Notification' | 'Stop' | 'SubagentStop' | 'PreCompact'

// ツールの種類
export type ToolName =
  | 'Bash'
  | 'Edit'
  | 'Read'
  | 'Write'
  | 'MultiEdit'
  | 'Grep'
  | 'Glob'
  | 'LS'
  | 'Task'
  | 'WebSearch'
  | 'WebFetch'
  | 'TodoWrite'
  | 'NotebookRead'
  | 'NotebookEdit'

// Hook の決定結果
export type HookDecision = 'approve' | 'block'

// Hook の入力（Claude Code から受け取る JSON）
export interface HookInput {
  // PreToolUse/PostToolUse で共通
  tool_name: string
  tool_input: Record<string, unknown>

  // PostToolUse の場合のみ
  tool_response?: Record<string, unknown>
  session_id?: string
  transcript_path?: string
  hook_event_name?: string
}

// Bash Hook用の入力
export interface BashHookInput {
  tool_name: 'Bash'
  tool_input: BashToolInput
  tool_response?: BashToolResponse
  session_id?: string
  transcript_path?: string
  hook_event_name?: string
}

// Hook の出力（Claude Code に返す JSON）
export interface HookOutput {
  decision?: 'block' | 'approve'
  reason?: string

  // PostToolUse用
  action?: 'block' | 'log'
}

// Bash ツールの入力
export interface BashToolInput {
  command: string
  description?: string
  working_directory?: string
  timeout?: number
}

// Bash ツールの実行結果（PostToolUse で受け取る）
export interface BashToolResponse {
  stdout: string
  stderr: string
  interrupted: boolean
  isImage: boolean
}
