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
SlashCmdList.FINDUPGRADE("quests")
runTimers() -- os timers do cálculo (no jogo, os próximos frames)
local f = FindUpgradeFrame
assert(f and f.shown and FindUpgradeDB.mode == "src" and FU.ctx, "/fu quests abre no modo Quests e dungeons, sem leiloeiro")
assert(not REPLICATED, "não varre o AH")
noErrors()
local res = FU.res
local function first(key) return res[key][1] and res[key][1].parts[1].g end
-- Pulso: a recompensa da Aliança, com nome e qualidade do jogo e a quest do banco.
local g = first("Wrist")
assert(#res.Wrist == 1 and g.id == 710 and g.name == "Bracers of the People's Militia" and near(res.Wrist[1].gain, 3.9), "pulso: Bracers +3,9")
assert(g.src.kind == "quest" and g.src.quest == "Patrolling Westfall" and g.src.questId == 102 and g.src.zone == "Westfall", "fonte da quest")
-- Fora: a da Horda (711), a quest já feita (712) e o vendedor da Horda (719).
assert(#res.Hands == 0 and #res.Waist == 0, "sem a quest feita e sem o vendedor da Horda")
assert(first("Feet").src.kind == "vendor" and first("Feet").src.npc == "Thomas", "pés: vendedor")
assert(first("Chest").src.kind == "dungeon" and first("Chest").src.rate == 12.3 and first("Chest").src.instance == "Hall of Thanes", "peito: boss com %")
-- O cajado tinha só o 13 da dungeon; o item pede 16: não entra no lvl 15, entra no +3.
assert(#res.weapon == 0, "cajado do 16 fora no lvl 15")
f.levelSeg.buttons[2].scripts.OnClick(f.levelSeg.buttons[2])
assert(#FU.res.weapon == 1 and FU.res.weapon[1].parts[1].g.level == 16 and near(FU.res.weapon[1].gain, 8.4), "+3: Golemheart Stave (+8,4), level 16")
-- Coluna da fonte, tooltip e clique.
pick(f, "Chest")
local rows = shownRows(f)
assert(rows[1].price.text:find("Hall of Thanes 12%", 1, true), "coluna da fonte: " .. tostring(rows[1].price.text))
assert(f.maxBox.shown == false and f.kindSeg.buttons[1].shown, "sem preço; com o filtro de tipo")
assert(f.info.text:find("banco de 2026-11-14", 1, true), "info diz o banco: " .. f.info.text)
rows[1].scripts.OnClick(rows[1], "LeftButton")
assert(has("Boss Robe: Drop: Faldrim Anvilmar · Hall of Thanes (Dun Morogh) · 12,3%"), "clique escreve a fonte")
-- Tipo: só quests, só dungeons.
f.kindSeg.buttons[2].scripts.OnClick(f.kindSeg.buttons[2])
assert(#FU.res.Wrist == 1 and #FU.res.Chest == 0 and #FU.res.Feet == 0 and #FU.res.weapon == 0, "só quests")
f.kindSeg.buttons[3].scripts.OnClick(f.kindSeg.buttons[3])
assert(#FU.res.Wrist == 0 and #FU.res.Chest == 1 and #FU.res.weapon == 1, "só dungeons")
-- Botão na janela do personagem: fecha e abre (no último modo).
local cb = FU.charButton
assert(cb and FindUpgrade_Toggle and BINDING_NAME_FINDUPGRADE_TOGGLE, "botão na janela do personagem, atalho e menu de addons")
cb.scripts.OnClick(cb)
assert(not f.shown, "o botão fecha a janela")
cb.scripts.OnClick(cb)
runTimers()
assert(f.shown and FindUpgradeDB.mode == "src", "e abre de novo no modo Quests e dungeons")
-- Caixinha da dica no tooltip: liga e desliga (FindUpgradeDB.tooltipOff).
assert(f.tipToggle.checked == true, "dica no tooltip começa ligada")
f.tipToggle.scripts.OnClick(f.tipToggle)
assert(FindUpgradeDB.tooltipOff == true and f.tipToggle.checked == false, "desliga")
f.tipToggle.scripts.OnClick(f.tipToggle)
assert(not FindUpgradeDB.tooltipOff and f.tipToggle.checked == true, "liga de novo")
-- Volta pro leilão.
f.modeSeg.buttons[1].scripts.OnClick(f.modeSeg.buttons[1])
assert(FindUpgradeDB.mode == "ah" and f.maxBox.shown and not f.kindSeg.buttons[1].shown, "modo leilão")
noErrors()
`;

run('quests e dungeons (banco próprio)', setup, driver);
