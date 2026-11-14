// Modo "Quests e dungeons": lê o banco do GearQuest Forever (de onde vem cada item da classe,
// facção da recompensa) e do Wishwell Forever (loot de dungeon com % de drop, id das quests),
// tira a recompensa da outra facção, a quest já feita e o world drop, junta as duas fontes no
// mesmo item, acha o level de verdade do item do Wishwell quando ele carrega, e filtra por tipo.
const { run } = require('./harness.cjs');

const setup = String.raw`
CLASS, LEVEL, MONEY = "PRIEST", 15, 5000
CharacterFrame = CreateFrame("Frame")
ITEMS = {
  [4314] = { "Double-Stitched Woolen Shoulders", "INVTYPE_SHOULDER", 4, 1, 12, { ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 4 } },
  [2042] = { "Staff of Westfall", "INVTYPE_2HWEAPON", 2, 10, 13, {}, { "Staff of Westfall", "+5 Intellect", "+6 Spirit", "+48 Spell Healing" } },
  -- das fontes
  [710] = { "Bracers of the People's Militia", "INVTYPE_WRIST", 4, 1, 8, { ITEM_MOD_INTELLECT_SHORT = 3, ITEM_MOD_SPIRIT_SHORT = 2 } },
  [711] = { "Horde Bracers", "INVTYPE_WRIST", 4, 1, 10, { ITEM_MOD_INTELLECT_SHORT = 9 } },
  [712] = { "Done Quest Gloves", "INVTYPE_HAND", 4, 1, 12, { ITEM_MOD_INTELLECT_SHORT = 9 } },
  [713] = { "World Drop Belt", "INVTYPE_WAIST", 4, 1, 12, { ITEM_MOD_INTELLECT_SHORT = 9 } },
  [714] = { "Vendor Boots", "INVTYPE_FEET", 4, 1, 10, { ITEM_MOD_INTELLECT_SHORT = 4 } },
  [715] = { "Boss Robe", "INVTYPE_ROBE", 4, 1, 14, { ITEM_MOD_INTELLECT_SHORT = 8, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 6 } },
  [716] = { "Golemheart Stave", "INVTYPE_2HWEAPON", 2, 10, 16, { ITEM_MOD_INTELLECT_SHORT = 5, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 60 } },
  [718] = { "Onyxia Robe", "INVTYPE_ROBE", 4, 1, 60, { ITEM_MOD_INTELLECT_SHORT = 40 } },
}
CACHED = { [716] = false } -- o cajado só do Wishwell chega sem dados
EQUIP = { [3] = link(4314), [16] = link(2042) }
LOADED = {}
C_AddOns = { LoadAddOn = function(name)
  LOADED[#LOADED + 1] = name
  if name == "GearQuestForever_PRIEST" then GearQuest.Data.priestItemFacts = FACTS end
end }
DONE = { [500] = true }
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return DONE[id] == true end }
-- GearQuest: o módulo da classe é LoadOnDemand (o FindUpgrade carrega se ainda não veio).
FACTS = {
  [710] = { name = "Bracers of the People's Militia", quality = 1, reqLevel = 8, sourceType = "quest_reward", questName = "Patrolling Westfall", zone = "Westfall", instructions = "Reward from the quest 'Patrolling Westfall'." },
  [711] = { name = "Horde Bracers", quality = 2, reqLevel = 10, sourceType = "quest_reward", questName = "Horde Thing", zone = "Durotar" },
  [712] = { name = "Done Quest Gloves", quality = 2, reqLevel = 12, sourceType = "quest_reward", questName = "Done Quest", zone = "Elwynn Forest" },
  [713] = { name = "World Drop Belt", quality = 2, reqLevel = 12, sourceType = "world_drop", zone = "Westfall" },
  [714] = { name = "Vendor Boots", quality = 1, reqLevel = 10, sourceType = "vendor", npc = "Thomas", zone = "Goldshire", instructions = "Bought from Thomas." },
  [715] = { name = "Boss Robe", quality = 3, reqLevel = 14, sourceType = "boss_drop", npc = "Faldrim Anvilmar", zone = "Dun Morogh", instructions = "Drops from Faldrim Anvilmar." },
}
GearQuest = { Data = { questFaction = { [710] = "Alliance", [711] = "Horde" } } }
WishwellData = {
  instances = {
    { id = "thanes", name = "Hall of Thanes", kind = "dungeon", zone = "Dun Morogh", min = 13, max = 18 },
    { id = "onyxia", name = "Onyxia's Lair", kind = "raid", size = 40 },
  },
  items = {
    { id = 715, name = "Boss Robe", slot = "Chest", boss = "Faldrim Anvilmar", raid = "thanes", q = 3, rate = 12.3 },
    { id = 716, name = "Golemheart Stave", slot = "Two-Hand", boss = "Plunder", raid = "thanes", q = 3, rate = 9.6 },
    { id = 718, name = "Onyxia Robe", boss = "Onyxia", raid = "onyxia", rate = 30 },
  },
  quests = { { 500, "Done Quest", 12, 10, 12, 500, 77, 0 }, { 501, "Patrolling Westfall", 12, 8, 40, 600, 77, 0 } },
}
`;

