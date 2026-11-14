// Tooltip de item: uma linha dizendo se é upgrade pro papel dele, contra a peça que sairia, o que
// muda nos stats e de onde vem. Priest de cura, lvl 20, com staff. Não aparece no que está
// equipado, no que a classe não usa e com o tooltip desligado.
const { run } = require('./harness.cjs');

const setup = String.raw`
CLASS, LEVEL, MONEY = "PRIEST", 20, 5686
ITEMS = {
  [4314] = { "Double-Stitched Woolen Shoulders", "INVTYPE_SHOULDER", 4, 1, 17, { ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 4 } },
  [6378] = { "Seer's Cape", "INVTYPE_CLOAK", 4, 1, 11, { ITEM_MOD_INTELLECT_SHORT = 2, ITEM_MOD_SPIRIT_SHORT = 2 } },
  [2042] = { "Staff of Westfall", "INVTYPE_2HWEAPON", 2, 10, 18, {}, { "Staff of Westfall", "+5 Intellect", "+6 Spirit", "+48 Spell Healing", "+16 Spell Damage" } },
  [12006] = { "Meadow Ring of the Owl", "INVTYPE_FINGER", 4, 0, 17, { ITEM_MOD_INTELLECT_SHORT = 3, ITEM_MOD_SPIRIT_SHORT = 3 } },
  [11967] = { "Zircon Band of Concentration", "INVTYPE_FINGER", 4, 0, 18, { ITEM_MOD_MANA_REGENERATION_SHORT = 2 } },
  [4315] = { "Reinforced Woolen Shoulders", "INVTYPE_SHOULDER", 4, 1, 19, { ITEM_MOD_INTELLECT_SHORT = 4, ITEM_MOD_SPELL_POWER_SHORT = 5 } },
  [6604] = { "Dervish Cape", "INVTYPE_CLOAK", 4, 1, 21, {}, { "Dervish Cape of Healing", "Equip: Increases healing done by spells and effects by up to 11." } },
  [8888] = { "Plate Pauldrons", "INVTYPE_SHOULDER", 4, 4, 20, { ITEM_MOD_INTELLECT_SHORT = 20 } },
  [9999] = { "Robe of the Far Future", "INVTYPE_ROBE", 4, 1, 25, { ITEM_MOD_INTELLECT_SHORT = 30 } },
  [1449] = { "Minor Channeling Ring", "INVTYPE_FINGER", 4, 0, 18, { ITEM_MOD_INTELLECT_SHORT = 2, ITEM_MOD_SPELL_POWER_SHORT = 5 } },
  [5000] = { "Mace of Mending", "INVTYPE_WEAPONMAINHAND", 2, 4, 19, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 48 } },
  [5001] = { "Tome of Knowledge", "INVTYPE_HOLDABLE", 4, 0, 18, { ITEM_MOD_INTELLECT_SHORT = 6, ITEM_MOD_SPIRIT_SHORT = 4, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 8 } },
}
CACHED = {}
EQUIP = { [3] = link(4314), [15] = link(6378), [16] = link(2042), [11] = link(12006), [12] = link(11967) }
LISTINGS = {}

-- O tooltip do jogo: o addon se pendura no TooltipDataProcessor; hover(link) faz o que o jogo faz.
POSTCALLS = {}
Enum.TooltipDataType = { Item = 0 }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) POSTCALLS[#POSTCALLS + 1] = fn end }
local function newTip()
  return { lines = {}, GetItem = function(self) return nil, self.link end,
    AddLine = function(self, t, r, g, b) self.lines[#self.lines + 1] = { t = t, r = r, g = g, b = b } end, Show = function() end }
end
GameTooltip, ItemRefTooltip, ShoppingTooltip1 = newTip(), newTip(), newTip()
function hover(l, tt)
  tt = tt or GameTooltip
  tt.lines, tt.link = {}, l
  for _, fn in ipairs(POSTCALLS) do fn(tt, {}) end
  return tt.lines
end
function text(lines) local t = {}; for _, l in ipairs(lines) do t[#t + 1] = l.t end; return table.concat(t, "\n") end
`;

const driver = String.raw`
local FU = loadAddon()
fire("PLAYER_LOGIN")
assert(#POSTCALLS == 1, "o tooltip devia se pendurar no TooltipDataProcessor")

-- Ombro: +3,6 no lugar do equipado, com o que muda.
local L = hover(link(4315))
local T = text(L)
assert(L[1] and L[1].t:find("Upgrade +3,6 · no lugar de Double-Stitched Woolen Shoulders", 1, true) and L[1].g == 1, "ombro: " .. T)
assert(L[2] and L[2].t:find("+4 Int", 1, true) and L[2].t:find("-4 Sta", 1, true), "o que muda nos stats: " .. T)

-- Capa com a cura só no tooltip (+11 - 3 = +8), que pede lvl 21.
T = text(hover(link(6604, 1)))
assert(T:find("Upgrade +8,0 · no lugar de Seer's Cape", 1, true) and T:find("pede lvl 21", 1, true), "capa: " .. T)

-- Anel: contra o mais fraco dos dois (o Zircon).
T = text(hover(link(1449)))
assert(T:find("no lugar de Zircon Band of Concentration", 1, true), "anel contra o mais fraco: " .. T)

-- Robe num slot vazio.
T = text(hover(link(9999)))
assert(T:find("Upgrade +27,0 · no lugar de vazio", 1, true) and T:find("pede lvl 25", 1, true), "robe: " .. T)

-- Maça sozinha perde da staff, e avisa que com off-hand soma.
T = text(hover(link(5000)))
assert(T:find("Pior que Staff of Westfall (-8,1)", 1, true) and T:find("com uma, soma", 1, true), "maça: " .. T)

-- Tomo com staff na mão: só junto com arma de 1 mão.
T = text(hover(link(5001)))
assert(T:find("Off-hand: +15,8 junto com uma arma de 1 mão", 1, true), "tomo: " .. T)

-- Nada no que está equipado, no que a classe não usa e nos tooltips de comparação.
assert(#hover(link(4314)) == 0, "equipado: nada")
assert(#hover(link(8888)) == 0, "placa: priest não usa")
assert(#hover(link(4315), ShoppingTooltip1) == 0, "tooltip de comparação: nada")
assert(#hover(link(4315), ItemRefTooltip) > 0, "link no chat: mostra")

-- Troca de peça: o equipado é lido de novo.
EQUIP[3] = link(4315)
fire("PLAYER_EQUIPMENT_CHANGED")
assert(#hover(link(4315)) == 0, "o ombro novo agora é o equipado")
T = text(hover(link(4314)))
assert(T:find("Pior que Reinforced Woolen Shoulders (-3,6)", 1, true), "o velho virou pior: " .. T)

-- Desligado.
FU.db().tooltipOff = true
assert(#hover(link(9999)) == 0, "tooltip desligado")
FU.db().tooltipOff = nil
`;

run('tooltip de item', setup, driver);
