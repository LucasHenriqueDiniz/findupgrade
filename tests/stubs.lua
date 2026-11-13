-- API do WoW simulada pros testes (fengari). O teste define antes de carregar o addon:
--   ITEMS[id] = { nome, equipLoc, classe, subclasse, level, stats do GetItemStats, linhas do tooltip }
--   EQUIP[slot] = link equipado · LISTINGS = { { id, buyout, link }, ... } · CACHED[id] = false (sem dados)
--   CLASS, LEVEL, MONEY
local events, timers = {}, {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
function runTimers() local n = 0; while #timers > 0 and n < 6000 do n = n + 1; local fn = table.remove(timers, 1); fn() end end
function fire(e, ...) for _, f in ipairs(events[e] or {}) do if f.fn then f.fn(f, e, ...) end end; runTimers() end
function clearEvents() for k in pairs(events) do events[k] = nil end end
function InCombatLockdown() return false end
time = os.time; date = os.date
SlashCmdList = {}
PRINTED = {}
function print(...) PRINTED[#PRINTED + 1] = table.concat({ ... }, " ") end
CLASS, LEVEL, MONEY = "PRIEST", 20, 5686
function GetMoney() return MONEY end
function UnitLevel() return LEVEL end
function UnitClass() return CLASS, CLASS end
function GetRealmName() return "Normal" end
function UnitFactionGroup() return "Alliance" end
function IsModifiedClick() return false end
function strsplit(sep, str) local out = {}; for part in (str .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = part end; return table.unpack(out) end
unpack = table.unpack

local function mock()
  local o = { shown = true, scripts = {} }
  return setmetatable(o, { __index = function(_, k)
    if k == "CreateTexture" or k == "CreateFontString" then return function() return mock() end end
    if k == "SetText" then return function(self, v) self.text = v end end
    if k == "GetText" then return function(self) return self.text end end
    if k == "SetTexture" then return function(self, v) self.tex = v end end
    if k == "SetChecked" then return function(self, v) self.checked = v end end
    if k == "SetEnabled" then return function(self, v) self.enabled = v end end
    if k == "Show" then return function(self) self.shown = true end end
    if k == "Hide" then return function(self) self.shown = false end end
    if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
    if k == "IsShown" then return function(self) return self.shown end end
    if k == "SetScript" then return function(self, n, fn) self.scripts[n] = fn; if n == "OnEvent" then self.fn = fn end end end
    if k == "RegisterEvent" then return function(self, e) events[e] = events[e] or {}; table.insert(events[e], self) end end
    if not k:match("^%u") then return nil end -- campo (row.r etc.): nil como num frame de verdade
    return function() end
  end })
end
function CreateFrame(_, name) local o = mock(); if name then _G[name] = o end; return o end
UIParent = mock()
UISpecialFrames = {}
tinsert = table.insert
Enum = { AuctionHouseSortOrder = { Price = 0 } }
ITEMS, EQUIP, LISTINGS, CACHED, LOADREQ = {}, {}, {}, {}, {}

local function idOf(l) return tonumber(tostring(l):match("item:(%d+)")) end
function link(id, suffix)
  return "|cff1eff00|Hitem:" .. id .. "::::::::20:1487:::" .. (suffix or "") .. "::::::|h[" .. ITEMS[id][1]
    .. (suffix and " of Healing" or "") .. "]|h|r"
end
C_Item = {
  GetItemNameByID = function(id) if CACHED[id] == false then return nil end; return ITEMS[id] and ITEMS[id][1] end,
  GetItemIconByID = function(id) return 1000 + id end,
  GetItemInfo = function(l) local x = ITEMS[idOf(l)]; if x then return x[1], l, 2, 20, x[5], "", "", 1, x[2], 134400, 100 end end,
  GetItemInfoInstant = function(v) local id = type(v) == "number" and v or idOf(v); local x = ITEMS[id]; if x then return id, "", "", x[2], 134400, x[3], x[4] end end,
  IsItemDataCachedByID = function(id) return CACHED[id] ~= false end,
  RequestLoadItemDataByID = function(id) if CACHED[id] == false then LOADREQ[id] = (LOADREQ[id] or 0) + 1; if LOADREQ[id] >= 2 then CACHED[id] = true end end end,
  GetItemStats = function(l) local x = ITEMS[idOf(l)]; if x then local t = {}; for k, v in pairs(x[6] or {}) do t[k] = v end; return t end end,
}
C_TooltipInfo = {
  GetHyperlink = function(l)
    local x = ITEMS[idOf(l)]
    local lines = {}
    for _, t in ipairs(x and x[7] or {}) do
      if type(t) == "table" then
        lines[#lines + 1] = { leftText = t[1], leftColor = { r = 1, g = 0.125, b = 0.125 } }
      else
        lines[#lines + 1] = { leftText = t, leftColor = { r = 1, g = 1, b = 1 } }
      end
    end
    return { lines = lines }
  end,
  GetInventoryItem = function(_, slot) EQTIP = (EQTIP or 0) + 1; return C_TooltipInfo.GetHyperlink(EQUIP[slot]) end,
}
function GetInventoryItemLink(_, slot)
  local l = EQUIP[slot]
  if l and CACHED[idOf(l)] == false then return (l:gsub("%[.-%]", "[]")) end
  return l
end
function GetInventoryItemTexture(_, slot) local l = EQUIP[slot]; return l and (1000 + idOf(l)) or nil end
function GetInventorySlotInfo(name) return 0, "empty-" .. name end
C_AuctionHouse = {
  ReplicateItems = function() REPLICATED = (REPLICATED or 0) + 1 end,
  GetNumReplicateItems = function() return #LISTINGS end,
  GetReplicateItemInfo = function(i)
    local l = LISTINGS[i + 1]; local x = ITEMS[l[1]]
    return l[3]:match("%[(.-)%]"), nil, 1, 2, true, x[5], "level", 0, 0, l[2], 0, nil, nil, "x", "x", 0, l[1], true
  end,
  GetReplicateItemLink = function(i) return LISTINGS[i + 1][3] end,
}
SEARCHED = {}
AuctionHouseFrameDisplayMode = { Buy = 1 }
function openAH()
  AuctionHouseFrame = { SearchBar = { SetSearchText = function(_, t) SEARCHED.text = t end, StartSearch = function() SEARCHED.n = (SEARCHED.n or 0) + 1 end },
    SetDisplayMode = function(_, m) SEARCHED.mode = m end }
  fire("AUCTION_HOUSE_SHOW")
end

-- Carrega os arquivos do addon na ordem do .toc, com o namespace compartilhado.
function loadAddon()
  local ns = {}
  for _, f in ipairs(ADDON_FILES) do
    local chunk = assert(load(f.src, "=" .. f.name))
    chunk("FindUpgrade", ns)
  end
  fire("ADDON_LOADED", "FindUpgrade")
  return ns
end

-- Ajudas dos testes.
function has(text) for _, p in ipairs(PRINTED) do if p:find(text, 1, true) then return true end end end
function near(a, b) return a and math.abs(a - b) < 0.01 end
function noErrors() for _, p in ipairs(PRINTED) do assert(not p:find("erro"), "erro impresso: " .. p) end end
function shownRows(f)
  local out = {}
  for _, row in ipairs(f.rows) do if row.shown and row.r then out[#out + 1] = row end end
  return out
end
function pick(f, key)
  for _, b in ipairs(f.groups) do if b.key == key then b.scripts.OnClick(b); return b end end
  error("grupo " .. key)
end
function group(f, key) for _, b in ipairs(f.groups) do if b.key == key then return b end end end
function ids(list) local t = {}; for _, r in ipairs(list) do t[#t + 1] = r.parts[1].g.id end; return table.concat(t, ",") end
-- Escolhe o item n do dropdown (moeda, papel).
function choose(dd, n)
  dd.scripts.OnClick(dd)
  local r = dd.menu.rows[n]
  assert(r and r.shown, "item " .. n .. " do menu")
  r.scripts.OnClick(r)
end
