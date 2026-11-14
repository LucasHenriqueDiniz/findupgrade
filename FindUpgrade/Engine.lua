-- FindUpgrade · Engine.lua
-- A conta: o que ele tem equipado, que peça à venda entra em que slot, quanto cada uma ganha e
-- os combos de arma (2 mãos, ou 1 mão + off-hand/escudo/segunda arma). Os filtros (level, preço)
-- entram só em FU.results, então mexer neles na janela não recalcula nada. Ver docs/pontuacao.md.

local _, FU = ...
FU = FU or FindUpgrade

-- O que comparar: no modo "ah", o equipamento à venda (Scan.lua: o do VaultSync ou a varredura
-- própria); no modo "src", recompensa de quest e drop de dungeon (Sources.lua).
-- view: o botão escolhido (ah, quest, dungeon, vendor); mode: a família da lista (ah ou src).
-- Quest, Dungeon e Vendedores dividem a mesma lista e a mesma conta: trocar entre eles é na hora.
FU.VIEWS = { ah = true, quest = true, dungeon = true, vendor = true }
function FU.view()
  local v = FU.db().mode
  return FU.VIEWS[v or ""] and v or "ah"
end
function FU.mode() return FU.view() == "ah" and "ah" or "src" end

function FU.load()
  if FU.mode() == "src" then return FU.src.load() end
  local gear, date = FU.ah.load()
  -- Varredura guardada sem slot/classe (VaultSync v47): completa pelo id, que não pede cache.
  for _, g in ipairs(gear or {}) do
    if not g.loc then
      local _, _, _, loc, _, classID, subID = C_Item.GetItemInfoInstant(g.id)
      g.loc, g.class, g.sub = loc, classID, subID
    end
  end
  return gear, date
end

-- O papel escolhido na janela (FindUpgradeDB.role), se a classe tiver; senão o primeiro dela.
function FU.roleFor(ci)
  local want = FU.db().role
  for _, r in ipairs(ci.roles) do
    if r == want then return r end
  end
  return ci.roles[1]
end

-- O que ele tem: classe, papel e pesos, level, gold e o equipado (stats e nota de cada slot).
function FU.context()
  local _, cls = UnitClass("player")
  local ci = FU.CLASSES[cls or ""] or FU.CLASSES.WARRIOR
  local level = UnitLevel("player") or 1
  local role = FU.roleFor(ci)
  local rs = FU.ROLES[role]
  -- Pesos e ganho mínimo da tela de configurações, por cima dos do papel (peso 0 tira o stat).
  local db = FU.db()
  local w, custom = rs.w, db.weights and db.weights[role]
  if custom and next(custom) then
    w = {}
    for k, v in pairs(rs.w) do w[k] = v end
    for k, v in pairs(custom) do w[k] = (v ~= 0) and v or nil end
  end
  local ctx = { class = cls, ci = ci, level = level, money = GetMoney() or 0, role = role, rs = rs, w = w,
    min = db.minGain or rs.min or 2, tier = (level >= 40 and ci.armor40) or ci.armor, eq = {}, missing = 0, skipped = 0,
    cand = {}, w2h = {}, wmh = {}, woh = {} }
  -- Logo depois do /reload o Forever ainda não tem os dados das peças equipadas: o link vem com
  -- o nome vazio ("[]") e sem stats. Conta como faltando e o compute espera carregar.
  local dump = {}
  for name, slot in pairs(FU.SLOT_IDS) do
    local link = GetInventoryItemLink("player", slot)
    local e = { name = "vazio", score = 0, s = {}, link = link }
    if link then
      local id = (GetInventoryItemID and GetInventoryItemID("player", slot)) or tonumber(link:match("item:(%d+)") or "")
      local s = FU.stats(link, true, slot)
      e.id = id
      e.name = link:match("%[(.-)%]")
      if not e.name or e.name == "" then e.name = id and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) end
      if not s or not e.name or e.name == "" then
        ctx.missing = ctx.missing + 1
        if id and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
      end
      if not e.name or e.name == "" then e.name = "?" end
      e.s = s or {}
      e.score = FU.scoreFor(e.s, ctx, name)
      e.icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
      dump[name] = string.format("%s = %.1f (%s)", e.name, e.score, FU.statText(e.s))
      e.set = select(16, C_Item.GetItemInfo(link))
      if e.set == 0 then e.set = nil end
      if name == "MainHand" then
        local _, _, _, loc = C_Item.GetItemInfoInstant(link)
        ctx.twoHand = loc == "INVTYPE_2HWEAPON"
      end
    end
    ctx.eq[name] = e
  end
  FU.db().eq = dump -- o que a janela achou do equipado (pra conferir no arquivo salvo)
  return ctx
