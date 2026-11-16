-- FindUpgrade · Sources.lua
-- Peças que não estão no leilão: recompensa de quest, drop de boss de dungeon, vendedor e
-- intendente de reputação. O jogo não tem essa lista; ela vem do banco que vem junto com o addon
-- (SourcesData.lua, FU.SOURCES), gerado por tools/build-sources.mjs. Ver docs/fontes.md.

local _, FU = ...
FU = FU or FindUpgrade

local src = {}
FU.src = src

src.KIND_LABEL = { quest = "Quest", dungeon = "Dungeon", vendor = "Vendedor", rep = "Reputação" }

-- O banco está aí? (devolve a data em que foi gerado)
function src.available()
  return FU.SOURCES and FU.SOURCES.generated or nil
end

local function questDone(id)
  if not id then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) == true end
  if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(id) == true end
  return false
end

-- As quests que estão no log dele agora (id → true).
local function questLog()
  local set = {}
  pcall(function()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
      for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then set[info.questID] = true end
      end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
      for i = 1, (GetNumQuestLogEntries()) do
        local _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
        if not isHeader and id then set[id] = true end
      end
    end
  end)
  return set
end
src.questLog = questLog

-- Bit n (1 = o primeiro) de uma máscara; 0 = vale pra todos. Sem bit.band: as máscaras de raça
-- do Forever passam de 32 bits (as raças novas).
local function hasBit(mask, n)
  if not mask or mask == 0 or not n then return true end
  return math.floor(mask / 2 ^ (n - 1)) % 2 == 1
end

-- Quem ele é: facção, raça, classe, level e as quests do log. É o que decide se a quest serve.
local function who()
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  local race, class
  if UnitRace then race = select(3, UnitRace("player")) end
  if UnitClass then class = select(3, UnitClass("player")) end
  return { side = (faction == "Alliance" and 1) or (faction == "Horde" and 2) or 0, race = race, class = class,
    level = UnitLevel and UnitLevel("player") or 1, log = questLog(), memo = {} }
end
src.who = who

local function questOK(q, me)
  return q == nil or (hasBit(q[5], me.race) and hasBit(q[6], me.class))
end

-- Quantas quests ele ainda faz até poder pegar esta (as de antes que faltam) e por qual começa.
-- Quest no log ou feita: 0. Quest que a raça/classe dele não pega: NO (não serve).
local NO = 999
local function before(S, id, me, depth)
  local m = me.memo[id]
  if m then return m[1], m[2] end
  if depth > 30 then return 0, id end
  me.memo[id] = { NO, id } -- corrente circular no banco não trava
  local q = S.quests[id]
  local n, start = 0, id
  if not me.log[id] and q then
    local function need(p)
      if questDone(p) or me.log[p] then return 0, nil end
      if not questOK(S.quests[p], me) then return NO, nil end
      local b, st = before(S, p, me, depth + 1)
      return math.min(NO, b + 1), st
    end
    for _, p in ipairs(q[7] or {}) do
      local k, st = need(p)
      if k > 0 and start == id then start = st end
      n = math.min(NO, n + k)
    end
    if q[8] then
      local best, bst = NO, nil
      for _, p in ipairs(q[8]) do
        local k, st = need(p)
        if k < best then best, bst = k, st end
      end
      if best > 0 and start == id then start = bst end
      n = math.min(NO, n + best)
    end
  end
  me.memo[id] = { n, start }
  return n, start
end

-- Uma fonte da quest: no log (tier 1), dá pra pegar agora (2) ou tem quest antes (3).
local function questCand(S, qid, me)
  if questDone(qid) then return nil end
  local q = S.quests[qid]
  if not questOK(q, me) then return nil end
  local n, start = before(S, qid, me, 0)
  if n >= NO then return nil end
  local c = { kind = "quest", questId = qid, quest = q and q[1], qlevel = q and q[3], zone = q and q[4] ~= "" and q[4] or nil,
    lvl = q and q[2] or 0, starter = q and q[9] ~= "" and q[9] or nil, chain = n,
    tier = me.log[qid] and 1 or (n == 0 and 2 or 3) }
  local sq = n > 0 and S.quests[start]
  if sq then
    c.start, c.startLevel, c.startBy, c.startZone = sq[1], sq[2], sq[9] ~= "" and sq[9] or nil, sq[4] ~= "" and sq[4] or nil
  end
  return c
