-- FindUpgrade · Data.lua
-- Tabelas fixas: slots, classes (armadura, armas, escudo, duas armas), papéis com os pesos de
-- cada stat, chaves de stat do GetItemStats e nomes de stat do tooltip.
-- Mudou algo no jogo (uma classe nova, um peso que não bate)? É aqui. Ver docs/classes.md e
-- docs/pontuacao.md.

local _, FU = ...
FU = FU or {}
FindUpgrade = FU -- global: /dump FindUpgrade.ctx no jogo, e os testes leem

FU.VERSION = "1.7.1"
FU.PLUS = { 0, 3, 5, 10 } -- botões de level: só o meu, até +3, +5, +10
FU.MAXPLUS = 10
FU.PER_ITEM = 3 -- no máximo 3 combos com a mesma arma comprada (senão ela enche a lista)

FU.SLOT_IDS = { Head = 1, Neck = 2, Shoulder = 3, Chest = 5, Waist = 6, Legs = 7, Feet = 8, Wrist = 9, Hands = 10,
  Finger1 = 11, Finger2 = 12, Trinket1 = 13, Trinket2 = 14, Back = 15, MainHand = 16, OffHand = 17, Ranged = 18 }

FU.EQUIP_LOC = {
  INVTYPE_HEAD = { "Head" }, INVTYPE_NECK = { "Neck" }, INVTYPE_SHOULDER = { "Shoulder" }, INVTYPE_CHEST = { "Chest" },
  INVTYPE_ROBE = { "Chest" }, INVTYPE_WAIST = { "Waist" }, INVTYPE_LEGS = { "Legs" }, INVTYPE_FEET = { "Feet" },
  INVTYPE_WRIST = { "Wrist" }, INVTYPE_HAND = { "Hands" }, INVTYPE_FINGER = { "Finger1", "Finger2" },
  INVTYPE_TRINKET = { "Trinket1", "Trinket2" }, INVTYPE_CLOAK = { "Back" }, INVTYPE_2HWEAPON = { "MainHand" },
  INVTYPE_WEAPON = { "MainHand" }, INVTYPE_WEAPONMAINHAND = { "MainHand" }, INVTYPE_WEAPONOFFHAND = { "OffHand" },
  INVTYPE_HOLDABLE = { "OffHand" }, INVTYPE_SHIELD = { "OffHand" }, INVTYPE_RANGED = { "Ranged" },
  INVTYPE_RANGEDRIGHT = { "Ranged" }, INVTYPE_THROWN = { "Ranged" },
}

local function set(list)
  local t = {}
  for _, v in ipairs(list) do t[v] = true end
  return t
end

-- Subclasse de arma (classe 2): 0 machado 1M · 1 machado 2M · 2 arco · 3 arma de fogo · 4 maça 1M ·
-- 5 maça 2M · 6 lança (polearm) · 7 espada 1M · 8 espada 2M · 10 cajado · 13 arma de punho ·
-- 15 adaga · 16 arremesso · 18 besta · 19 varinha.
-- Armadura (classe 4): 0 diversos (anel, colar, trinket, off-hand) · 1 pano · 2 couro · 3 malha ·
-- 4 placa · 6 escudo.
-- armor = a armadura que a classe usa; armor40 = a partir do level 40. shield = usa escudo;
-- dw = luta com duas armas; offhand = segura item de mão secundária (livro, orbe).
-- roles: papéis da classe, o primeiro é o padrão (dá pra trocar na janela).
FU.CLASSES = {
  WARRIOR = { armor = 3, armor40 = 4, shield = true, dw = true,
    weapons = set({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }), roles = { "str", "tank" } },
  PALADIN = { armor = 3, armor40 = 4, shield = true,
    weapons = set({ 0, 1, 4, 5, 6, 7, 8 }), roles = { "heal", "tank", "str" } },
  HUNTER = { armor = 2, armor40 = 3, dw = true,
    weapons = set({ 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }), roles = { "hunter" } },
  ROGUE = { armor = 2, dw = true,
    weapons = set({ 2, 3, 4, 7, 13, 15, 16, 18 }), roles = { "agi" } },
  PRIEST = { armor = 1, offhand = true,
    weapons = set({ 4, 10, 15, 19 }), roles = { "heal", "spell" } },
  SHAMAN = { armor = 2, armor40 = 3, shield = true, offhand = true,
    weapons = set({ 0, 1, 4, 5, 10, 13, 15 }), roles = { "heal", "spell", "str" } },
  MAGE = { armor = 1, offhand = true,
    weapons = set({ 7, 10, 15, 19 }), roles = { "spell" } },
  WARLOCK = { armor = 1, offhand = true,
    weapons = set({ 7, 10, 15, 19 }), roles = { "warlock" } },
  DRUID = { armor = 2, offhand = true,
    weapons = set({ 4, 5, 10, 13, 15 }), roles = { "heal", "spell", "agi", "tank" } },
}

