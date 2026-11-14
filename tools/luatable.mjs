// Lê uma tabela Lua (formato das SavedVariables ou dos arquivos de dados dos addons) e devolve em JS.
// Mesmo leitor do sync.mjs do vault.

export const LUA_ESCAPES = { n: '\n', t: '\t', r: '\r', a: '\x07', b: '\b', f: '\f', v: '\v' };

export function luaUnescape(s) {
  return s.replace(/\\(\d{1,3}|[\s\S])/g, (_, c) => (/^\d+$/.test(c) ? String.fromCharCode(Number(c)) : LUA_ESCAPES[c] ?? c));
}

// Lê um campo string ["nome"] = "..." das SavedVariables e desfaz o escape de string do Lua.
export function luaString(text, field) {
  const re = new RegExp('\\["' + field + '"\\]\\s*=\\s*"((?:[^"\\\\]|\\\\[\\s\\S])*)"');
  const m = text.match(re);
  return m ? luaUnescape(m[1]) : null;
}

// Lê uma tabela Lua no formato das SavedVariables (VaultSyncAH = { ... }) e devolve em JS.
// Tabela com só 1..n vira array. Comentário '-- [n]' e chave nua (sem colchete) também valem.
export function luaTable(text, name) {
  const start = text.search(new RegExp('^' + name + '\\s*=', 'm'));
  if (start < 0) return null;
  let i = text.indexOf('=', start) + 1;
  const ws = () => {
    for (;;) {
      while (i < text.length && /\s/.test(text[i])) i++;
      if (text.startsWith('--', i)) { while (i < text.length && text[i] !== '\n') i++; } else return;
    }
  };
  const value = () => {
    ws();
    const c = text[i];
    if (c === '{') {
      i++;
      const obj = {};
      let n = 0;
      for (;;) {
        ws();
        if (text[i] === '}') { i++; break; }
        let key;
        if (text[i] === '[') { i++; key = value(); ws(); i++; ws(); i++; } // [k] =
        else {
          const m = /^[A-Za-z_]\w*\s*=(?!=)/.exec(text.slice(i, i + 80));
          if (m) { key = m[0].replace(/\s*=$/, ''); i += m[0].length; } else key = ++n;
        }
        obj[key] = value();
        ws();
        if (text[i] === ',' || text[i] === ';') i++;
      }
      const keys = Object.keys(obj);
      return keys.length && keys.every((k, j) => Number(k) === j + 1) ? keys.map((k) => obj[k]) : obj;
    }
    if (c === '"') {
      let j = i + 1;
      while (text[j] !== '"') j += text[j] === '\\' ? 2 : 1;
      const raw = text.slice(i + 1, j);
      i = j + 1;
      return luaUnescape(raw);
    }
    const m = /^(-?[\d.]+(?:[eE][-+]?\d+)?|true|false|nil)/.exec(text.slice(i, i + 40));
    if (!m) throw new Error('Lua inesperado em ' + i + ': ' + text.slice(i, i + 30));
    i += m[0].length;
    return m[0] === 'true' ? true : m[0] === 'false' ? false : m[0] === 'nil' ? null : Number(m[0]);
  };
  return value();
}
