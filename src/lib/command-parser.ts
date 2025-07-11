/**
 * コマンドパーサー
 * 複合コマンドを個別のコマンドに分解する
 */

// パースされたコマンド
export interface ParsedCommand {
  command: string
  separator?: '&&' | '||' | ';' | '|'
}

/**
 * 複合コマンドを個別のコマンドに分解
 * 例: "cd ~/.claude && echo hello && touch foo.txt bar.txt"
 * → [
 *     { command: "cd ~/.claude", separator: "&&" },
 *     { command: "echo hello", separator: "&&" },
 *     { command: "touch foo.txt bar.txt" }
 *   ]
 */
export function parseCommands(input: string): ParsedCommand[] {
  const commands: ParsedCommand[] = []
  let current = ''
  let inSingleQuote = false
  let inDoubleQuote = false
  let escapeNext = false
  let i = 0

  while (i < input.length) {
    const char = input[i]
    const next = input[i + 1]

    // エスケープ処理
    if (escapeNext) {
      current += char
      escapeNext = false
      i++
      continue
    }

    // バックスラッシュ
    if (char === '\\') {
      current += char
      escapeNext = true
      i++
      continue
    }

    // クォート処理
    if (char === "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote
      current += char
      i++
      continue
    }

    if (char === '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote
      current += char
      i++
      continue
    }

    // クォート外でセパレータをチェック
    if (!inSingleQuote && !inDoubleQuote) {
      // && をチェック
      if (char === '&' && next === '&') {
        if (current.trim()) {
          commands.push({
            command: current.trim(),
            separator: '&&'
          })
          current = ''
        }
        i += 2
        continue
      }

      // || をチェック
      if (char === '|' && next === '|') {
        if (current.trim()) {
          commands.push({
            command: current.trim(),
            separator: '||'
          })
          current = ''
        }
        i += 2
        continue
      }

      // ; をチェック
      if (char === ';') {
        if (current.trim()) {
          commands.push({
            command: current.trim(),
            separator: ';'
          })
          current = ''
        }
        i++
        continue
      }

      // | (パイプ) をチェック
      if (char === '|') {
        if (current.trim()) {
          commands.push({
            command: current.trim(),
            separator: '|'
          })
          current = ''
        }
        i++
        continue
      }
    }

    // 通常の文字
    current += char
    i++
  }

  // 最後のコマンドを追加
  if (current.trim()) {
    commands.push({
      command: current.trim()
    })
  }

  return commands
}