-- Papéis: o peso de cada stat (ganho = soma de stat × peso, menos a do equipado).
-- Cura e dano mágico em pontos de cura/dano; físico em pontos de Attack Power: 1 Str = 2 AP pro
-- warrior, 20 Agi ≈ 1% de crítico, 1 de DPS de arma ≈ 14 AP (ver docs/pontuacao.md e as fontes).
-- crit, hit, dodge, parry, block: por 1%. dpsBy: quanto o DPS de cada arma conta (a off-hand bate
-- metade no dual wield; o caçador vive da arma de distância). min: ganho mínimo pra aparecer.
FU.ROLES = {
  heal = { label = "Cura", min = 2,
    w = { heal = 1.0, int = 0.9, spi = 0.6, mp5 = 1.6, sta = 0.25, armor = 0.004 } },
  spell = { label = "Dano mágico", min = 2,
    w = { dmg = 1.0, int = 0.7, spi = 0.3, mp5 = 1.2, sta = 0.4, spellcrit = 10, spellhit = 10, armor = 0.004 } },
  warlock = { label = "Dano mágico", min = 2,
    w = { dmg = 1.0, int = 0.6, spi = 0.4, mp5 = 1.0, sta = 0.6, spellcrit = 10, spellhit = 10, armor = 0.004 } },
  str = { label = "DPS (força)", min = 4,
    w = { str = 2, ap = 1, agi = 1, crit = 20, hit = 15, sta = 0.5, dps = 14, armor = 0.02 },
    dpsBy = { MainHand = 1, OffHand = 0.5, Ranged = 0.1 } },
  agi = { label = "DPS (agilidade)", min = 4,
    w = { agi = 2, ap = 1, str = 1, crit = 20, hit = 15, sta = 0.5, dps = 14, armor = 0.02 },
    dpsBy = { MainHand = 1, OffHand = 0.5, Ranged = 0.1 } },
  hunter = { label = "Caçador", min = 4,
    w = { agi = 2, rap = 1, ap = 0.2, int = 0.5, mp5 = 1, crit = 20, hit = 15, sta = 0.5, dps = 14, armor = 0.02 },
    dpsBy = { MainHand = 0.15, OffHand = 0.05, Ranged = 1 } },
  tank = { label = "Tank", min = 4,
    w = { sta = 2.5, def = 3, armor = 0.1, agi = 1.5, str = 1, dodge = 25, parry = 25, block = 15, blockValue = 0.5,
      hit = 8, ap = 0.3, dps = 3 },
    dpsBy = { MainHand = 1, OffHand = 0, Ranged = 0 } },
}

