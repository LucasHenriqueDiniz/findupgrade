-- FindUpgrade · Scan.lua
-- O equipamento à venda no AH. Duas fontes, com a mesma cara pro resto do addon (FU.ah):
--  · "vaultsync": se o addon VaultSync estiver ligado, usa a varredura dele (VaultSyncAPI) e não
--    varre de novo. É o caso do Lucas.
--  · "proprio": sem o VaultSync, varre sozinho com C_AuctionHouse.ReplicateItems (o AH inteiro de
--    uma vez; a Blizzard libera uma a cada 15 min) e guarda em FindUpgradeAH, por reino e facção.
-- Ver docs/arquitetura.md.

local _, FU = ...
FU = FU or FindUpgrade

local ah = { listeners = {} }
FU.ah = ah

local WAIT_EVERY = 15 * 60 -- a Blizzard libera uma varredura a cada 15 min
local SERVER_WAIT = 180 -- o AH inteiro (140 mil anúncios) leva de 30s a 2 min pra chegar
local CHUNK = 4000 -- anúncios lidos por frame
local KEEP_DAYS = 14 -- reino sem varredura há mais tempo sai do arquivo

local function bridge()
  local api = VaultSyncAPI
  if api and api.loadGear and api.startScan and api.ahOpen then return api end
end
ah.mode = bridge() and "vaultsync" or "proprio"

local function notify(gear)
  for _, fn in ipairs(ah.listeners) do pcall(fn, gear) end
end

if ah.mode == "vaultsync" then
  local api = bridge()
  table.insert(api.listeners, function(gear) notify(gear) end)
  function ah.isOpen() return api.ahOpen() end
  function ah.scanning() return api.scanning() end
  function ah.wait() return api.scanWait() end
  function ah.start(after) api.startScan(after) end
  function ah.load() return api.loadGear() end
  function ah.at() return api.scanAt() end
  function ah.status() return nil end
  return
end

-- Varredura própria ------------------------------------------------------------

local open, scan = false, nil

local function realmKey()
  return (GetRealmName and GetRealmName() or "?") .. " - " .. (UnitFactionGroup and UnitFactionGroup("player") or "?")
end

local function store()
  FindUpgradeAH = FindUpgradeAH or {}
  local key = realmKey()
  local R = FindUpgradeAH[key]
  if not R then
    R = { realm = key }
    FindUpgradeAH[key] = R
  end
  return R
end

-- Equipamento numa string: link, preço, anúncios, level, slot, classe, subclasse e qualidade,
-- separados por tab, um item por linha (mesmo formato do VaultSync). Ocupa bem menos que tabela
-- nas SavedVariables.
local function pack(gear)
  local lines = {}
  for i, g in ipairs(gear) do
    lines[i] = table.concat({ g.link or "", g.price or 0, g.n or 1, g.level or 0, g.loc or "", g.class or "",
      g.sub or "", g.quality or "" }, "\t")
  end
  return table.concat(lines, "\n")
end

local HEX_QUALITY = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5 }

local function unpackGear(text)
  local gear = {}
  for line in text:gmatch("[^\n]+") do
    local link, price, n, level, loc, class, sub, q = strsplit("\t", line)
    local id = link and tonumber(link:match("item:(%d+)") or "")
    if id then
      gear[#gear + 1] = { id = id, link = link, name = link:match("%[(.-)%]"), price = tonumber(price) or 0,
        n = tonumber(n) or 1, level = tonumber(level) or 0, loc = (loc ~= "" and loc) or nil, class = tonumber(class),
        sub = tonumber(sub), quality = tonumber(q) or HEX_QUALITY[(link:match("|c%x%x(%x%x%x%x%x%x)") or ""):lower()] }
    end
  end
  return gear
end

-- Mesmo item com o mesmo sufixo/bônus vira uma chave só (o link muda por anúncio).
local function linkKey(link, itemID)
  local body = link and link:match("item:([%-%d:]+)")
  if not body then return tostring(itemID) end
  local f = { strsplit(":", body) }
  local key = (f[1] or tostring(itemID)) .. ":" .. (f[7] or "")
  local n = tonumber(f[13] or "") or 0
  for i = 14, 13 + n do key = key .. ":" .. (f[i] or "") end
  return key
end

-- Só guarda o que a classe usa (menos coisa no arquivo e menos item pra carregar).
local function usable(ci, classID, sub, loc)
  if classID == 2 then return ci.weapons[sub] == true end
  if classID ~= 4 then return false end
  if sub == 6 then return ci.shield == true end
  return sub == 0 or loc == "INVTYPE_CLOAK" or sub == ci.armor or sub == ci.armor40
end

local function newRead()
  local _, cls = UnitClass("player")
  return { i = 0, n = C_AuctionHouse.GetNumReplicateItems() or 0, byKey = {}, gear = {}, missing = 0, requested = {},
    ci = FU.CLASSES[cls or ""] or FU.CLASSES.WARRIOR }
end

