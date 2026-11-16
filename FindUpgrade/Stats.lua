-- FindUpgrade · Stats.lua
-- Os stats de uma peça e a nota dela pro papel do personagem.
-- Fonte 1: C_Item.GetItemStats (chaves ITEM_MOD_*, iguais em qualquer idioma).
-- Fonte 2: o tooltip (C_TooltipInfo), pro que o GetItemStats não traz no Forever (cura do
-- "+48 Spell Healing", crítico, acerto, defesa, bloqueio). Por stat vale o maior dos dois.

local _, FU = ...
FU = FU or FindUpgrade

FU.cache, FU.blockedCache = {}, {}

local function maxInto(s, keys, v)
  for _, k in ipairs(keys) do
    if v > (s[k] or 0) then s[k] = v end
  end
end

-- Guarda as chaves de stat que o cliente usa (false = chave que o mapa ainda não entende).
-- Fica em FindUpgradeDB.statKeys: é por aí que se descobre chave nova numa versão do jogo.
function FU.noteKey(key, known)
  local db = FU.db()
  local t = db.statKeys or {}
  db.statKeys = t
  if t[key] == nil then
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    if n < 80 then t[key] = known end
  end
end

-- Frases de "Equip:" (inglês) → stat. A ordem importa: as de feitiço antes das gerais.
local EQUIP_PATTERNS = {
  { "critical strike with spells by (%d+)%%", { "spellcrit" } },
  { "chance to hit with spells by (%d+)%%", { "spellhit" } },
  { "critical strike by (%d+)%%", { "crit" } },
  { "chance to hit by (%d+)%%", { "hit" } },
  { "dodge an attack by (%d+)%%", { "dodge" } },
  { "parry an attack by (%d+)%%", { "parry" } },
  { "block attacks with a shield by (%d+)%%", { "block" } },
  { "block value of your shield by (%d+)", { "blockValue" } },
  { "Increased Defense %+(%d+)", { "def" } },
  { "%+(%d+) ranged Attack Power", { "rap" } },
  { "%+(%d+) Attack Power", { "ap" } },
}

-- Stats do tooltip: completa o que o GetItemStats não trouxer. Com slot, lê o tooltip da peça
-- equipada (o item de verdade, com sufixo e encantamento), senão o do link.
function FU.tooltipStats(link, s, slot)
  if not C_TooltipInfo then return end
  local ok, data
  if slot and C_TooltipInfo.GetInventoryItem then
    ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
  end
  if not (ok and type(data) == "table") and C_TooltipInfo.GetHyperlink then
    ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
  end
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return end
  for _, line in ipairs(data.lines) do
    local t = line.leftText
    if type(t) == "string" then
      local v, name = t:match("^%+(%d+) (.+)$")
      local keys = name and FU.TIP_NAMES[name:lower()]
      if keys then maxInto(s, keys, tonumber(v)) end
      local up = tonumber(t:match("by up to (%d+)") or "")
      if up then
        if t:find("damage and healing") then
          maxInto(s, { "heal", "dmg" }, up)
        elseif t:find("healing") then
          maxInto(s, { "heal" }, up)
        elseif t:find("damage done by") then
          maxInto(s, { "dmg" }, up)
        end
      end
      local mana = tonumber(t:match("[Rr]estores (%d+) mana per 5") or "")
      if mana then maxInto(s, { "mp5" }, mana) end
      local armor = tonumber(t:match("^(%d+) Armor$") or "")
      if armor then maxInto(s, { "armor" }, armor) end
      local block = tonumber(t:match("^(%d+) Block$") or "")
      if block then maxInto(s, { "blockValue" }, block) end
      local dps = tonumber(t:match("%(([%d%.]+) damage per second%)") or "")
      if dps then maxInto(s, { "dps" }, dps) end
      if t:find("^Equip:") then
        for _, p in ipairs(EQUIP_PATTERNS) do
          local n = tonumber(t:match(p[1]) or "")
          if n then
            maxInto(s, p[2], n)
            break
          end
        end
      end
    end
  end
end

-- Pede os dados do item ao servidor, no máximo 1 vez a cada 2 s por item (a conta tenta de novo
-- a cada meio segundo e não precisa pedir de novo).
FU.asked = {}
function FU.requestItem(id)
  local now = GetTime and GetTime() or 0
  if (FU.asked[id] or -10) > now - 2 then return end
  FU.asked[id] = now
  if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
end