end

-- Os slots onde o item entra, ou nil se a classe não usa.
function FU.slotsFor(g, ctx)
  local slots = FU.EQUIP_LOC[g.loc or ""]
  if not slots then return nil end
  if g.class == 4 then
    if g.sub == 6 then return ctx.ci.shield and slots or nil end -- escudo: warrior, paladino, shaman
    if g.loc == "INVTYPE_HOLDABLE" and not ctx.ci.offhand then return nil end
    if g.sub ~= 0 and g.loc ~= "INVTYPE_CLOAK" and g.sub ~= ctx.tier then return nil end
  elseif g.class == 2 then
    if not ctx.ci.weapons[g.sub] then return nil end
    if g.loc == "INVTYPE_WEAPONOFFHAND" and not ctx.ci.dw then return nil end
  else
    return nil
  end
  return slots
end

-- Arma da mão (staff, arma de 1 mão, off-hand) ou nil. A de distância (wand) é um slot normal.
function FU.weaponKind(g)
  local loc = g.loc
  if loc == "INVTYPE_2HWEAPON" then return "2h" end
  if loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONMAINHAND" then return "mh" end
  if loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_HOLDABLE" or loc == "INVTYPE_SHIELD" then return "oh" end
end

-- Com quem a peça compete: o mais fraco dos slots do grupo (anel e trinket têm 2).
function FU.base(ctx, key)
  local base
  for _, n in ipairs(FU.GROUP_BY[key].slots) do
    local e = ctx.eq[n]
    if not base or e.score < base.score then base = { slot = n, score = e.score, name = e.name, set = e.set } end
  end
  return base
end

