// Spell power no level baixo: rank antes do 20 recebe menos do bônus e com pouca mana saem poucas
// curas, então +3 SP vale bem menos que +5 Int. O caso de 14/11: priest de cura lvl 16 com maça e
// Dwarven Tome (+1 Spi, +3 SP); a Tear of Grief (+5 Int, -3 Spi) é upgrade no 16 e não no 40.
const { run } = require('./harness.cjs');

const setup = String.raw`
REAL_SPELL_SCALE = true
CLASS, LEVEL, MONEY = "PRIEST", 16, 5686
ITEMS = {
  [2777] = { "Feeble Shortbow Mace", "INVTYPE_WEAPONMAINHAND", 2, 4, 10, {} },
  [279898] = { "Dwarven Tome", "INVTYPE_HOLDABLE", 4, 0, 12, { ITEM_MOD_SPIRIT_SHORT = 1, ITEM_MOD_SPELL_POWER_SHORT = 3 } },
  [5611] = { "Tear of Grief", "INVTYPE_HOLDABLE", 4, 0, 14, { ITEM_MOD_INTELLECT_SHORT = 5, ITEM_MOD_SPIRIT_SHORT = -3 } },
}
CACHED = {}
EQUIP = { [16] = link(2777), [17] = link(279898) }
LISTINGS = {}
POSTCALLS = {}
Enum.TooltipDataType = { Item = 0 }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) POSTCALLS[#POSTCALLS + 1] = fn end }
GameTooltip = { lines = {}, GetItem = function(self) return nil, self.link end,
  AddLine = function(self, t) self.lines[#self.lines + 1] = t end, Show = function() end }
function hover(l)
  GameTooltip.lines, GameTooltip.link = {}, l
  for _, fn in ipairs(POSTCALLS) do fn(GameTooltip, {}) end
  return table.concat(GameTooltip.lines, "\n")
end
`;

const driver = String.raw`
local FU = loadAddon()
fire("PLAYER_LOGIN")

-- A conta: 0,38 no 16, 0,53 no 20, 0,8 no 30, cheio do 40 pra cima.
assert(near(FU.spellScale(16), 0.3835), "16: " .. FU.spellScale(16))
assert(near(FU.spellScale(20), 0.5325), "20: " .. FU.spellScale(20))
assert(near(FU.spellScale(30), 0.8), "30: " .. FU.spellScale(30))
assert(FU.spellScale(40) == 1 and FU.spellScale(60) == 1, "40 e 60: cheio")

-- No 16: +5 Int ganha de +3 SP (e o Spirit que sai).
local T = hover(link(5611))
assert(T:find("Upgrade +", 1, true) and T:find("no lugar de Dwarven Tome", 1, true), "lvl 16: " .. T)
assert(T:find("+5 Int", 1, true) and T:find("-3 Cura", 1, true), "o que muda: " .. T)

-- No 40 o +3 SP vale cheio: o Dwarven Tome fica melhor.
LEVEL = 40
fire("PLAYER_LEVEL_UP")
T = hover(link(5611))
assert(T:find("Pior que Dwarven Tome (-0,9)", 1, true), "lvl 40: " .. T)

-- Peso que ele pôs na tela de configurações fica como está, em qualquer level.
LEVEL = 16
FU.db().weights = { heal = { heal = 1 } }
fire("PLAYER_LEVEL_UP")
assert(FU.context().w.heal == 1, "peso dele: " .. tostring(FU.context().w.heal))
FU.db().weights = nil
assert(near(FU.context().w.heal, 0.3835), "sem peso dele, o do level")
`;

run('spell power por level', setup, driver);