end

-- O level pra ter a peça: o pedido pelo item e o da fonte (quest de lvl 58 com item sem level
-- pedido era sugerida no 24 · 16/11).
local KIND_ORDER = { quest = 4, dungeon = 3, vendor = 2, rep = 1 }
local function better(a, b, me)
  local la, lb = a.lvl > me.level, b.lvl > me.level
  if la ~= lb then return lb end -- a que ele já pode pegar vem antes
  if a.kind ~= b.kind then return KIND_ORDER[a.kind] > KIND_ORDER[b.kind] end
  if a.kind == "quest" and (a.tier or 2) ~= (b.tier or 2) then return (a.tier or 2) < (b.tier or 2) end
  if a.kind == "dungeon" and (a.rate or 0) ~= (b.rate or 0) then return (a.rate or 0) > (b.rate or 0) end
  return a.lvl < b.lvl
end

-- As fontes de um item: a melhor de cada botão (Quests, Dungeons, Vendedores) e a melhor no
-- geral (o tooltip usa). O item pede |e[1]| (negativo = só o mínimo da dungeon).
local function sources(S, e, me)
  local by, best = {}, nil
  local req = math.abs(e[1] or 0)
  for i = 3, #e do
    local s = e[i]
    local k, cand = s[1], nil
    if k == 1 then
      cand = questCand(S, s[2], me)
    elseif k == 5 then
      local inst = S.instances[s[2]]
      cand = { kind = "quest", instance = inst and inst[1], zone = inst and inst[2], lvl = inst and inst[3] or 0, tier = 2, chain = 0 }
    elseif k == 2 then
      local inst = S.instances[s[2]]
      cand = { kind = "dungeon", instance = inst and inst[1], zone = inst and inst[2] ~= "" and inst[2] or nil, npc = s[3],
        rate = s[4], lvl = inst and inst[3] or 0 }
    elseif (k == 3 or k == 4) and (s[4] == 0 or me.side == 0 or s[4] == me.side) then
      cand = { kind = k == 3 and "vendor" or "rep", npc = s[2], zone = s[3] ~= "" and s[3] or nil, lvl = 0 }
    end
    if cand then
      cand.lvl = math.max(cand.lvl or 0, req)
      local view = cand.kind == "rep" and "vendor" or cand.kind
      if not by[view] or better(cand, by[view], me) then by[view] = cand end
      if not best or better(cand, best, me) then best = cand end
    end
  end
  if best then
    best.kinds = {}
    for v in pairs(by) do best.kinds[v] = true end
  end
  return best, by
end

-- A melhor fonte de um item só (o tooltip usa): nil se não está no banco ou não serve mais
-- (quest feita, peça da outra facção, quest de outra raça/classe).
function src.forItem(id)
  local S = FU.SOURCES
  local e = S and S.items[id]
  if not e then return nil end
  local me = who()
  if not (e[2] == 0 or me.side == 0 or e[2] == me.side) then return nil end
  return (sources(S, e, me))
end