const driver = String.raw`
local FU = loadAddon()
fire("PLAYER_LOGIN")
SlashCmdList.FINDUPGRADE("quests")
runTimers() -- os timers do cálculo (no jogo, os próximos frames)
local f = FindUpgradeFrame
assert(f and f.shown and FindUpgradeDB.mode == "src" and FU.ctx, "/fu quests abre no modo Quests e dungeons, sem leiloeiro")
assert(LOADED[1] == "GearQuestForever_PRIEST", "carrega o módulo de Priest do GearQuest")
assert(not REPLICATED, "não varre o AH")
noErrors()
local res = FU.res
local function src(key) return res[key][1] and res[key][1].parts[1].g.src end
-- Pulso: recompensa da Aliança (+3,9), com a quest, a zona e o id (do Wishwell).
assert(#res.Wrist == 1 and res.Wrist[1].parts[1].g.id == 710 and near(res.Wrist[1].gain, 3.9), "pulso: Bracers +3,9")
assert(src("Wrist").kind == "quest" and src("Wrist").quest == "Patrolling Westfall" and src("Wrist").questId == 501, "fonte da quest")
-- Fora: a recompensa da Horda (711), a quest já feita (712) e o world drop (713).
assert(#res.Hands == 0 and #res.Waist == 0, "sem a luva da quest feita e sem o world drop")
-- Pés: vendedor. Peito: drop do boss, com o % e a dungeon do Wishwell no mesmo item.
assert(src("Feet").kind == "vendor" and src("Feet").npc == "Thomas", "pés: vendedor")
assert(src("Chest").kind == "dungeon" and src("Chest").rate == 12.3 and src("Chest").instance == "Hall of Thanes" and src("Chest").text:find("Faldrim", 1, true),
  "peito: boss do GearQuest + % do Wishwell")
-- Raid fica fora; o cajado só do Wishwell pede o 16 (o mínimo da dungeon era 13): não entra no lvl 15.
assert(#res.weapon == 0, "cajado do 16 fora no lvl 15")
f.levelSeg.buttons[2].scripts.OnClick(f.levelSeg.buttons[2])
assert(#FU.res.weapon == 1 and FU.res.weapon[1].parts[1].g.id == 716 and FU.res.weapon[1].parts[1].g.level == 16 and near(FU.res.weapon[1].gain, 8.4),
  "+3: Golemheart Stave (+8,4), level de verdade 16")
-- Coluna da fonte, filtros de preço escondidos.
pick(f, "Chest")
local rows = shownRows(f)
assert(rows[1].price.text:find("Hall of Thanes 12%", 1, true), "coluna da fonte: " .. tostring(rows[1].price.text))
assert(f.maxBox.shown == false and f.fitGold.shown == false and f.kindSeg.buttons[1].shown, "sem preço; com o filtro de tipo")
assert(f.info.text:find("GearQuest + Wishwell", 1, true), "info diz de onde veio: " .. f.info.text)
-- Clique: escreve no chat de onde vem.
rows[1].scripts.OnClick(rows[1], "LeftButton")
assert(has("Boss Robe: Drop: Faldrim Anvilmar · Hall of Thanes · 12,3%"), "clique escreve a fonte")
-- Tipo: só quests, só dungeons.
f.kindSeg.buttons[2].scripts.OnClick(f.kindSeg.buttons[2])
assert(#FU.res.Wrist == 1 and #FU.res.Chest == 0 and #FU.res.Feet == 0 and #FU.res.weapon == 0, "só quests")
f.kindSeg.buttons[3].scripts.OnClick(f.kindSeg.buttons[3])
assert(#FU.res.Wrist == 0 and #FU.res.Chest == 1 and #FU.res.weapon == 1, "só dungeons")
-- Botão na janela do personagem: fecha e abre a janela (no último modo).
local cb = FU.charButton
assert(cb and FindUpgrade_Toggle and BINDING_NAME_FINDUPGRADE_TOGGLE, "botão na janela do personagem, atalho e menu de addons")
cb.scripts.OnClick(cb)
assert(not f.shown, "o botão fecha a janela")
cb.scripts.OnClick(cb)
runTimers()
assert(f.shown and FindUpgradeDB.mode == "src", "e abre de novo no modo Quests e dungeons")
-- Volta pro leilão: preço aparece de novo e o modo fica salvo.
f.modeSeg.buttons[1].scripts.OnClick(f.modeSeg.buttons[1])
assert(FindUpgradeDB.mode == "ah" and f.maxBox.shown and not f.kindSeg.buttons[1].shown, "modo leilão")
noErrors()

-- Sem GearQuest e sem Wishwell: avisa o que instalar.
GearQuest, WishwellData = nil, nil
PRINTED = {}
SlashCmdList.FINDUPGRADE("quests")
assert(has("instala o GearQuest Forever ou o Wishwell Forever"), "sem os bancos: avisa")
`;

run('quests e dungeons (banco do GearQuest + Wishwell)', setup, driver);
