// Gera FindUpgrade/SourcesData.lua: o banco de fontes do modo "Quests e dungeons".
//
// Junta, num formato compacto, o que vale pra achar upgrade fora do leilão:
//   · tools/fontes/lootgoblin/ForeverSources.local.lua (LootGoblin 1.3.0): cada item equipável
//     com as fontes (quest com id, boss de dungeon, vendedor, reputação), o level pedido e a
//     facção; as quests (nome, level, nível da quest, zona).
//   · tools/fontes/wishwell/DataForever.lua e DataQuests.lua (Wishwell Forever 1.4.2): a faixa de
//     level de cada dungeon, a % de drop dos bosses e os itens de dungeon que o LootGoblin não
//     tem; o nome de cada zona.
// O GearQuest Forever não entra: a licença dele é "todos os direitos reservados".
// Licenças e créditos: THIRD_PARTY.md.
//
// Uso: node tools/build-sources.mjs   (roda da raiz do repo; leva uns 10 segundos)

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { luaTable } from './luatable.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const F = (p) => join(ROOT, 'tools', 'fontes', p);
const OUT = join(ROOT, 'FindUpgrade', 'SourcesData.lua');

const LG = luaTable(readFileSync(F('lootgoblin/ForeverSources.local.lua'), 'utf8').replace('addon.ForeverSources =', 'LG ='), 'LG');
const wwText = readFileSync(F('wishwell/DataForever.lua'), 'utf8');
const W = luaTable(wwText, 'WishwellData');
const WQ = readFileSync(F('wishwell/DataQuests.lua'), 'utf8');
const questZones = luaTable(WQ.replace(/^WishwellData\.questZones =/m, 'QZ ='), 'QZ') || {};

const zoneName = (area) => (questZones[area] && questZones[area][0]) || null;

// Dungeons: a lista do Wishwell (nome, zona, faixa de level), mais as que só o LootGoblin cita.
const instances = [];
const instByName = new Map();
function instance(name, zone, min, max) {
  const key = (name || '').toLowerCase().replace(/^the /, '');
  let i = instByName.get(key);
  if (!i) {
    i = { idx: instances.length + 1, name, zone: zone || '', min: min || 0, max: max || 0 };
    instances.push(i);
    instByName.set(key, i);
  } else {
    if (!i.min && min) i.min = min;
    if (!i.max && max) i.max = max;
    if (!i.zone && zone) i.zone = zone;
  }
  return i;
}
const wwInst = {};
for (const d of W.instances || []) {
  if (d.kind !== 'dungeon') continue;
  wwInst[d.id] = instance(d.name, d.zone, d.min, d.max);
  for (const alias of d.aliases || []) instByName.set(alias.toLowerCase().replace(/^the /, ''), wwInst[d.id]);
}

// % de drop do Wishwell: item → { inst, boss, rate }
const wwDrop = new Map();
const wwQuestReward = new Map();
for (const it of W.items || []) {
  const inst = wwInst[it.raid];
  if (!inst || !it.id) continue;
  if (it.boss === 'Quest rewards') {
    wwQuestReward.set(it.id, inst);
    continue;
  }
  const prev = wwDrop.get(it.id);
  if (!prev || (it.rate || 0) > (prev.rate || 0)) wwDrop.set(it.id, { inst, boss: it.boss, rate: it.rate, standin: !!it.standin });
}

// Itens: fontes do LootGoblin; % do Wishwell no drop do mesmo boss/dungeon.
const KIND = { quests: 1, dungeons: 2, vendors: 3, reputation: 4 };
const items = new Map(); // id → { req, side, src: [] }
const quests = new Map(); // id → [name, minLevel, questLevel, zone, races, classes, preAll, preAny, starter]
const arr = (x) => (Array.isArray(x) ? x : Object.values(x || {})).map(Number).filter(Boolean);
// Quem começa a quest: o NPC, ou "[item]" quando ela começa num item que dropa.
function starterOf(q) {
  const npc = arr(q?.starters)[0];
  if (npc && LG.npcs?.[npc]?.name) return LG.npcs[npc].name;
  const item = arr(q?.startItems)[0];
  const route = item && q?.startItemRoutes?.[item];
  return route?.name ? `[${route.name}]` : '';
}
// A quest e as que vêm antes dela (pra contar a corrente e dizer onde ela começa).
function addQuest(id, fallbackName, fallbackLevel) {
  if (!id || quests.has(id)) return;
  const q = LG.quests && LG.quests[id];
  const preAll = arr(q?.preAll), preAny = arr(q?.preAny);
  // Zona: a da quest; senão a de quem dá (a zona da quest às vezes é uma subzona sem nome).
  const npc = arr(q?.starters)[0];
  const zone = zoneName(q?.zone) || zoneName(LG.npcs?.[npc]?.locations?.[0]?.area) || '';
  quests.set(id, [q?.name || fallbackName || '?', q?.level || fallbackLevel || 0, q?.questLevel || 0, zone,
    q?.races || 0, q?.classes || 0, preAll, preAny, starterOf(q)]);
  for (const p of [...preAll, ...preAny]) addQuest(p);
}
let stats = { quest: 0, dungeon: 0, vendor: 0, rep: 0, rate: 0, wwOnly: 0, wwQuest: 0 };
for (const it of LG.items || []) {
  if (!(it.classID === 2 || it.classID === 4)) continue;
  const src = [];
  for (const s of it.sources || []) {
    const k = KIND[s.category];
    if (!k) continue;
    if (k === 1 && s.quest) {
      addQuest(s.quest, s.target, s.level);
      src.push([1, s.quest]);
      stats.quest++;
    } else if (k === 2) {
      const inst = instance(s.location || s.name, null, 0, 0);
      const boss = s.target && s.target !== 'Random enemies' ? s.target : null;
      const w = wwDrop.get(it.id);
      const rate = w && w.inst === inst ? w.rate : undefined;
      if (rate) stats.rate++;
      src.push([2, inst.idx, boss || (w && w.inst === inst ? w.boss : null), rate ?? null]);
      stats.dungeon++;
    } else if (k === 3 || k === 4) {
      src.push([k, s.target || s.name || '?', s.location || zoneName(s.zone) || '', s.side || 0]);
      stats[k === 3 ? 'vendor' : 'rep']++;
    }
  }
  if (src.length) items.set(it.id, { req: it.level || 0, side: it.side || 0, src });
}
// Dungeon que só o Wishwell tem (sem level pedido: o jogo diz quando o item carregar).
for (const [id, w] of wwDrop) {
  if (items.has(id)) {
    const e = items.get(id);
    if (!e.src.some((s) => s[0] === 2)) e.src.push([2, w.inst.idx, w.boss, w.rate ?? null]);
    continue;
  }
  items.set(id, { req: -w.inst.min, side: 0, src: [[2, w.inst.idx, w.boss, w.rate ?? null]] });
  stats.wwOnly++;
}
for (const [id, inst] of wwQuestReward) {
  const e = items.get(id) || { req: -inst.min, side: 0, src: [] };
  if (!e.src.some((s) => s[0] === 1)) {
    e.src.push([5, inst.idx]); // recompensa de quest da dungeon (sem id da quest)
    stats.wwQuest++;
  }
  items.set(id, e);
}

