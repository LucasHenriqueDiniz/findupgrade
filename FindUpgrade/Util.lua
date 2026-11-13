-- FindUpgrade · Util.lua
-- O que vários arquivos usam: as escolhas salvas do personagem, dinheiro em texto e números.

local _, FU = ...
FU = FU or FindUpgrade

function FU.say(msg) print("|cff88ccffFindUpgrade|r: " .. msg) end

-- Escolhas da janela, por personagem (FindUpgradeDB): filtros, aba, papel e posição.
function FU.db()
  FindUpgradeDB = FindUpgradeDB or {}
  local db = FindUpgradeDB
  if db.plus == nil then db.plus = 0 end
  if db.group == nil then db.group = "all" end
  if db.weaponMode == nil then db.weaponMode = "all" end
  if db.fitGold == nil then db.fitGold = false end
  if db.maxUnit == nil then db.maxUnit = "g" end
  return db
end

-- Preço máximo por peça, em cobre (nil = sem limite): o número da caixa × a moeda escolhida.
function FU.maxPiece()
  local db = FU.db()
  local unit = FU.UNIT_BY[db.maxUnit] or FU.UNIT_BY.g
  if not db.maxValue or db.maxValue <= 0 then return nil end
  return math.floor(db.maxValue * unit.mult + 0.5)
end

-- "1,5" ou "1.5" → 1.5; vazio, zero ou texto → nil.
function FU.parseNumber(t)
  t = tostring(t or ""):gsub("%s", ""):gsub(",", ".")
  local n = tonumber(t)
  if not n or n <= 0 then return nil end
  return n
end

-- 1.5 → "1,5"; 5 → "5".
function FU.numberText(n)
  if not n then return "" end
  return (string.format("%.2f", n):gsub("%.?0+$", ""):gsub("%.", ","))
end

function FU.coins(c)
  c = math.floor(math.abs(c or 0) + 0.5)
  local g, s, cu = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  if g > 0 then return string.format("%dg %ds", g, s) end
  if s > 0 then return string.format("%ds %dc", s, cu) end
  return cu .. "c"
end

-- Ganho com vírgula: 7.7 → "7,7".
function FU.num(v) return (string.format("%.1f", v):gsub("%.", ",")) end

function FU.itemIcon(id)
  return (id and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or 134400
end