-- Uma peça à venda: vira candidata do grupo dela (só se ganha do equipado) ou das armas.
function FU.evaluate(g, ctx, pending)
  local req = g.level or 0
  if not g.link or req > ctx.level + FU.MAXPLUS then return end
  local slots = FU.slotsFor(g, ctx)
  if not slots then return end
  local s = FU.stats(g.link)
  if not s then
    pending[#pending + 1] = g
    return
  end
  -- Item do banco de fontes: nome e qualidade vêm do jogo quando ele carrega.
  if not g.name then
    local name, _, quality = C_Item.GetItemInfo(g.link)
    g.name, g.quality = name, g.quality or quality
  end
  -- Item de dungeon só com o mínimo da dungeon: agora vale o level do item.
  if g.levelGuess then
    local lv = select(5, C_Item.GetItemInfo(g.link))
    if lv then
      g.level, g.levelGuess, req = lv, nil, lv
      if req > ctx.level + FU.MAXPLUS then return end
    end
  end
  local kind = FU.weaponKind(g)
  -- A nota depende da mão: o DPS da arma conta inteiro na principal e metade na off-hand.
  local slot = (kind == "oh" and "OffHand") or (kind and "MainHand") or slots[1]
  local c = { g = g, s = s, score = FU.scoreFor(s, ctx, slot), price = g.price or 0, req = req }
  if not kind then
    local key = FU.GROUP_OF[slots[1]]
    if c.score - FU.base(ctx, key).score < ctx.min then return end
  end
  if FU.blocked(g.link) then
    ctx.skipped = ctx.skipped + 1
    return
  end
  if kind == "2h" then
    ctx.w2h[#ctx.w2h + 1] = c
  elseif kind == "mh" then
    ctx.wmh[#ctx.wmh + 1] = c
    -- Quem luta com duas armas também pode pôr a de 1 mão na off-hand (com a nota da off-hand).
    if ctx.ci.dw and g.loc == "INVTYPE_WEAPON" then
      ctx.woh[#ctx.woh + 1] = { g = g, s = s, score = FU.scoreFor(s, ctx, "OffHand"), price = c.price, req = req }
    end
  elseif kind == "oh" then
    ctx.woh[#ctx.woh + 1] = c
  else
    local key = FU.GROUP_OF[slots[1]]
    local list = ctx.cand[key] or {}
    ctx.cand[key] = list
    list[#list + 1] = c
  end
end

-- Calcula em pedaços (pra não travar o jogo) e chama done(ctx), ou done(nil) sem varredura.
-- Relógio em ms (debugprofilestop no jogo) e o orçamento de cada fatia da conta: passou de
-- BUDGET ms, o resto fica pro próximo frame, então a conta nunca trava o jogo.
local clock = debugprofilestop or function() return os.clock() * 1000 end
local BUDGET = 8

-- Calcula em fatias de até BUDGET ms e chama done(ctx), ou done(nil) sem lista. gen: se outra
-- conta começou depois (FU.gen mudou), esta para no meio e não chama done.
function FU.compute(done, gen)
  local function stale() return gen and gen ~= FU.gen end
  local t0 = clock()
  local list = FU.load()
  if not list then
    done(nil)
    return
  end
  local ctx = FU.context()
  -- Peça equipada sem dados (logo depois do /reload): espera carregar, até ~3s.
  if ctx.missing > 0 and (FU.waitEq or 0) < 6 then
    FU.waitEq = (FU.waitEq or 0) + 1
    C_Timer.After(0.5, function() if not stale() then FU.compute(done, gen) end end)
    return
  end
  FU.waitEq = 0
  local pending, tries = {}, 0
  local maxTries = FU.mode() == "src" and 8 or 3 -- quest e dungeon trazem centenas de itens nunca vistos
  local perf = { mode = FU.view(), items = #list, work = clock() - t0, slices = 1, maxSlice = clock() - t0 }
  local function finish()
    ctx.total, ctx.pending = #list, #pending
    perf.pending, perf.tries = #pending, tries
    FU.perf = perf
    done(ctx)
  end
  -- Avalia a lista em fatias de até BUDGET ms; then() quando acabar.
  local function sliced(items, then_)
    local i = 0
    local function slice()
      if stale() then return end
      local s0 = clock()
      while i < #items do
        i = i + 1
        FU.evaluate(items[i], ctx, pending)
        if clock() - s0 > BUDGET then break end
      end
      local ms = clock() - s0
      perf.work, perf.slices = perf.work + ms, perf.slices + 1
      if ms > perf.maxSlice then perf.maxSlice = ms end
      if i < #items then
        C_Timer.After(0, slice)
      else
        then_()
      end
    end
    slice()
  end
  local function afterPass()
    if #pending > 0 and tries < maxTries then
      C_Timer.After(2, function()
        if stale() then return end
        tries = tries + 1
        local again = pending
        pending = {}
        sliced(again, afterPass)
      end)
    else
      finish()
    end
  end
  sliced(list, afterPass)
end

-- Filtros: level (até o meu + N), preço máximo por peça e, se marcado, o total cabe no gold.
function FU.filters(ctx)
  local db = FU.db()
  if FU.mode() == "src" then
    -- Quest, dungeon e vendedor não têm preço: só level e o tipo de fonte (o botão escolhido).
    return { maxLevel = ctx.level + (db.plus or 0), weaponMode = db.weaponMode, kind = FU.view() }
  end
  return { maxLevel = ctx.level + (db.plus or 0), maxPiece = FU.maxPiece(), money = db.fitGold and ctx.money or nil,
    weaponMode = db.weaponMode }
end

local function pass(c, f)
  if c.kept then return true end
  if c.req > f.maxLevel then return false end
  if f.kind then
    local k = c.g.src and c.g.src.kinds or {}
    -- Vendedores junta vendedor e intendente de reputação.
    if not (k[f.kind] or (f.kind == "vendor" and k.rep)) then return false end
  end
  if f.maxPiece and c.price > f.maxPiece then return false end
  return true
end

local function byScore(a, b) return a.score > b.score end

-- Armas: staff no lugar do que está na mão, e arma de 1 mão + off-hand (as do AH e as que ele
-- já tem). Cada combo soma as duas peças e compara com a mão principal + a secundária de agora.
function FU.weaponRows(ctx, f, rows)
  local eqM, eqO = ctx.eq.MainHand, ctx.eq.OffHand
  local base = eqM.score + (eqO.link and eqO.score or 0)
  local baseName = eqM.link and eqM.name or "mão vazia"
  if eqO.link then baseName = baseName .. " + " .. eqO.name end
  -- O que cada mão já tem (com staff, a mão principal não fica: o combo compara com a staff).
  local haveM = (eqM.link and not ctx.twoHand) and eqM.score or nil
  local haveO = eqO.link and eqO.score or 0
  local function add(parts, kind)
    -- Cada peça comprada tem que valer sozinha contra a que ela tira da mão; senão o combo certo é
    -- comprar só a outra (que aparece com a peça dele marcada "já tem").
    local partGain
    if kind == "pair" then
      local m, o = parts[1], parts[2]
      local mGain = (not m.kept and haveM) and (m.score - haveM) or nil
      local oGain = (o and not o.kept) and (o.score - haveO) or nil
      if (mGain and mGain < ctx.min) or (oGain and oGain < ctx.min) then return end
      partGain = { mGain, oGain }
    end
    local s, score, price, req, bought = {}, 0, 0, 0, 0
    for _, c in ipairs(parts) do
      score = score + c.score
      for k, v in pairs(c.s) do s[k] = (s[k] or 0) + v end
      if not c.kept then
        price, req, bought = price + c.price, math.max(req, c.req), bought + 1
      end
    end
    local gain = score - base
    if bought > 0 and gain >= ctx.min then
      rows[#rows + 1] = { group = "weapon", slot = "MainHand", kind = kind, parts = parts, s = s, gain = gain,
        price = price, req = req, replaces = baseName, partGain = partGain }
    end
  end
  if f.weaponMode ~= "pair" then
    for _, c in ipairs(ctx.w2h) do
      if pass(c, f) then add({ c }, "2h") end
    end
  end
  if f.weaponMode == "2h" then return end
  local function kept(e)
    return { kept = true, score = e.score, s = e.s, price = 0, req = 0, g = { id = e.id, name = e.name, link = e.link } }
  end
  local mhs, ohs = {}, { false }
  if eqM.link and not ctx.twoHand then mhs[1] = kept(eqM) end
  if eqO.link then ohs[2] = kept(eqO) end
  local function top(list, into)
    local tmp = {}
    for _, c in ipairs(list) do
      if pass(c, f) then tmp[#tmp + 1] = c end
    end
    table.sort(tmp, byScore)
    for k = 1, math.min(#tmp, 12) do into[#into + 1] = tmp[k] end
  end
  top(ctx.wmh, mhs)
  top(ctx.woh, ohs)
  for _, m in ipairs(mhs) do
    for _, o in ipairs(ohs) do
      if not o then
        add({ m }, "pair")
      elseif o.g ~= m.g or (m.g.n or 1) > 1 then
        add({ m, o }, "pair")
      end
    end
  end
end

local function byGain(a, b)
  if a.gain ~= b.gain then return a.gain > b.gain end
  return a.price < b.price
end

-- As opções de cada grupo, já filtradas e da maior pro menor ganho.
function FU.results(ctx, f)
  local out = {}
  for _, gr in ipairs(FU.GROUPS) do
    local rows = {}
    if gr.key == "weapon" then
      FU.weaponRows(ctx, f, rows)
    else
      local base = FU.base(ctx, gr.key)
      for _, c in ipairs(ctx.cand[gr.key] or {}) do
        if pass(c, f) then
          rows[#rows + 1] = { group = gr.key, slot = base.slot, parts = { c }, s = c.s, gain = c.score - base.score,
            price = c.price, req = c.req, replaces = base.name, breaksSet = base.set ~= nil }
        end
      end
    end
    local kept = {}
    if f.money then
      for _, r in ipairs(rows) do
        if r.price <= f.money then kept[#kept + 1] = r end
      end
    else
      kept = rows
    end
    table.sort(kept, byGain)
    if gr.key == "weapon" then
      -- A mesma arma comprada aparece no máximo PER_ITEM vezes (com off-hands diferentes).
      local seen, cut = {}, {}
      for _, r in ipairs(kept) do
        local g = (r.parts[1].kept and r.parts[2] or r.parts[1]).g
        seen[g] = (seen[g] or 0) + 1
        if seen[g] <= FU.PER_ITEM then cut[#cut + 1] = r end
      end
      kept = cut
    end
    out[gr.key] = kept
  end
  return out
end

-- "Tudo": o melhor de cada grupo, e quanto dá comprando tudo.
function FU.overview(res)
  local rows, gain, price = {}, 0, 0
  for _, gr in ipairs(FU.GROUPS) do
    local r = res[gr.key] and res[gr.key][1]
    if r then
      rows[#rows + 1] = r
      gain, price = gain + r.gain, price + r.price
    end
  end
  table.sort(rows, byGain)
  return rows, gain, price
end