// Lua compacto.
const q = (s) => JSON.stringify(String(s ?? '')).replace(/\\u([0-9a-f]{4})/gi, (_, h) => '\\' + parseInt(h, 16));
const v = (x) => (x === null || x === undefined ? 'nil' : typeof x === 'string' ? q(x) : String(x));
const lines = [];
lines.push(`-- GERADO por tools/build-sources.mjs em ${new Date().toISOString().slice(0, 10)}. Não edite à mão: rode o script.`);
lines.push('-- Fontes de equipamento fora do leilão (quest, boss de dungeon, vendedor, reputação), juntadas');
lines.push('-- do LootGoblin 1.3.0 e do Wishwell Forever 1.4.2 (que juntam Wowhead Forever, QuestieDB e');
lines.push('-- AtlasLootClassic). Licenças e créditos: THIRD_PARTY.md. Formato: docs/fontes.md.');
lines.push('local _, FU = ...');
lines.push('FU = FU or FindUpgrade');
lines.push(`FU.SOURCES = { build = ${q(LG.build || '?')}, generated = ${q(new Date().toISOString().slice(0, 10))},`);
lines.push('  -- dungeon: { nome, zona, level mínimo, level máximo }');
lines.push('  instances = {');
for (const i of instances) lines.push(`    [${i.idx}] = { ${q(i.name)}, ${q(i.zone)}, ${i.min}, ${i.max} },`);
lines.push('  },');
lines.push('  -- quest: { nome, level pra pegar, level da quest, zona, raças, classes, todas antes, uma antes, quem dá }.');
lines.push('  -- Raças e classes: bit (raceID/classID - 1), 0 = todas. Antes: ids das quests que vêm antes (nil = nenhuma).');
lines.push('  -- Quem dá: o NPC, ou "[item]" quando começa num item. Vêm também as quests que só abrem a corrente.');
lines.push('  quests = {');
const ids = (a) => (a.length ? `{ ${a.join(', ')} }` : 'nil');
for (const [id, x] of [...quests].sort((a, b) => a[0] - b[0])) {
  lines.push(`    [${id}] = { ${q(x[0])}, ${x[1]}, ${x[2]}, ${q(x[3])}, ${x[4]}, ${x[5]}, ${ids(x[6])}, ${ids(x[7])}, ${q(x[8])} },`);
}
lines.push('  },');
lines.push('  -- item: { level pedido (negativo = mínimo da dungeon, o do item vem do jogo), facção (0 as duas,');
lines.push('  -- 1 Aliança, 2 Horda), fontes... }. Fonte: { 1, quest } · { 2, dungeon, boss, % de drop } ·');
lines.push('  -- { 3, vendedor, zona, facção } · { 4, intendente de reputação, zona, facção } · { 5, dungeon } (quest da dungeon)');
lines.push('  items = {');
for (const [id, e] of [...items].sort((a, b) => a[0] - b[0])) {
  lines.push(`    [${id}] = { ${e.req}, ${e.side}, ${e.src.map((s) => '{ ' + s.map(v).join(', ') + ' }').join(', ')} },`);
}
lines.push('  },');
lines.push('}');
writeFileSync(OUT, lines.join('\n') + '\n');
const size = readFileSync(OUT).length;
console.log(`SourcesData.lua: ${items.size} itens · ${quests.size} quests · ${instances.length} dungeons · ${(size / 1024).toFixed(0)} KB`);
console.log(`fontes: quest ${stats.quest} · dungeon ${stats.dungeon} (com % ${stats.rate}) · vendedor ${stats.vendor} · reputação ${stats.rep} · só no Wishwell ${stats.wwOnly} · quest de dungeon ${stats.wwQuest}`);