-- Lê um pedaço dos anúncios; devolve true quando acabou.
local function readChunk(st)
  local last = math.min(st.n - 1, st.i + CHUNK - 1)
  for i = st.i, last do
    local name, _, count, quality, _, level, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
    if itemID and buyout and buyout > 0 then
      local _, _, _, loc, _, classID, sub = C_Item.GetItemInfoInstant(itemID)
      if loc and loc ~= "" and FU.EQUIP_LOC[loc] and usable(st.ci, classID, sub, loc) then
        local link = C_AuctionHouse.GetReplicateItemLink(i)
        if not link then
          st.missing = st.missing + 1
          if not st.requested[itemID] and C_Item.RequestLoadItemDataByID then
            st.requested[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
          end
        else
          local key = linkKey(link, itemID)
          local unit = math.floor(buyout / math.max(count or 1, 1))
          local g = st.byKey[key]
          if g then
            g.n = g.n + 1
            if unit < g.price then g.price = unit end
          else
            g = { id = itemID, link = link, name = name, quality = quality, level = level, loc = loc, class = classID,
              sub = sub, price = unit, n = 1 }
            st.byKey[key] = g
            st.gear[#st.gear + 1] = g
          end
        end
      end
    end
  end
  st.i = last + 1
  return st.i >= st.n
end

local function progress(text)
  ah.progressText = text
  if FU.onScanProgress then pcall(FU.onScanProgress) end
end

local function finish()
  if not scan then return end
  scan.read = scan.read or newRead()
  local st = scan.read
  local ok, done = pcall(readChunk, st)
  if not ok then
    FU.say("erro lendo o AH: " .. tostring(done))
    scan = nil
    progress(nil)
    return
  end
  progress(string.format("Lendo o AH: %d de %d anúncios", st.i, st.n))
  if not done then
    C_Timer.After(0, finish)
    return
  end
  scan.read = nil
  -- Item sem dados ainda não tem link: pede os dados e lê de novo (até 4 vezes).
  if st.missing > 0 and scan.tries < 4 and open then
    scan.tries = scan.tries + 1
    progress(string.format("Carregando dados de %d itens (%d/4)...", st.missing, scan.tries))
    C_Timer.After(3, finish)
    return
  end
  local R = store()
  R.at, R.date, R.total, R.missing, R.gear = time(), date("%Y-%m-%d %H:%M:%S"), st.n, st.missing, pack(st.gear)
  ah.gear, ah.gearDate = st.gear, R.date
  local after = scan.after
  scan = nil
  progress(nil)
  FU.say(string.format("AH lido: %d anúncios, %d peças que tua classe usa%s.", st.n, #st.gear,
    st.missing > 0 and (" (" .. st.missing .. " ficaram sem dados)") or ""))
  notify(st.gear)
  if after then pcall(after) end
end

function ah.isOpen() return open end
function ah.scanning() return scan ~= nil end
function ah.wait() return math.max(0, (store().at or 0) + WAIT_EVERY - time()) end
function ah.status() return ah.progressText end

function ah.at()
  local R = store()
  return R.at, R.date
end

function ah.load()
  if ah.gear then return ah.gear, ah.gearDate end
  local R = store()
  if type(R.gear) ~= "string" then return nil end
  ah.gear, ah.gearDate = unpackGear(R.gear), R.date
  return ah.gear, ah.gearDate
end

-- after: o que rodar quando terminar (a janela se redesenha).
function ah.start(after)
  if not (C_AuctionHouse and C_AuctionHouse.ReplicateItems) then
    FU.say("este cliente não tem a varredura completa do AH.")
    return
  end
  if not open then
    FU.say("abre o leiloeiro primeiro.")
    return
  end
  local wait = ah.wait()
  if wait > 0 then
    FU.say(string.format("a Blizzard só libera uma varredura a cada 15 min. Falta %d min.", math.ceil(wait / 60)))
    return
  end
  if scan then
    FU.say("já estou lendo o AH, espera terminar.")
    return
  end
  scan = { tries = 0, after = after }
  C_AuctionHouse.ReplicateItems()
  progress("Pedindo o AH inteiro ao servidor (leva 1 a 2 min)...")
  C_Timer.After(SERVER_WAIT, function()
    if scan and not scan.waiting then
      scan = nil
      progress(nil)
      FU.say("o AH não mandou nada em 3 min. Tenta de novo daqui a pouco.")
      if after then pcall(after) end
    end
  end)
end

-- Reino sem varredura há KEEP_DAYS dias sai (o arquivo é carregado por todo personagem).
local function prune()
  local old = time() - KEEP_DAYS * 86400
  for key, R in pairs(FindUpgradeAH or {}) do
    if type(R) ~= "table" or (R.at or 0) < old then FindUpgradeAH[key] = nil end
  end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    pcall(prune)
  elseif event == "AUCTION_HOUSE_SHOW" then
    open = true
  elseif event == "AUCTION_HOUSE_CLOSED" then
    open = false
  elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
    -- Varredura nossa ou de outro addon (Auctionator): lê um pouco depois, quando os dados
    -- assentam. O evento volta a cada lote de item carregado: fora de uma varredura nossa, só
    -- conta se a última leitura foi há mais de 15 min, senão vira loop.
    if not scan and ah.wait() > 0 then return end
    scan = scan or { tries = 0 }
    if not scan.waiting then
      scan.waiting = true
      C_Timer.After(1, finish)
    end
  end
end)
for _, e in ipairs({ "PLAYER_LOGIN", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "REPLICATE_ITEM_LIST_UPDATE" }) do
  pcall(ev.RegisterEvent, ev, e)
end
