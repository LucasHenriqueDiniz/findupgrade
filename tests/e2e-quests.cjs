// Botão Quests (16/11): o level é o da quest, não só o do item (a Zandalarian Hero Charm não pede
// level, mas vem de quest de lvl 58); quest de outra raça ou classe some; as do log vêm primeiro,
// depois as que dá pra pegar, depois as que têm quest antes (com quantas e por onde começa).
const { run } = require('./harness.cjs');

const setup = String.raw`
CLASS, LEVEL, MONEY = "PRIEST", 24, 5000
function UnitClass() return "Priest", "PRIEST", 5 end
function UnitRace() return "Gnome", "Gnome", 7 end
CharacterFrame = CreateFrame("Frame")
ITEMS = {
  [2042] = { "Staff of Westfall", "INVTYPE_2HWEAPON", 2, 10, 13, {}, { "Staff of Westfall", "+5 Intellect", "+6 Spirit", "+48 Spell Healing" } },
  [801] = { "Zandalarian Hero Charm", "INVTYPE_TRINKET", 4, 0, 0, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 204 } },
  [802] = { "Log Ring", "INVTYPE_FINGER", 4, 0, 20, { ITEM_MOD_INTELLECT_SHORT = 3 } },
  [803] = { "Pickup Amulet", "INVTYPE_NECK", 4, 0, 22, { ITEM_MOD_INTELLECT_SHORT = 9 } },
  [804] = { "Chain Cloak", "INVTYPE_CLOAK", 4, 1, 22, { ITEM_MOD_INTELLECT_SHORT = 6 } },
  [805] = { "Warrior Bracers", "INVTYPE_WRIST", 4, 1, 20, { ITEM_MOD_INTELLECT_SHORT = 9 } },
  [806] = { "Horde Hat", "INVTYPE_HEAD", 4, 1, 20, { ITEM_MOD_INTELLECT_SHORT = 9 } },
}
EQUIP = { [16] = link(2042) }
LOG = { 900 }
C_QuestLog = {
  IsQuestFlaggedCompleted = function() return false end,
  GetNumQuestLogEntries = function() return #LOG end,
  GetInfo = function(i) return { questID = LOG[i], isHeader = false } end,
}
-- quest: { nome, level pra pegar, level da quest, zona, raças, classes, todas antes, uma antes, quem dá }
TEST_SOURCES = { generated = "2026-11-16", instances = {},
  quests = {
    [8183] = { "The Heart of Hakkar", 58, 60, "", 0, 0, nil, nil, "[Heart of Hakkar]" },
    [900] = { "Log Quest", 20, 22, "Redridge Mountains", 0, 0, nil, nil, "Magistrate Solomon" },
    [901] = { "Pickup Quest", 22, 24, "Duskwood", 0, 0, nil, nil, "Abercrombie" },
    [902] = { "Middle Quest", 20, 23, "Duskwood", 0, 0, nil, { 905, 906 }, "Jitters" },
    [903] = { "Chain End", 22, 25, "Duskwood", 0, 0, { 902 }, nil, "Jitters" },
    [905] = { "Horde Start", 18, 20, "Barrens", 2, 0, nil, nil, "Grunt" },
    [906] = { "Gnome Start", 18, 20, "Duskwood", 64, 0, nil, nil, "Watcher Ladimore" },
    [907] = { "Warrior Quest", 20, 22, "Duskwood", 0, 1, nil, nil, "Trainer" },
    [908] = { "Horde Quest", 20, 22, "Barrens", 2, 0, nil, nil, "Grunt" },
  },
  items = {
    [801] = { 1, 0, { 1, 8183 } },
    [802] = { 20, 0, { 1, 900 } },
    [803] = { 22, 0, { 1, 901 } },
    [804] = { 22, 0, { 1, 903 } },
    [805] = { 20, 0, { 1, 907 } },
    [806] = { 20, 0, { 1, 908 } },
  },
}
`;

const driver = String.raw`
local FU = loadAddon()
fire("PLAYER_LOGIN")
FU.SOURCES = TEST_SOURCES
SlashCmdList.FINDUPGRADE("quests")
runTimers()
local f = FindUpgradeFrame
local res = FU.res
local function id(key, i) local r = res[key][i or 1]; return r and r.parts[1].g.id end
-- Quest de lvl 58 com item sem level pedido: fora no 24, mesmo com +10.
assert(#res.Trinket == 0, "Hero Charm (quest lvl 58) não aparece no 24")
f.levelSeg.buttons[4].scripts.OnClick(f.levelSeg.buttons[4])
assert(#FU.res.Trinket == 0, "nem com +10")
f.levelSeg.buttons[1].scripts.OnClick(f.levelSeg.buttons[1])
res = FU.res
-- Outra classe e outra raça: somem.
assert(#res.Wrist == 0 and #res.Head == 0, "quest de warrior e da Horda somem")
-- Ordem: a do log primeiro (mesmo ganhando menos), depois a de pegar, depois a com quest antes.
local all = FU.overview(res)
assert(#all == 3, "3 linhas no Tudo: " .. #all)
assert(all[1].parts[1].g.id == 802 and all[2].parts[1].g.id == 803 and all[3].parts[1].g.id == 804,
  "ordem log → pegar → corrente: " .. all[1].parts[1].g.id .. "," .. all[2].parts[1].g.id .. "," .. all[3].parts[1].g.id)
local s1, s2, s3 = all[1].parts[1].g.src, all[2].parts[1].g.src, all[3].parts[1].g.src
assert(s1.tier == 1 and FU.src.short(s1):find("No log", 1, true), "anel: no log")
assert(s2.tier == 2 and FU.src.short(s2) == "Pegar", "colar: pegar")
assert(s3.tier == 3 and s3.chain == 2 and s3.start == "Gnome Start" and FU.src.short(s3) == "+2 quests", "capa: 2 antes, começa na do gnomo")
local function joined(s) return table.concat(FU.src.lines(s), " | ") end
assert(joined(s1):find("Tá no teu log de quests", 1, true), joined(s1))
assert(joined(s2):find("Dá pra pegar com Abercrombie", 1, true), joined(s2))
assert(joined(s3):find("Antes dela: 2 quests · começa em Gnome Start (lvl 18) com Watcher Ladimore · Duskwood", 1, true), joined(s3))
-- Tooltip fora da janela: a do lvl 58 diz quando dá pra pegar.
local hk = FU.src.forItem(801)
assert(joined(hk):find("Só dá pra pegar no lvl 58", 1, true), joined(hk))
-- Pegou a quest do colar: ela sobe pro topo.
LOG[2] = 901
fire("QUEST_ACCEPTED")
runTimers()
all = FU.overview(FU.res)
assert(all[1].parts[1].g.src.tier == 1 and all[2].parts[1].g.src.tier == 1 and all[1].parts[1].g.id == 803,
  "colar pego: no log, e o de maior ganho primeiro")
noErrors()
`;

run('quests: level da quest, raça/classe, log e corrente', setup, driver);