-- Spell power (cura e dano mágico) no level baixo vale bem menos que os pesos acima, que são de
-- quem está no ~40. No 16 o tooltip dava a Tear of Grief (+5 Int) pior que o Dwarven Tome (+3 SP),
-- e é o contrário (14/11). Duas razões:
--  1. rank aprendido antes do 20 recebe menos do bônus: 1 - (20 - level do rank) x 3,75%; o rank
--     que se usa costuma ser de uns 3 levels antes;
--  2. com pouca mana saem poucas curas até acabar, e cada uma ganha o bônus uma vez; o Int (15 de
--     mana por ponto) rende o mesmo em qualquer level. Mana / custo da cura do priest: ~3 no 16,
--     ~4 no 20, ~5 no 30, ~6 no 40.
-- O peso de cura e de dano mágico do papel vai x FU.spellScale(level): 0,38 no 16, 0,53 no 20,
-- 0,8 no 30, 1 do 40 pra cima. Peso que ele mudou na tela de configurações fica como ele pôs.
FU.SPELL_POWER = { heal = true, dmg = true }
function FU.spellScale(level)
  level = level or 60
  local coef = level >= 23 and 1 or math.max(0.3, 1 - (23 - level) * 0.0375)
  return coef * math.min(1, (level + 10) / 50)
end

-- O peso padrão do papel no level (com a conta acima).
function FU.roleWeight(rs, stat, level)
  local v = rs.w[stat]
  if v and FU.SPELL_POWER[stat] then v = v * FU.spellScale(level) end
  return v
end

-- Chave do GetItemStats → stat. A primeira que bater vale, por isso a ordem importa:
-- SPELL_HEALING antes de SPELL_POWER, SPELL_CRIT antes de CRIT, RANGED_ATTACK_POWER antes de
-- ATTACK_POWER, BLOCK_VALUE antes de BLOCK.
FU.STAT_KEYS = {
  { "SPELL_HEALING", { "heal" } }, { "SPELL_POWER", { "heal", "dmg" } }, { "SPELL_DAMAGE", { "dmg" } },
  { "SPELL_CRIT", { "spellcrit" } }, { "SPELL_HIT", { "spellhit" } },
  { "MANA_REGENERATION", { "mp5" } }, { "POWER_REGEN0", { "mp5" } }, { "HEALTH_REGEN", { "hp5" } },
  { "INTELLECT", { "int" } }, { "SPIRIT", { "spi" } }, { "STAMINA", { "sta" } }, { "AGILITY", { "agi" } },
  { "STRENGTH", { "str" } }, { "RANGED_ATTACK_POWER", { "rap" } }, { "ATTACK_POWER", { "ap" } },
  { "BLOCK_VALUE", { "blockValue" } }, { "BLOCK", { "block" } }, { "DODGE", { "dodge" } }, { "PARRY", { "parry" } },
  { "DEFENSE", { "def" } }, { "CRIT", { "crit" } }, { "HIT", { "hit" } },
  { "DAMAGE_PER_SECOND", { "dps" } }, { "RESISTANCE0_NAME", { "armor" } },
}

-- Linha "+N Nome" do tooltip → stat (em inglês; os nomes no idioma do cliente entram abaixo).
FU.TIP_NAMES = {
  intellect = { "int" }, spirit = { "spi" }, stamina = { "sta" }, agility = { "agi" }, strength = { "str" },
  ["spell power"] = { "heal", "dmg" }, healing = { "heal" }, ["bonus healing"] = { "heal" }, ["spell damage"] = { "dmg" },
  ["spell healing"] = { "heal" }, -- "+48 Spell Healing" (Staff of Westfall no Forever)
  ["mana per 5 sec."] = { "mp5" }, ["mana per 5 sec"] = { "mp5" }, ["mana every 5 sec."] = { "mp5" },
  ["attack power"] = { "ap" }, ["ranged attack power"] = { "rap" }, defense = { "def" }, ["defense rating"] = { "def" },
  ["health per 5 sec."] = { "hp5" }, block = { "blockValue" },
}
-- Cliente em outro idioma: o nome curto dos atributos vem das strings globais do próprio jogo
-- ("Intelecto" no ptBR). As frases de "Equip:" continuam só em inglês (ver docs/idioma.md).
for key, stat in pairs({ ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi", ITEM_MOD_STAMINA_SHORT = "sta",
  ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STRENGTH_SHORT = "str" }) do
  local name = _G[key]
  if type(name) == "string" and name ~= "" then FU.TIP_NAMES[name:lower()] = { stat } end
