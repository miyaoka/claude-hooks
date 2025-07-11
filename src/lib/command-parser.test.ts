import { describe, expect, test } from 'bun:test'
import { parseCommands } from './command-parser'

describe('parseCommands', () => {
  test('単一コマンドの場合、1要素の配列を返す', () => {
    // 仕様: 複合コマンドでない場合はそのまま1つのコマンドとして返す
    const input = 'ls -la'
    const result = parseCommands(input)

    expect(result).toHaveLength(1)
    expect(result[0]).toEqual({
      command: 'ls -la'
      // separator は undefined
    })
  })

  test('&&で繋がれたコマンドを分解する', () => {
    // 仕様: && は「前のコマンドが成功したら次を実行」の意味
    const input = 'cd ~/.claude && echo hello'
    const result = parseCommands(input)

    expect(result).toHaveLength(2)
    expect(result[0]).toEqual({
      command: 'cd ~/.claude',
      separator: '&&'
    })
    expect(result[1]).toEqual({
      command: 'echo hello'
    })
  })

  test('||で繋がれたコマンドを分解する', () => {
    // 仕様: || は「前のコマンドが失敗したら次を実行」の意味
    const input = 'test -f file.txt || touch file.txt'
    const result = parseCommands(input)

    expect(result).toHaveLength(2)
    expect(result[0]).toEqual({
      command: 'test -f file.txt',
      separator: '||'
    })
    expect(result[1]).toEqual({
      command: 'touch file.txt'
    })
  })

  test(';で繋がれたコマンドを分解する', () => {
    // 仕様: ; は「前のコマンドの結果に関わらず次を実行」の意味
    const input = 'echo start; sleep 1; echo end'
    const result = parseCommands(input)

    expect(result).toHaveLength(3)
    expect(result[0]).toEqual({
      command: 'echo start',
      separator: ';'
    })
    expect(result[1]).toEqual({
      command: 'sleep 1',
      separator: ';'
    })
    expect(result[2]).toEqual({
      command: 'echo end'
    })
  })

  test('|（パイプ）で繋がれたコマンドを分解する', () => {
    // 仕様: | は「前のコマンドの出力を次のコマンドの入力に」の意味
    const input = 'cat file.txt | grep pattern | wc -l'
    const result = parseCommands(input)

    expect(result).toHaveLength(3)
    expect(result[0]).toEqual({
      command: 'cat file.txt',
      separator: '|'
    })
    expect(result[1]).toEqual({
      command: 'grep pattern',
      separator: '|'
    })
    expect(result[2]).toEqual({
      command: 'wc -l'
    })
  })

  test('シングルクォート内のセパレータは分割しない', () => {
    // 仕様: シングルクォート内の文字はリテラルとして扱う
    const input = "echo 'hello && world'"
    const result = parseCommands(input)

    expect(result).toHaveLength(1)
    expect(result[0]).toEqual({
      command: "echo 'hello && world'"
    })
  })

  test('ダブルクォート内のセパレータは分割しない', () => {
    // 仕様: ダブルクォート内の文字もセパレータとして扱わない
    const input = 'echo "hello && world"'
    const result = parseCommands(input)

    expect(result).toHaveLength(1)
    expect(result[0]).toEqual({
      command: 'echo "hello && world"'
    })
  })

  test('エスケープされたセパレータは分割しない', () => {
    // 仕様: バックスラッシュでエスケープされた文字はリテラル
    const input = 'echo hello \\&& world'
    const result = parseCommands(input)

    expect(result).toHaveLength(1)
    expect(result[0]).toEqual({
      command: 'echo hello \\&& world'
    })
  })

  test('複数種類のセパレータが混在する場合', () => {
    // 仕様: 異なるセパレータも正しく認識して分割
    const input = 'cmd1 && cmd2 || cmd3; cmd4 | cmd5'
    const result = parseCommands(input)

    expect(result).toHaveLength(5)
    expect(result[0]).toEqual({ command: 'cmd1', separator: '&&' })
    expect(result[1]).toEqual({ command: 'cmd2', separator: '||' })
    expect(result[2]).toEqual({ command: 'cmd3', separator: ';' })
    expect(result[3]).toEqual({ command: 'cmd4', separator: '|' })
    expect(result[4]).toEqual({ command: 'cmd5' })
  })

  test('前後の空白は削除される', () => {
    // 仕様: コマンドの前後の空白はトリムされる
    const input = '  echo hello  &&   echo world  '
    const result = parseCommands(input)

    expect(result).toHaveLength(2)
    expect(result[0]).toEqual({
      command: 'echo hello',
      separator: '&&'
    })
    expect(result[1]).toEqual({
      command: 'echo world'
    })
  })

  test('実際の例：cd && echo && touch', () => {
    // ドキュメントの例
    const input = 'cd ~/.claude && echo hello && touch foo.txt bar.txt'
    const result = parseCommands(input)

    expect(result).toHaveLength(3)
    expect(result[0]).toEqual({
      command: 'cd ~/.claude',
      separator: '&&'
    })
    expect(result[1]).toEqual({
      command: 'echo hello',
      separator: '&&'
    })
    expect(result[2]).toEqual({
      command: 'touch foo.txt bar.txt'
    })
  })

  test('シングルクォート内の複数のセパレータを含む文字列', () => {
    // 仕様: シングルクォート内のすべてのセパレータはリテラル
    const input = "echo 'This && has || many ; separators | inside'"
    const result = parseCommands(input)

    expect(result).toHaveLength(1)
    expect(result[0]).toEqual({
      command: "echo 'This && has || many ; separators | inside'"
    })
  })

  test('ダブルクォート内の複数のセパレータを含む文字列', () => {
    // 仕様: ダブルクォート内のすべてのセパレータもリテラル
    const input = 'echo "This && has || many ; separators | inside"'
    const result = parseCommands(input)

    expect(result).toHaveLength(1)
    expect(result[0]).toEqual({
      command: 'echo "This && has || many ; separators | inside"'
    })
  })

  test('文字列の途中でクォートが始まる場合', () => {
    // 仕様: コマンドの途中からクォートが始まってもセパレータは保護される
    const input = 'echo test"&&"test && echo done'
    const result = parseCommands(input)

    expect(result).toHaveLength(2)
    expect(result[0]).toEqual({
      command: 'echo test"&&"test',
      separator: '&&'
    })
    expect(result[1]).toEqual({
      command: 'echo done'
    })
  })

  test('ネストしたクォート（シングル内のダブル）', () => {
    // 仕様: シングルクォート内ではダブルクォートも通常の文字
    const input = 'echo \'He said "Hello && Goodbye"\' && echo done'
    const result = parseCommands(input)

    expect(result).toHaveLength(2)
    expect(result[0]).toEqual({
      command: 'echo \'He said "Hello && Goodbye"\'',
      separator: '&&'
    })
    expect(result[1]).toEqual({
      command: 'echo done'
    })
  })

  test('ネストしたクォート（ダブル内のシングル）', () => {
    // 仕様: ダブルクォート内ではシングルクォートも通常の文字
    const input = 'echo "It\'s a && b" && echo done'
    const result = parseCommands(input)

    expect(result).toHaveLength(2)
    expect(result[0]).toEqual({
      command: 'echo "It\'s a && b"',
      separator: '&&'
    })
    expect(result[1]).toEqual({
      command: 'echo done'
    })
  })

  test('閉じられていないクォート', () => {
    // 仕様: 閉じられていないクォートがある場合、最後まで文字列として扱う
    const input = 'echo "unclosed && echo should not split'
    const result = parseCommands(input)

    expect(result).toHaveLength(1)
    expect(result[0]).toEqual({
      command: 'echo "unclosed && echo should not split'
    })
  })
})
