import { existsSync, readFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'
import type { Rule } from '../types/config'

interface HooksConfig {
  PreToolUse?: {
    Bash?: Rule[]
  }
}

/**
 * 設定ファイルを読み込む（PreToolUse用）
 */
export function loadConfig(): Rule[] {
  const rules: Rule[] = []

  // 設定ファイルのパスを決定
  const configPaths = [
    // ローカル設定（最優先）
    join(process.cwd(), '.claude', 'hooks.config.json'),

    // グローバル設定
    process.env.CLAUDE_CONFIG_DIR ? join(process.env.CLAUDE_CONFIG_DIR, 'hooks.config.json') : null,
    join(homedir(), '.config', 'claude', 'hooks.config.json'),
    join(homedir(), '.claude', 'hooks.config.json')
  ].flatMap(path => (path ? [path] : []))

  // 各設定ファイルを読み込んでマージ
  for (const configPath of configPaths.reverse()) {
    // グローバルから読んでローカルで上書き
    if (existsSync(configPath)) {
      try {
        const content = readFileSync(configPath, 'utf-8')
        const config: HooksConfig = JSON.parse(content)

        if (config.PreToolUse?.Bash) {
          rules.push(...config.PreToolUse.Bash)
        }
      } catch (error) {
        // 設定ファイルの読み込みエラーは無視
        console.error(`Failed to load config from ${configPath}:`, error)
      }
    }
  }

  return rules
}
