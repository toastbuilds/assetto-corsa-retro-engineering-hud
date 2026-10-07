const fs = require('fs')
const path = require('path')
const lua = require('luaparse')

const root = path.resolve(__dirname, '..')
const files = []

function collect(directory) {
  for (const entry of fs.readdirSync(path.join(root, directory), { withFileTypes: true })) {
    const relative = path.join(directory, entry.name)
    if (entry.isDirectory()) collect(relative)
    else if (entry.name.endsWith('.lua')) files.push(relative)
  }
}

for (const directory of ['src', 'ui', 'modules', 'tests']) collect(directory)
files.push('app.lua', 'RetroUI.lua')

let failures = 0
for (const file of files) {
  const code = fs.readFileSync(path.join(root, file), 'utf8')
  try {
    lua.parse(code, { luaVersion: '5.2' })
  } catch (error) {
    console.error(`${file}: ${error.message}`)
    failures++
  }
  for (const match of code.matchAll(/require\(['"]([^'"]+)['"]\)/g)) {
    if (!fs.existsSync(path.join(root, `${match[1]}.lua`))) {
      console.error(`${file}: missing module ${match[1]}`)
      failures++
    }
  }
}

const manifest = fs.readFileSync(path.join(root, 'manifest.ini'), 'utf8')
const app = fs.readFileSync(path.join(root, 'app.lua'), 'utf8')
const callbacks = [...manifest.matchAll(/^FUNCTION_(?:MAIN|ON_SHOW|ON_HIDE) = (\w+)$/gm)]
for (const [, callback] of callbacks) {
  if (!app.includes(`function script.${callback}(`)) {
    console.error(`manifest.ini: missing callback ${callback}`)
    failures++
  }
}
const windows = [...manifest.matchAll(/^ID = (\w+)$/gm)]
if (windows.length !== 11 || new Set(windows.map((match) => match[1])).size !== 11) {
  console.error(`manifest.ini: expected 11 distinct windows, got ${windows.length}`)
  failures++
}

console.log(`Checked ${files.length} Lua files, ${windows.length} windows and ${callbacks.length} callbacks`)
if (failures) process.exitCode = 1