end

-- Coluna da esquerda (o "Tudo" vem antes). inv = slot do paperdoll, pro ícone de slot vazio.
FU.GROUPS = {
  { key = "weapon", label = "Armas", slots = { "MainHand", "OffHand" }, inv = "MainHandSlot" },
  { key = "Ranged", label = "Distância", slots = { "Ranged" }, inv = "RangedSlot" },
  { key = "Head", label = "Cabeça", slots = { "Head" }, inv = "HeadSlot" },
  { key = "Neck", label = "Colar", slots = { "Neck" }, inv = "NeckSlot" },
  { key = "Shoulder", label = "Ombro", slots = { "Shoulder" }, inv = "ShoulderSlot" },
  { key = "Back", label = "Capa", slots = { "Back" }, inv = "BackSlot" },
  { key = "Chest", label = "Peito", slots = { "Chest" }, inv = "ChestSlot" },
  { key = "Wrist", label = "Pulso", slots = { "Wrist" }, inv = "WristSlot" },
  { key = "Hands", label = "Mãos", slots = { "Hands" }, inv = "HandsSlot" },
  { key = "Waist", label = "Cinto", slots = { "Waist" }, inv = "WaistSlot" },
  { key = "Legs", label = "Calça", slots = { "Legs" }, inv = "LegsSlot" },
  { key = "Feet", label = "Pés", slots = { "Feet" }, inv = "FeetSlot" },
  { key = "Finger", label = "Anéis", slots = { "Finger1", "Finger2" }, inv = "Finger0Slot" },
  { key = "Trinket", label = "Trinkets", slots = { "Trinket1", "Trinket2" }, inv = "Trinket0Slot" },
}
FU.GROUP_OF, FU.GROUP_BY = {}, {}
for _, gr in ipairs(FU.GROUPS) do
  FU.GROUP_BY[gr.key] = gr
  for _, s in ipairs(gr.slots) do FU.GROUP_OF[s] = gr.key end
end

-- Nome de cada stat (tela de configurações, pesos), na ordem em que aparecem lá.
FU.STAT_ORDER = { "heal", "dmg", "int", "spi", "mp5", "sta", "str", "agi", "ap", "rap", "crit", "hit", "spellcrit",
  "spellhit", "dps", "def", "dodge", "parry", "block", "blockValue", "armor" }
FU.STAT_LABEL = { heal = "Cura", dmg = "Dano mágico", int = "Intelecto", spi = "Espírito", mp5 = "Mana a cada 5s",
  sta = "Stamina", str = "Força", agi = "Agilidade", ap = "Attack Power", rap = "AP à distância", crit = "1% crítico",
  hit = "1% acerto", spellcrit = "1% crítico mágico", spellhit = "1% acerto mágico", dps = "1 DPS de arma",
  def = "Defesa", dodge = "1% esquiva", parry = "1% aparar", block = "1% bloqueio", blockValue = "Valor de bloqueio",
  armor = "Armadura" }

-- Moedas da caixa de preço máximo.
FU.UNITS = {
  { key = "g", label = "Ouro", mult = 10000, icon = "Interface\\MoneyFrame\\UI-GoldIcon" },
  { key = "s", label = "Prata", mult = 100, icon = "Interface\\MoneyFrame\\UI-SilverIcon" },
  { key = "c", label = "Cobre", mult = 1, icon = "Interface\\MoneyFrame\\UI-CopperIcon" },
}
FU.UNIT_BY = {}
for _, u in ipairs(FU.UNITS) do FU.UNIT_BY[u.key] = u end