-- Stats de um link (nil se o cliente ainda não tem os dados do item: pede e tenta depois).
function FU.stats(link, noCache, slot)
  if not link then return nil end
  local c = not noCache and FU.cache[link]
  if c then return c end
  local id = tonumber(link:match("item:(%d+)") or "")
  if id and C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(id) then
    FU.requestItem(id)
    return nil
  end
  local s = {}
  local get = (C_Item and C_Item.GetItemStats) or GetItemStats
  local ok, raw = pcall(get or error, link)
  if ok and type(raw) == "table" then
    for key, v in pairs(raw) do
      if type(key) == "string" and type(v) == "number" then
        local hit = false
        for _, m in ipairs(FU.STAT_KEYS) do
          if key:find(m[1], 1, true) then
            for _, k in ipairs(m[2]) do s[k] = (s[k] or 0) + v end
            hit = true
            break
          end
        end
        FU.noteKey(key, hit)
      end
    end
  end
  FU.tooltipStats(link, s, slot)
  if not noCache then FU.cache[link] = s end
  return s
end

-- Nota da peça pro papel: soma de stat × peso. O DPS da arma conta conforme a mão (dpsBy do
-- papel): metade na off-hand de quem luta com duas armas, quase nada na distância do warrior.
function FU.scoreFor(s, ctx, slot)
  local w, by = ctx.w, ctx.rs and ctx.rs.dpsBy
  local total = 0
  for k, wt in pairs(w) do
    local v = s[k]
    if v then
      if k == "dps" and by then wt = wt * (by[slot] or 0) end
      total = total + v * wt
    end
  end
  return total
end

-- Linha vermelha de requisito que ele não cumpre (profissão, reputação, classe, raça). O level
-- fica de fora: quem decide é o filtro de level da janela.
function FU.blocked(link)
  local c = FU.blockedCache[link]
  if c ~= nil then return c end
  local res = false
  if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    for _, line in ipairs(ok and type(data) == "table" and data.lines or {}) do
      local t, col = line.leftText, line.leftColor
      if type(t) == "string" and type(col) == "table" and (col.r or 0) > 0.9 and (col.g or 1) < 0.35 and (col.b or 1) < 0.35
        and not t:find("^Requires [Ll]evel") and (t:find("^Requires") or t:find("^Classes") or t:find("^Races")) then
        res = t
        break
      end
    end
  end
  FU.blockedCache[link] = res
  return res
end

-- Texto curto dos stats: "+4 Int +5 SP", "+12 Str 2% crít 18,5 dps".
function FU.statText(s)
  local parts = {}
  local function add(v, label) if v and v > 0 then parts[#parts + 1] = "+" .. v .. " " .. label end end
  local function pct(v, label) if v and v > 0 then parts[#parts + 1] = v .. "% " .. label end end
  add(s.str, "Str")
  add(s.agi, "Agi")
  add(s.int, "Int")
  add(s.spi, "Spi")
  if s.heal and s.dmg and s.heal == s.dmg then
    add(s.heal, "SP")
  else
    add(s.heal, "Cura")
    add(s.dmg, "Dano")
  end
  add(s.mp5, "mp5")
  add(s.sta, "Sta")
  add(s.ap, "AP")
  add(s.rap, "RAP")
  pct(s.crit, "crít")
  pct(s.hit, "acerto")
  pct(s.spellcrit, "crít mág")
  pct(s.spellhit, "acerto mág")
  add(s.def, "Def")
  pct(s.dodge, "esquiva")
  pct(s.parry, "aparar")
  pct(s.block, "bloqueio")
  if s.dps and s.dps > 0 then parts[#parts + 1] = (string.format("%.1f dps", s.dps):gsub("%.", ",")) end
  return table.concat(parts, " ")
end

-- Os pesos do papel em texto ("Cura ×1 · Int ×0,9 · ..."), pro tooltip do ganho.
function FU.weightText(w)
  local order = { "heal", "dmg", "str", "agi", "int", "spi", "mp5", "sta", "ap", "rap", "crit", "hit", "spellcrit",
    "spellhit", "dps", "def", "dodge", "parry", "block", "blockValue", "armor" }
  local names = { heal = "Cura", dmg = "Dano", int = "Int", spi = "Spi", mp5 = "mp5", sta = "Sta", agi = "Agi",
    str = "Str", ap = "AP", rap = "RAP", crit = "1% crít", hit = "1% acerto", spellcrit = "1% crít mág",
    spellhit = "1% acerto mág", dps = "1 dps de arma", def = "Def", dodge = "1% esquiva", parry = "1% aparar",
    block = "1% bloqueio", blockValue = "valor de bloqueio", armor = "Armadura" }
  local parts = {}
  for _, k in ipairs(order) do
    if w[k] then parts[#parts + 1] = names[k] .. " ×" .. (tostring(w[k]):gsub("%.", ",")) end
  end
  return table.concat(parts, " · ")
end
