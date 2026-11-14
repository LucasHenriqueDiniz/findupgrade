// Modo "Quests e dungeons" com o banco de fontes do próprio addon (SourcesData.lua): confere o
// banco de verdade (gerado por tools/build-sources.mjs) e, com um banco pequeno de teste, tira
// a peça da outra facção e a quest já feita, escolhe a fonte, acha o level de verdade do item que
// só tinha o mínimo da dungeon, junta nome e qualidade do jogo, filtra por tipo e abre pelo botão
// da janela do personagem.
const { run } = require('./harness.cjs');

const setup = String.raw`
CLASS, LEVEL, MONEY = "PRIEST", 15, 5000
CharacterFrame = CreateFrame("Frame")
ITEMS = {
  [4314] = { "Double-Stitched Woolen Shoulders", "INVTYPE_SHOULDER", 4, 1, 12, { ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 4 } },
  [2042] = { "Staff of Westfall", "INVTYPE_2HWEAPON", 2, 10, 13, {}, { "Staff of Westfall", "+5 Intellect", "+6 Spirit", "+48 Spell Healing" } },
  -- do banco de teste
  [710] = { "Bracers of the People's Militia", "INVTYPE_WRIST", 4, 1, 8, { ITEM_MOD_INTELLECT_SHORT = 3, ITEM_MOD_SPIRIT_SHORT = 2 } },
  [711] = { "Horde Bracers", "INVTYPE_WRIST", 4, 1, 10, { ITEM_MOD_INTELLECT_SHORT = 9 } },
  [712] = { "Done Quest Gloves", "INVTYPE_HAND", 4, 1, 12, { ITEM_MOD_INTELLECT_SHORT = 9 } },
  [714] = { "Vendor Boots", "INVTYPE_FEET", 4, 1, 10, { ITEM_MOD_INTELLECT_SHORT = 4 } },
  [715] = { "Boss Robe", "INVTYPE_ROBE", 4, 1, 14, { ITEM_MOD_INTELLECT_SHORT = 8, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 6 } },
  [716] = { "Golemheart Stave", "INVTYPE_2HWEAPON", 2, 10, 16, { ITEM_MOD_INTELLECT_SHORT = 5, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 60 } },
  [719] = { "Horde Vendor Belt", "INVTYPE_WAIST", 4, 1, 10, { ITEM_MOD_INTELLECT_SHORT = 9 } },
}
CACHED = { [716] = false } -- o cajado chega sem dados
EQUIP = { [3] = link(4314), [16] = link(2042) }
DONE = { [500] = true }
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return DONE[id] == true end }
TEST_SOURCES = { generated = "2026-11-14",
  instances = { [1] = { "Hall of Thanes", "Dun Morogh", 13, 18 } },
  quests = { [102] = { "Patrolling Westfall", 8, 14, "Westfall" }, [500] = { "Done Quest", 10, 12, "Elwynn Forest" } },
  items = {
    [710] = { 8, 1, { 1, 102 } },                              -- quest da Aliança
    [711] = { 10, 2, { 1, 103 } },                             -- só da Horda
    [712] = { 12, 0, { 1, 500 } },                             -- quest já feita
    [714] = { 10, 0, { 3, "Thomas", "Goldshire", 1 } },        -- vendedor da Aliança
    [719] = { 10, 0, { 3, "Gruk", "Orgrimmar", 2 } },          -- vendedor da Horda
    [715] = { 14, 0, { 2, 1, "Faldrim Anvilmar", 12.3 } },     -- boss com % de drop
    [716] = { -13, 0, { 2, 1, "Plunder", 9.6 } },              -- só o mínimo da dungeon (13); o item pede 16
  },
}
`;

