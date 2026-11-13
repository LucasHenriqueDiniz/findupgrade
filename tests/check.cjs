// Confere a sintaxe Lua 5.1 (a do WoW) de todo arquivo do addon.
const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

const dir = path.join(__dirname, '..', 'FindUpgrade');
let bad = 0;
for (const f of fs.readdirSync(dir).filter((n) => n.endsWith('.lua'))) {
  try {
    luaparse.parse(fs.readFileSync(path.join(dir, f), 'utf8'), { luaVersion: '5.1' });
  } catch (e) {
    console.log(`ERRO de sintaxe em ${f}:`, e.message);
    bad++;
  }
}
if (bad) process.exit(1);
console.log('sintaxe Lua 5.1: OK');
