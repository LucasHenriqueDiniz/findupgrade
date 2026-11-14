-- FindUpgrade · Sources.lua
-- Peças que não estão no leilão: recompensa de quest, drop de boss de dungeon, rare e vendedor.
-- O jogo não tem essa lista, então ela vem do banco de outro addon instalado, lido no jogo
-- (o FindUpgrade não traz nem copia esses dados; ver docs/fontes.md):
--  · GearQuest Forever: GearQuest.Data.<classe>ItemFacts diz de onde vem cada item da classe
--    (quest, boss, vendedor...), o level pedido, a zona, o NPC e o texto de como pegar;
--    GearQuest.Data.questFaction diz qual recompensa é só da Aliança ou só da Horda.
--  · Wishwell Forever: WishwellData.instances e .items têm as tabelas de loot das dungeons, com
--    % de drop; WishwellData.quests dá o id de cada quest (pra esconder as que ele já fez).
-- Os dois são opcionais: com um só, vem o que ele tiver.

local _, FU = ...
FU = FU or FindUpgrade

local src = {}
FU.src = src

-- sourceType do GearQuest → o tipo nosso. World drop, profissão e "sem fonte" ficam de fora:
-- não dá pra ir buscar.
local GQ_KIND = { quest_reward = "quest", boss_drop = "dungeon", rare_npc = "rare", vendor = "vendor" }
src.KIND_LABEL = { quest = "Quest", dungeon = "Dungeon", rare = "Rare", vendor = "Vendedor" }

local function loadAddOn(name)
  local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
  if load then pcall(load, name) end
end

-- O banco do GearQuest pra classe. O módulo da classe é LoadOnDemand: se ainda não carregou,
-- carrega (é o que o próprio GearQuest faz).
local function gearQuest(cls)
  local GQ = _G.GearQuest
  if type(GQ) ~= "table" then return nil end
  local key = (cls or ""):lower() .. "ItemFacts"
  if not (type(GQ.Data) == "table" and type(GQ.Data[key]) == "table") then loadAddOn("GearQuestForever_" .. (cls or "")) end
  local data = type(GQ.Data) == "table" and GQ.Data or {}
  return type(data[key]) == "table" and data[key] or nil, type(data.questFaction) == "table" and data.questFaction or {}
end

local function wishwell()
  local W = _G.WishwellData
  if type(W) == "table" and type(W.items) == "table" then return W end
end

-- Quais bancos estão aí ("GearQuest", "Wishwell"), pra janela dizer de onde veio.
function src.available()
  local _, cls = UnitClass("player")
  local out = {}
  if gearQuest(cls) then out[#out + 1] = "GearQuest" end
  if wishwell() then out[#out + 1] = "Wishwell" end
  return out
end

-- Quest feita? (o id vem do Wishwell, pelo nome da quest)
local function questDone(id)
  if not id then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) == true end
  if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(id) == true end
  return false
end

-- Os candidatos no formato do leilão (o resto do addon não muda): { id, link, name, quality,
-- level, loc, class, sub, price = 0, n = 1, src = { kind, zone, npc, quest, questId, rate,
-- instance, text } }. Tira a recompensa da outra facção e a de quest que ele já fez.
function src.load()
  local _, cls = UnitClass("player")
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  local facts, questFaction = gearQuest(cls)
  local W = wishwell()
  if not facts and not W then return nil end
  local byId, list = {}, {}
  local function add(id, info)
    local g = byId[id]
    if not g then
      g = { id = id, link = "item:" .. id, price = 0, n = 1, src = {} }
      byId[id] = g
      list[#list + 1] = g
    end
    g.name = g.name or info.name
    g.quality = g.quality or info.quality
    if info.level and (not g.level or g.levelGuess) then g.level, g.levelGuess = info.level, info.levelGuess end
    for k, v in pairs(info.src) do
      if g.src[k] == nil then g.src[k] = v end
    end
  end
  for id, f in pairs(facts or {}) do
    local kind = type(f) == "table" and GQ_KIND[f.sourceType]
    local side = questFaction[id]
    if kind and not (side and faction and side ~= faction) then
      add(id, { name = f.name, quality = f.quality, level = f.reqLevel,
        src = { kind = kind, zone = f.zone, npc = f.npc, quest = f.questName, text = f.instructions } })
    end
  end
  if W then
    local inst = {}
    for _, i in ipairs(W.instances or {}) do inst[i.id] = i end
    for _, it in ipairs(W.items) do
      local i = it.raid and inst[it.raid]
      if i and i.kind == "dungeon" and it.id then
        local isQuest = it.boss == "Quest rewards"
        -- O level pedido do item só vem com o cache; até lá, o mínimo da dungeon serve de filtro.
        add(it.id, { name = it.name, quality = it.q, level = i.min, levelGuess = true,
          src = { kind = isQuest and "quest" or "dungeon", npc = not isQuest and it.boss or nil, rate = it.rate,
            instance = i.name, zone = i.zone } })
      end
    end
    -- Id da quest pelo nome (Wishwell), pra esconder a que ele já fez.
    local qid = {}
    for _, q in ipairs(W.quests or {}) do
      if type(q) == "table" and q[1] and q[2] then qid[q[2]] = q[1] end
    end
    for _, g in ipairs(list) do
      if g.src.quest then g.src.questId = qid[g.src.quest] end
    end
  end
  local out = {}
  for _, g in ipairs(list) do
    if not questDone(g.src.questId) then
      local _, _, _, loc, _, classID, subID = C_Item.GetItemInfoInstant(g.id)
      g.loc, g.class, g.sub = loc, classID, subID
      out[#out + 1] = g
    end
  end
  return out, nil
end

-- Texto curto da fonte, pra coluna do preço: "Quest", "Hall of Thanes 12%".
function src.short(s)
  if not s then return "" end
  if s.kind == "dungeon" then
    local name = s.instance or s.zone or "Dungeon"
    if #name > 16 then name = name:sub(1, 15) .. "…" end
    return name .. (s.rate and string.format(" %d%%", math.floor(s.rate + 0.5)) or "")
  end
  return src.KIND_LABEL[s.kind] or ""
end

-- Linhas do tooltip: de onde vem e como pegar.
function src.lines(s)
  local out = {}
  if not s then return out end
  if s.kind == "quest" then
    out[#out + 1] = "Recompensa da quest " .. (s.quest or "?") .. (s.zone and (" · " .. s.zone) or "")
      .. (s.instance and (" · " .. s.instance) or "")
  elseif s.kind == "dungeon" then
    out[#out + 1] = "Drop: " .. (s.npc or "boss") .. " · " .. (s.instance or s.zone or "dungeon")
      .. (s.rate and string.format(" · %s%%", (string.format("%.1f", s.rate):gsub("%.", ","))) or "")
  elseif s.kind == "rare" then
    out[#out + 1] = "Rare: " .. (s.npc or "?") .. (s.zone and (" · " .. s.zone) or "")
  elseif s.kind == "vendor" then
    out[#out + 1] = "Vendedor: " .. (s.npc or "?") .. (s.zone and (" · " .. s.zone) or "")
  end
  if s.text and s.text ~= "" then out[#out + 1] = s.text end
  return out
end