const driver = String.raw`
local FU = loadAddon()
fire("PLAYER_LOGIN")
-- O banco de verdade veio junto (SourcesData.lua).
local S = FU.SOURCES
local n = 0
for _ in pairs(S.items) do n = n + 1 end
assert(n > 4000 and S.quests[102] and S.quests[102][1] == "Patrolling Westfall" and S.items[710] and S.items[710][3][2] == 102,
  "banco de verdade: " .. n .. " itens, Bracers do Patrolling Westfall")
assert(S.instances[1] and S.instances[1][1] == "Hall of Thanes", "dungeons do banco")
-- Daqui pra frente, um banco pequeno de teste.
FU.SOURCES = TEST_SOURCES
-- Conta quantas contas de verdade rodam (trocar de botão na mesma família não recalcula).
local computes, realCompute = 0, FU.compute
FU.compute = function(...) computes = computes + 1; return realCompute(...) end
SlashCmdList.FINDUPGRADE("quests")
runTimers() -- os timers do cálculo (no jogo, os próximos frames)
local f = FindUpgradeFrame
assert(f and f.shown and FindUpgradeDB.mode == "quest" and FU.ctx and computes == 1, "/fu quests abre no botão Quests, sem leiloeiro")
assert(not REPLICATED, "não varre o AH")
assert(FU.perf and FU.perf.items == 4 and FU.perf.maxSlice >= 0, "mede a conta (/fu debug)")
SlashCmdList.FINDUPGRADE("debug")
assert(has("última conta (quest): 4 itens"), "/fu debug")
noErrors()
local res = FU.res
local function first(key) return FU.res[key][1] and FU.res[key][1].parts[1].g end
-- Quests: a recompensa da Aliança, com nome e qualidade do jogo e a quest do banco; nada de dungeon nem vendedor.
local g = first("Wrist")
assert(#res.Wrist == 1 and g.id == 710 and g.name == "Bracers of the People's Militia" and near(res.Wrist[1].gain, 3.9), "pulso: Bracers +3,9")
assert(g.src.kind == "quest" and g.src.quest == "Patrolling Westfall" and g.src.questId == 102 and g.src.zone == "Westfall", "fonte da quest")
assert(#res.Hands == 0 and #res.Feet == 0 and #res.Chest == 0 and #res.weapon == 0, "só quest (sem a feita, sem dungeon, sem vendedor)")
assert(f.maxBox.shown == false and f.info.text:find("Quests · 4 itens no banco (de 2026-11-14)", 1, true), "sem preço; info: " .. f.info.text)
-- Dungeons: o boss com % e o cajado (o item pede 16, não o 13 da dungeon). Na hora, sem recalcular.
f.modeSeg.buttons[3].scripts.OnClick(f.modeSeg.buttons[3])
assert(FindUpgradeDB.mode == "dungeon" and computes == 1, "trocar Quests → Dungeons não recalcula")
assert(#FU.res.Chest == 1 and first("Chest").src.rate == 12.3 and first("Chest").src.instance == "Hall of Thanes" and #FU.res.Wrist == 0, "dungeon: peito com %")
assert(#FU.res.weapon == 0, "cajado do 16 fora no lvl 15")
f.levelSeg.buttons[2].scripts.OnClick(f.levelSeg.buttons[2])
assert(#FU.res.weapon == 1 and FU.res.weapon[1].parts[1].g.level == 16 and near(FU.res.weapon[1].gain, 8.4), "+3: Golemheart Stave (+8,4), level 16")
pick(f, "Chest")
local rows = shownRows(f)
assert(rows[1].price.text:find("Hall of Thanes 12%", 1, true), "coluna da fonte: " .. tostring(rows[1].price.text))
rows[1].scripts.OnClick(rows[1], "LeftButton")
assert(has("Boss Robe: Drop: Faldrim Anvilmar · Hall of Thanes (Dun Morogh) · 12,3%"), "clique escreve a fonte")
-- Vendedores: o da Aliança; o da Horda some.
f.modeSeg.buttons[4].scripts.OnClick(f.modeSeg.buttons[4])
assert(FindUpgradeDB.mode == "vendor" and computes == 1 and #FU.res.Feet == 1 and first("Feet").src.npc == "Thomas" and #FU.res.Waist == 0, "vendedores")
-- Botão na janela do personagem: fecha e abre (no último botão, com a conta guardada).
local cb = FU.charButton
assert(cb and FindUpgrade_Toggle and BINDING_NAME_FINDUPGRADE_TOGGLE, "botão na janela do personagem, atalho e menu de addons")
cb.scripts.OnClick(cb)
assert(not f.shown, "o botão fecha a janela")
cb.scripts.OnClick(cb)
assert(f.shown and FindUpgradeDB.mode == "vendor" and computes == 1, "e abre de novo onde estava, sem recalcular")
-- Leilão: conta própria (sem varredura, avisa) e a volta pra Quests usa a guardada.
f.modeSeg.buttons[1].scripts.OnClick(f.modeSeg.buttons[1])
runTimers()
assert(FindUpgradeDB.mode == "ah" and f.maxBox.shown and FU.noData and computes == 2, "leilão: outra conta")
f.modeSeg.buttons[2].scripts.OnClick(f.modeSeg.buttons[2])
assert(FindUpgradeDB.mode == "quest" and computes == 2 and #FU.res.Wrist == 1, "volta pra Quests na hora")
-- Quest entregue: a conta das fontes é refeita (a quest feita sai).
DONE[102] = true
fire("QUEST_TURNED_IN")
assert(computes == 3 and #FU.res.Wrist == 0, "quest entregue sai da lista")
DONE[102] = nil
-- Trocar no meio de uma conta: a de antes para e não sobrescreve a nova (era o que travava).
FU.invalidate()
local held, realAfter = {}, C_Timer.After
C_Timer.After = function(_, fn) held[#held + 1] = fn end
CACHED[716] = false
FU.cache["item:716"] = nil -- sem os stats guardados, a conta precisa esperar o cajado
LOADREQ[716] = nil
f.modeSeg.buttons[3].scripts.OnClick(f.modeSeg.buttons[3]) -- Dungeons: começa e fica esperando o cajado
assert(FU.computing and FindUpgradeDB.mode == "dungeon", "conta das fontes começou")
f.modeSeg.buttons[1].scripts.OnClick(f.modeSeg.buttons[1]) -- Leilão no meio
C_Timer.After = realAfter
for _, fn in ipairs(held) do fn() end
runTimers()
assert(FindUpgradeDB.mode == "ah" and FU.noData and not FU.ctxBy.src, "a conta velha parou e não mexeu na janela")
noErrors()
`;

run('quests e dungeons (banco próprio)', setup, driver);