-- Os candidatos no formato do leilão (o resto do addon não muda): { id, link, level, loc, class,
-- sub, price = 0, n = 1, src = a melhor fonte, srcBy = a melhor de cada botão }. Cada fonte tem
-- lvl (o level pra ter a peça por ela); a quest tem tier (1 no log, 2 dá pra pegar, 3 tem quest
-- antes), chain (quantas antes) e start (por qual começa). Nome e qualidade vêm do jogo quando o
-- item carrega (Engine.lua).
function src.load()
  local S = FU.SOURCES
  if not S then return nil end
  local me = who()
  local out = {}
  for id, e in pairs(S.items) do
    local req, side = e[1], e[2]
    if side == 0 or me.side == 0 or side == me.side then
      local best, by = sources(S, e, me)
      if best then
        local _, _, _, loc, _, classID, subID = C_Item.GetItemInfoInstant(id)
        -- Level negativo: o item só tem o mínimo da dungeon; o dele vem do jogo quando carregar.
        out[#out + 1] = { id = id, link = "item:" .. id, price = 0, n = 1, level = math.abs(req), levelGuess = req < 0 or nil,
          loc = loc, class = classID, sub = subID, src = best, srcBy = by }
      end
    end
  end
  return out
end

-- Texto curto da fonte, pra coluna do preço: "No log", "Pegar", "+2 quests", "Deadmines 12%".
function src.short(s)
  if not s then return "" end
  if s.kind == "dungeon" then
    local name = (s.instance or s.zone or "Dungeon"):gsub("^The ", "")
    if #name > 16 then name = name:sub(1, 15) .. "…" end
    return name .. (s.rate and string.format(" %d%%", math.floor(s.rate + 0.5)) or "")
  end
  if s.kind == "quest" and s.tier == 1 then return "|cff40ff40No log|r" end
  if s.kind == "quest" and (s.chain or 0) > 0 then return string.format("+%d quest%s", s.chain, s.chain > 1 and "s" or "") end
  if s.kind == "quest" and s.questId then return "Pegar" end
  return src.KIND_LABEL[s.kind] or ""
end

local function pct(r) return (string.format("%.1f", r):gsub("%.0$", ""):gsub("%.", ",")) .. "%" end

-- Linhas do tooltip (e do chat, no clique): de onde vem.
function src.lines(s)
  local out = {}
  if not s then return out end
  if s.kind == "quest" and s.quest then
    out[#out + 1] = "Recompensa da quest " .. s.quest .. (s.qlevel and s.qlevel > 0 and (" (lvl " .. s.qlevel .. ")") or "")
      .. (s.zone and (" · " .. s.zone) or "")
    if s.tier == 1 then
      out[#out + 1] = "Tá no teu log de quests"
    elseif (s.chain or 0) > 0 then
      out[#out + 1] = string.format("Antes dela: %d quest%s · começa em %s (lvl %d)%s%s", s.chain, s.chain > 1 and "s" or "",
        s.start or "?", s.startLevel or 0, s.startBy and (" com " .. s.startBy) or "", s.startZone and (" · " .. s.startZone) or "")
    elseif (s.lvl or 0) > (UnitLevel and UnitLevel("player") or 0) then
      out[#out + 1] = "Só dá pra pegar no lvl " .. s.lvl .. (s.starter and (" · com " .. s.starter) or "")
    else
      out[#out + 1] = "Dá pra pegar" .. (s.starter and (" com " .. s.starter) or "")
    end
  elseif s.kind == "quest" then
    out[#out + 1] = "Recompensa de quest da dungeon " .. (s.instance or "?") .. (s.zone and (" · " .. s.zone) or "")
  elseif s.kind == "dungeon" then
    local who = (not s.npc or s.npc == "Trash") and "trash" or s.npc
    out[#out + 1] = "Drop: " .. who .. " · " .. (s.instance or "dungeon") .. (s.zone and (" (" .. s.zone .. ")") or "")
      .. (s.rate and (" · " .. pct(s.rate)) or "")
  elseif s.kind == "vendor" then
    out[#out + 1] = "Vendedor: " .. (s.npc or "?") .. (s.zone and (" · " .. s.zone) or "")
  elseif s.kind == "rep" then
    out[#out + 1] = "Intendente de reputação: " .. (s.npc or "?") .. (s.zone and (" · " .. s.zone) or "")
  end
  return out
end
