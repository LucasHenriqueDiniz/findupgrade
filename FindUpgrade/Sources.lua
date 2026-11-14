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

-- Lê as fontes de um item do banco. Fica a que ele consegue usar: quest não feita, dungeon (a de
-- maior % de drop), vendedor ou intendente da facção dele. kinds = todos os tipos que sobraram
-- (os botões Quests/Dungeons/Vendedores da janela olham esses).
local function bestSource(S, e, mySide)
  local best, kinds = nil, {}
  for i = 3, #e do
    local s = e[i]
    local k, cand = s[1], nil
    if k == 1 and not questDone(s[2]) then
      local q = S.quests[s[2]]
      cand = { kind = "quest", questId = s[2], quest = q and q[1], qlevel = q and q[3], zone = q and q[4] ~= "" and q[4] or nil }
    elseif k == 5 then
      local inst = S.instances[s[2]]
      cand = { kind = "quest", instance = inst and inst[1], zone = inst and inst[2] }
    elseif k == 2 then
      local inst = S.instances[s[2]]
      cand = { kind = "dungeon", instance = inst and inst[1], zone = inst and inst[2] ~= "" and inst[2] or nil, npc = s[3],
        rate = s[4] }
    elseif (k == 3 or k == 4) and (s[4] == 0 or mySide == 0 or s[4] == mySide) then
      cand = { kind = k == 3 and "vendor" or "rep", npc = s[2], zone = s[3] ~= "" and s[3] or nil }
    end
    if cand then
      kinds[cand.kind] = true
      local order = { quest = 4, dungeon = 3, vendor = 2, rep = 1 }
      if not best or order[cand.kind] > order[best.kind]
        or (cand.kind == "dungeon" and best.kind == "dungeon" and (cand.rate or 0) > (best.rate or 0)) then
        best = cand
      end
    end
  end
  if best then best.kinds = kinds end
  return best
end

-- A melhor fonte de um item só (o tooltip usa): nil se não está no banco ou não serve mais
-- (quest feita, peça da outra facção).
function src.forItem(id)
  local S = FU.SOURCES
  local e = S and S.items[id]
  if not e then return nil end
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  local mySide = (faction == "Alliance" and 1) or (faction == "Horde" and 2) or 0
  if not (e[2] == 0 or mySide == 0 or e[2] == mySide) then return nil end
  return bestSource(S, e, mySide)
end

-- Os candidatos no formato do leilão (o resto do addon não muda): { id, link, level, loc, class,
-- sub, price = 0, n = 1, src = { kind, kinds, quest, questId, qlevel, instance, npc, rate, zone } }.
-- Sai a peça da outra facção e a recompensa de quest que ele já fez. Nome e qualidade vêm do jogo
-- quando o item carrega (Engine.lua).
function src.load()
  local S = FU.SOURCES
  if not S then return nil end
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  local mySide = (faction == "Alliance" and 1) or (faction == "Horde" and 2) or 0
  local out = {}
  for id, e in pairs(S.items) do
    local req, side = e[1], e[2]
    if side == 0 or mySide == 0 or side == mySide then
      local best = bestSource(S, e, mySide)
      if best then
        local _, _, _, loc, _, classID, subID = C_Item.GetItemInfoInstant(id)
        -- Level negativo: o item só tem o mínimo da dungeon; o dele vem do jogo quando carregar.
        out[#out + 1] = { id = id, link = "item:" .. id, price = 0, n = 1, level = math.abs(req), levelGuess = req < 0 or nil,
          loc = loc, class = classID, sub = subID, src = best }
      end
    end
  end
  return out
end

-- Texto curto da fonte, pra coluna do preço: "Quest", "Deadmines 12%".
function src.short(s)
  if not s then return "" end
  if s.kind == "dungeon" then
    local name = (s.instance or s.zone or "Dungeon"):gsub("^The ", "")
    if #name > 16 then name = name:sub(1, 15) .. "…" end
    return name .. (s.rate and string.format(" %d%%", math.floor(s.rate + 0.5)) or "")
  end
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
