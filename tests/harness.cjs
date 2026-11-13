// Roda um teste do FindUpgrade numa VM Lua 5.3 (fengari) com a API do WoW simulada (stubs.lua).
// O código do addon é o de verdade, carregado na ordem do FindUpgrade.toc.
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const ADDON = path.join(__dirname, '..', 'FindUpgrade');

function tocFiles() {
  return fs
    .readFileSync(path.join(ADDON, 'FindUpgrade.toc'), 'utf8')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
}

function run(name, setup, driver) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  lua.lua_newtable(L);
  tocFiles().forEach((file, i) => {
    lua.lua_newtable(L);
    lua.lua_pushstring(L, to_luastring(file));
    lua.lua_setfield(L, -2, to_luastring('name'));
    lua.lua_pushstring(L, to_luastring(fs.readFileSync(path.join(ADDON, file), 'utf8')));
    lua.lua_setfield(L, -2, to_luastring('src'));
    lua.lua_rawseti(L, -2, i + 1);
  });
  lua.lua_setglobal(L, to_luastring('ADDON_FILES'));
  const stubs = fs.readFileSync(path.join(__dirname, 'stubs.lua'), 'utf8');
  if (lauxlib.luaL_dostring(L, to_luastring(stubs + '\n' + setup + '\n' + driver)) !== lua.LUA_OK) {
    console.log(`ERRO ${name}:`, lua.lua_tojsstring(L, -1));
    process.exit(1);
  }
  console.log(`${name}: OK`);
}

module.exports = { run };
