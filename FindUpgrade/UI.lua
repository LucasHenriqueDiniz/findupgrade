-- FindUpgrade · UI.lua
-- A janela. Em cima, o papel (cura, DPS, tank...) e os filtros: level (só o meu, +3, +5, +10),
-- preço máximo por peça (com a moeda num dropdown) e "só o que cabe no meu gold". Na esquerda,
-- os slots com o melhor ganho de cada um ("Tudo" mostra o melhor de cada slot e o total). Na
-- direita, as opções do slot escolhido. Em Armas: 2 mãos, 1 mão + secundária, ou tudo junto.
--
-- Visual: com o EllesmereUI, a API de skin dele (EllesmereUI.RegisterSkin); com o ElvUI, as
-- funções do módulo Skins; sem nenhum, um escuro liso parecido. Ver docs/arquitetura.md.

local ADDON, FU = ...
FU = FU or FindUpgrade
ADDON = ADDON or "FindUpgrade"

local W, H = 800, 524
local LEFT_W = 188
local LIST_X = LEFT_W + 14
local LIST_W = W - LIST_X - 12
local NROWS = 14
local ROW_H = 22
local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_01"
local skin -- as primitivas do EllesmereUI (S), quando ele pinta a gente

FU.offset = 0

local say = FU.say

local function S(fn, ...)
  if skin and skin[fn] then pcall(skin[fn], ...) end
end

local function accent()
  if skin and skin.GetAccentColor then
    local ok, r, g, b = pcall(skin.GetAccentColor)
    if ok and r then return r, g, b end
  end
  return 0.35, 0.75, 1
end

local function text(parent, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  S("Font", fs)
  return fs
end

local function flat(frame, r, g, b, a, layer)
  local t = frame:CreateTexture(nil, layer or "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(r, g, b, a)
  return t
end

local itemIcon = FU.itemIcon

local function emptySlotIcon(inv)
  if not (inv and GetInventorySlotInfo) then return 134400 end
  local ok, _, tex = pcall(GetInventorySlotInfo, inv)
  return ok and tex or 134400
end

local function hideTip() if GameTooltip then GameTooltip:Hide() end end

local tip -- (abaixo; o Config.lua usa pelo FU.ui)
function tip(owner, lines)
  if not GameTooltip then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  for i, l in ipairs(lines) do
    if i == 1 then GameTooltip:SetText(l, 1, 1, 1) else GameTooltip:AddLine(l, 0.8, 0.8, 0.8, true) end
  end
  GameTooltip:Show()
end

-- O Config.lua desenha com as mesmas ajudas (e o mesmo skin).
FU.ui = { text = text, flat = flat, tip = function(...) return tip(...) end, hideTip = hideTip,
  skin = function(fn, ...) S(fn, ...) end, accent = function() return accent() end }

-- Staff, ou "2 mãos" pra quem usa machado/espada/maça de 2 mãos.
local function twoHandLabel(ci)
  if ci and ci.weapons[10] and not (ci.weapons[1] or ci.weapons[5] or ci.weapons[6] or ci.weapons[8]) then
    return "Staff"
  end
  return "2 mãos"
end

local function groupLabel(key, ctx, r)
  if key == "Ranged" and ctx and ctx.ci.weapons[19] then return "Wand" end
  if key == "weapon" and r then
    if r.kind == "2h" then return twoHandLabel(ctx and ctx.ci) end
    return #r.parts > 1 and "Arma+OH" or "Arma"
  end
  return FU.GROUP_BY[key] and FU.GROUP_BY[key].label or key
end

-- "2026-11-13 21:40:00" → "13/11 21:40 (há 2h)"
local function scanWhen()
  local at, when = FU.ah.at()
  if not when then return "?" end
  local _, mo, d, hh, mi = when:match("(%d+)-(%d+)-(%d+) (%d+):(%d+)")
  local out = d and (d .. "/" .. mo .. " " .. hh .. ":" .. mi) or when
  local age = at and (time() - at)
  if age and age >= 0 then
    if age < 3600 then
      out = out .. string.format(" (há %d min)", math.floor(age / 60))
    elseif age < 48 * 3600 then
      out = out .. string.format(" (há %dh)", math.floor(age / 3600))
    else
      out = out .. string.format(" |cffff8040(há %d dias)|r", math.floor(age / 86400))
    end
  end
  return out
end

-- Botão com menu (moeda, papel): mostra a escolha atual; o clique abre a lista e escolher fecha.
-- Feito à mão em vez do UIDropDownMenu da Blizzard, que muda entre clientes e espalha taint.
local openMenu
local function dropdown(parent, width, menuWidth, getItems, onPick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 20)
  b.bg = flat(b, 1, 1, 1, 0.06)
  flat(b, 1, 1, 1, 0.08, "HIGHLIGHT")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(14, 14)
  b.icon:SetPoint("LEFT", 4, 0)
  b.label = text(b)
  b.label:SetPoint("LEFT", 6, 0)
  b.label:SetJustifyH("LEFT")
  b.arrow = b:CreateTexture(nil, "ARTWORK")
  b.arrow:SetSize(12, 12)
  b.arrow:SetPoint("RIGHT", -3, 0)
  b.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
  local menu = CreateFrame("Frame", nil, b)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
  menu:EnableMouse(true)
  menu:Hide()
  flat(menu, 0.07, 0.07, 0.09, 0.98)
  menu.rows = {}
  b.menu = menu
  b:SetScript("OnClick", function()
    if menu:IsShown() then
      menu:Hide()
      return
    end
    if openMenu and openMenu ~= menu then openMenu:Hide() end
    local items = getItems()
    for i, it in ipairs(items) do
      local r = menu.rows[i]
      if not r then
        r = CreateFrame("Button", nil, menu)
        flat(r, 1, 1, 1, 0.1, "HIGHLIGHT")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(14, 14)
        r.icon:SetPoint("LEFT", 4, 0)
        r.label = text(r)
        r.label:SetPoint("LEFT", 22, 0)
        menu.rows[i] = r
      end
      r:SetSize(menuWidth - 4, 20)
      r:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 20)
      r.icon:SetShown(it.icon ~= nil)
      if it.icon then r.icon:SetTexture(it.icon) end
      r.label:SetText((it.selected and "|cff40ff40" or "") .. it.label .. (it.selected and "|r" or ""))
      r:SetScript("OnClick", function()
        menu:Hide()
        onPick(it.value)
      end)
      r:Show()
    end
    for i = #items + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(menuWidth, #items * 20 + 4)
    menu:Show()
    openMenu = menu
  end)
  -- O que aparece no botão: texto e/ou ícone.
  function b.Set(label, icon)
    b.icon:SetShown(icon ~= nil)
    if icon then b.icon:SetTexture(icon) end
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", icon and 20 or 6, 0)
    b.label:SetText(label or "")
  end
  return b
end

-- Botões lado a lado, um escolhido (fundo mais claro e a linha do accent embaixo).
local function segmented(parent, items, onPick)
  local seg = { buttons = {} }
  local prev
  for i, it in ipairs(items) do
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(it.w, 20)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) end
    b.bg = flat(b, 1, 1, 1, 0.05)
    b.hl = flat(b, 1, 1, 1, 0.08, "HIGHLIGHT")
    b.sel = b:CreateTexture(nil, "ARTWORK")
    b.sel:SetPoint("BOTTOMLEFT")
    b.sel:SetPoint("BOTTOMRIGHT")
    b.sel:SetHeight(2)
    b.label = text(b)
    b.label:SetPoint("CENTER")
    b.label:SetText(it.label)
    b.value = it.value
    b:SetScript("OnClick", function() onPick(it.value) end)
    if it.tip then
      b:SetScript("OnEnter", function(self) tip(self, it.tip) end)
      b:SetScript("OnLeave", hideTip)
    end
    seg.buttons[i] = b
    prev = b
  end
  function seg.Select(value)
    local r, g, bl = accent()
    for _, b in ipairs(seg.buttons) do
      local on = b.value == value
      b.bg:SetColorTexture(1, 1, 1, on and 0.14 or 0.05)
      b.sel:SetColorTexture(r, g, bl, 1)
      b.sel:SetShown(on)
      if on then b.label:SetTextColor(1, 1, 1) else b.label:SetTextColor(0.65, 0.65, 0.65) end
    end
  end
  function seg.SetShown(on)
    for _, b in ipairs(seg.buttons) do b:SetShown(on) end
  end
  return seg
end

local function scroll(delta)
  FU.offset = math.max(0, FU.offset - delta * 3)
  FU.draw()
end

function FU.build()
  local db = FU.db()
  local f = CreateFrame("Frame", "FindUpgradeFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(W, H)
  if db.pos then
    f:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
  else
    f:SetPoint("CENTER", -180, 30)
  end
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    if p then FU.db().pos = { p, rp, x, y } end
  end)
  if UISpecialFrames then table.insert(UISpecialFrames, "FindUpgradeFrame") end
  -- Fundo próprio (o Shell do EllesmereUI apaga e pinta o dele por cima).
  flat(f, 0.055, 0.055, 0.07, 0.97)
  local top = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(28)
  top:SetColorTexture(0.1, 0.1, 0.125, 1)
  if f.SetBackdrop then
    pcall(f.SetBackdrop, f, { edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    pcall(f.SetBackdropBorderColor, f, 0, 0, 0, 1)
  end

  -- Tudo o que não é fundo fica num filho (o Shell só apaga a arte do próprio frame).
  local body = CreateFrame("Frame", nil, f)
  body:SetAllPoints()
  f.body = body
  f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.close:SetPoint("TOPRIGHT", 2, 2)
  f.title = text(body, "GameFontNormal")
  f.title:SetPoint("TOPLEFT", 12, -8)
  f.title:SetText("Upgrades")
  -- Leilão é uma conta; Quests, Dungeons e Vendedores dividem outra (o banco de fontes). Trocar de
  -- botão usa a conta guardada: só recalcula o que mudou (peça, level, papel, pesos, varredura).
  f.modeSeg = segmented(body, {
    { value = "ah", label = "Leilão", w = 60, tip = { "Leilão", "O que está à venda no AH agora." } },
    { value = "quest", label = "Quests", w = 58, tip = { "Quests", "Recompensa de quest. As que tu já fez e as da outra facção somem." } },
    { value = "dungeon", label = "Dungeons", w = 70, tip = { "Dungeons", "Drop de dungeon, com o boss e a % de drop quando o banco tem." } },
    { value = "vendor", label = "Vendedores", w = 78, tip = { "Vendedores", "Vendedor e intendente de reputação da tua facção." } },
  }, function(v)
    FU.db().mode = v
    FU.offset = 0
    FU.show()
  end)
  f.modeSeg.buttons[1]:SetPoint("LEFT", f.title, "RIGHT", 12, 0)
  f.role = dropdown(body, 128, 150, function()
    local ctx, out = FU.ctx, {}
    local _, cls = UnitClass("player")
    local ci = (ctx and ctx.ci) or FU.CLASSES[cls or ""] or FU.CLASSES.WARRIOR
    local cur = FU.roleFor(ci)
    for _, r in ipairs(ci.roles) do out[#out + 1] = { value = r, label = FU.ROLES[r].label, selected = r == cur } end
    return out
  end, function(v)
    FU.db().role = v
    FU.offset = 0
    FU.invalidate()
    FU.show() -- pesos novos: recalcula tudo
  end)
  f.role:SetPoint("TOPRIGHT", body, "TOPRIGHT", -34, -5)
  f.role:SetScript("OnEnter", function(self)
    tip(self, { "Papel", "Muda os pesos de cada stat: cura, dano mágico, DPS de força ou agilidade, tank.",
      "Fica salvo neste personagem." })
  end)
  f.role:SetScript("OnLeave", hideTip)
  local roleLabel = text(body, "GameFontDisableSmall")
  roleLabel:SetPoint("RIGHT", f.role, "LEFT", -6, 0)
  roleLabel:SetText("Papel:")
  -- Engrenagem: a tela de configurações (Config.lua).
  local gear = CreateFrame("Button", nil, body)
  gear:SetSize(20, 20)
  gear:SetPoint("RIGHT", roleLabel, "LEFT", -12, 0)
  gear.icon = gear:CreateTexture(nil, "ARTWORK")
  gear.icon:SetAllPoints()
  gear.icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  flat(gear, 1, 1, 1, 0.15, "HIGHLIGHT")
  S("SquareIcon", gear.icon, gear)
  gear:SetScript("OnClick", function() FU.cfg.toggle() end)
  gear:SetScript("OnEnter", function(self)
    tip(self, { "Configurações", "Dica no tooltip, botões, varredura, ganho mínimo e os pesos de cada stat." })
  end)
  gear:SetScript("OnLeave", hideTip)
  f.gear = gear
  f.info = text(body, "GameFontDisableSmall")
  f.info:SetPoint("TOPLEFT", 12, -34)
  f.info:SetWidth(W - 24)
  f.info:SetJustifyH("LEFT")
  f.info:SetWordWrap(false)

  -- Filtros ----------------------------------------------------------------
  local lvl = text(body)
  lvl:SetPoint("TOPLEFT", 12, -58)
  lvl:SetText("Level:")
  f.levelSeg = segmented(body, {
    { value = 0, label = "Meu lvl", w = 78, tip = { "Só o que eu já uso", "Peças que pedem até o teu level." } },
    { value = 3, label = "+3", w = 36, tip = { "Até 3 levels a mais", "Pra comprar agora e pôr já já." } },
    { value = 5, label = "+5", w = 36, tip = { "Até 5 levels a mais" } },
    { value = 10, label = "+10", w = 40, tip = { "Até 10 levels a mais" } },
  }, function(v)
    FU.db().plus = v
    FU.offset = 0
    FU.refresh()
  end)
  f.levelSeg.buttons[1]:SetPoint("LEFT", lvl, "RIGHT", 8, 0)

  local maxLabel = text(body)
  maxLabel:SetPoint("LEFT", f.levelSeg.buttons[4], "RIGHT", 22, 0)
  maxLabel:SetText("Máx. por peça:")
  local eb = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
  eb:SetSize(60, 20)
  eb:SetPoint("LEFT", maxLabel, "RIGHT", 10, 0)
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(10)
  eb:SetText(FU.numberText(db.maxValue))
  local function applyMax(self)
    FU.db().maxValue = FU.parseNumber(self:GetText())
    FU.offset = 0
    FU.refresh()
  end
  eb:SetScript("OnTextChanged", function(self, user) if user then applyMax(self) end end)
  eb:SetScript("OnEnterPressed", function(self)
    applyMax(self)
    self:SetText(FU.numberText(FU.db().maxValue))
    self:ClearFocus()
  end)
  eb:SetScript("OnEscapePressed", function(self)
    self:SetText(FU.numberText(FU.db().maxValue))
    self:ClearFocus()
  end)
  eb:SetScript("OnEditFocusLost", function(self) self:SetText(FU.numberText(FU.db().maxValue)) end)
  eb:SetScript("OnEnter", function(self)
    tip(self, { "Preço máximo por peça", "O número aqui, na moeda do botão ao lado (ouro, prata ou cobre). Vazio: sem limite.",
      "No combo de arma vale pra cada peça." })
  end)
  eb:SetScript("OnLeave", hideTip)
  f.maxBox = eb
  f.unit = dropdown(body, 34, 100, function()
    local out, cur = {}, FU.db().maxUnit
    for _, u in ipairs(FU.UNITS) do out[#out + 1] = { value = u.key, label = u.label, icon = u.icon, selected = u.key == cur } end
    return out
  end, function(v)
    FU.db().maxUnit = v
    FU.offset = 0
    FU.refresh()
  end)
  f.unit:SetPoint("LEFT", eb, "RIGHT", 4, 0)
  f.unit:SetScript("OnEnter", function(self) tip(self, { "Moeda do preço máximo", "Ouro, prata ou cobre." }) end)
  f.unit:SetScript("OnLeave", hideTip)
  local gLabel = f.unit

  local cb = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  cb:SetPoint("LEFT", gLabel, "RIGHT", 22, 0)
  cb:SetScript("OnClick", function(self)
    local d = FU.db()
    d.fitGold = not d.fitGold
    self:SetChecked(d.fitGold)
    FU.offset = 0
    FU.refresh()
  end)
  f.fitGold = cb
  local cbLabel = text(body)
  cbLabel:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  cbLabel:SetText("Só o que cabe no meu gold")
  f.priceBits = { maxLabel, eb, f.unit, cb, cbLabel }

  local line = body:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 10, -80)
  line:SetPoint("TOPRIGHT", -10, -80)
  line:SetHeight(1)
  line:SetColorTexture(1, 1, 1, 0.08)

  -- Slots (esquerda) ----------------------------------------------------------
  f.groups = {}
  local keys = { { key = "all", label = "Tudo" } }
  for _, gr in ipairs(FU.GROUPS) do keys[#keys + 1] = gr end
  for i, gr in ipairs(keys) do
    local b = CreateFrame("Button", nil, body)
    b:SetSize(LEFT_W - 6, 24)
    b:SetPoint("TOPLEFT", 10, -88 - (i - 1) * 25)
    b.bg = flat(b, 1, 1, 1, 0)
    b.hl = flat(b, 1, 1, 1, 0.06, "HIGHLIGHT")
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetPoint("TOPLEFT")
    b.bar:SetPoint("BOTTOMLEFT")
    b.bar:SetWidth(2)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("LEFT", 8, 0)
    b.icon:SetTexture(gr.key == "all" and COIN_ICON or emptySlotIcon(gr.inv))
    b.label = text(b)
    b.label:SetPoint("LEFT", 32, 0)
    b.label:SetText(gr.label)
    b.gain = text(b)
    b.gain:SetPoint("RIGHT", -6, 0)
    b.key, b.inv = gr.key, gr.inv
    b:SetScript("OnClick", function()
      FU.db().group = gr.key
      FU.offset = 0
      FU.draw()
    end)
    f.groups[i] = b
  end
  local vline = body:CreateTexture(nil, "ARTWORK")
  vline:SetPoint("TOPLEFT", LEFT_W + 6, -86)
  vline:SetPoint("BOTTOMLEFT", LEFT_W + 6, 44)
  vline:SetWidth(1)
  vline:SetColorTexture(1, 1, 1, 0.08)

  -- Lista (direita) -------------------------------------------------------------
  f.subIcon = body:CreateTexture(nil, "ARTWORK")
  f.subIcon:SetSize(18, 18)
  f.subIcon:SetPoint("TOPLEFT", LIST_X, -90)
  f.sub = text(body, "GameFontHighlight")
  f.sub:SetPoint("LEFT", f.subIcon, "RIGHT", 6, 0)
  f.sub:SetJustifyH("LEFT")
  f.sub:SetWordWrap(false)
  f.weaponSeg = segmented(body, {
    { value = "all", label = "Tudo", w = 50 },
    { value = "2h", label = "Staff", w = 64, tip = { "Só arma de 2 mãos", "No lugar da arma e da off-hand de agora." } },
    { value = "pair", label = "Arma + secundária", w = 124,
      tip = { "Arma de 1 mão + off-hand", "As do AH e as que você já tem, somadas. Um combo pode trocar só uma das peças." } },
  }, function(v)
    FU.db().weaponMode = v
    FU.offset = 0
    FU.refresh()
  end)
  f.weaponSeg.buttons[1]:SetPoint("TOPRIGHT", body, "TOPRIGHT", -12 - 64 - 124 - 4, -89)

  local function header(label, x, width, justify)
    local h = text(body, "GameFontDisableSmall")
    h:SetPoint("TOPLEFT", LIST_X + x, -118)
    h:SetWidth(width)
    h:SetJustifyH(justify or "LEFT")
    h:SetText(label)
    return h
  end
  header("Item", 0, 120)
  header("Stats", 300, 140)
  header("Preço", LIST_W - 84, 84, "RIGHT")
  local gainHdr = CreateFrame("Button", nil, body)
  gainHdr:SetSize(52, 14)
  gainHdr:SetPoint("TOPLEFT", LIST_X + 444, -117)
  gainHdr.label = text(gainHdr, "GameFontDisableSmall")
  gainHdr.label:SetAllPoints()
  gainHdr.label:SetJustifyH("RIGHT")
  gainHdr.label:SetText("Ganho")
  gainHdr:SetScript("OnEnter", function(self)
    local ctx = FU.ctx
    tip(self, { "Ganho em pontos", ctx and ("Pesos (" .. ctx.rs.label .. "): " .. FU.weightText(ctx.w)) or "",
      "É a soma dos stats da peça vezes o peso, menos a do que está equipado." })
  end)
  gainHdr:SetScript("OnLeave", hideTip)

  local list = CreateFrame("Frame", nil, body)
  list:SetPoint("TOPLEFT", LIST_X, -134)
  list:SetSize(LIST_W, NROWS * ROW_H)
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(_, delta) scroll(delta) end)
  f.list = list
  f.rows = {}
  for i = 1, NROWS do
    local row = CreateFrame("Button", nil, list)
    row:SetSize(LIST_W, ROW_H - 2)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) scroll(delta) end)
    flat(row, 1, 1, 1, i % 2 == 0 and 0.03 or 0)
    flat(row, 1, 1, 1, 0.08, "HIGHLIGHT")
    row.slot = text(row, "GameFontDisableSmall")
    row.slot:SetPoint("LEFT", 4, 0)
    row.slot:SetWidth(56)
    row.slot:SetJustifyH("LEFT")
    row.icons = {}
    for k = 1, 2 do
      local ib = CreateFrame("Button", nil, row)
      ib:SetSize(20, 20)
      ib.tex = ib:CreateTexture(nil, "ARTWORK")
      ib.tex:SetAllPoints()
      ib.part = k
      ib:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      ib:SetScript("OnClick", function(self, button) FU.clickPart(row.r, self.part, button) end)
      ib:SetScript("OnEnter", function(self) FU.tipPart(self, row.r, self.part) end)
      ib:SetScript("OnLeave", hideTip)
      S("SquareIcon", ib.tex, ib)
      row.icons[k] = ib
    end
    row.name = text(row)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.stats = text(row)
    row.stats:SetPoint("LEFT", 300, 0)
    row.stats:SetWidth(140)
    row.stats:SetJustifyH("LEFT")
    row.stats:SetWordWrap(false)
    row.gain = text(row)
    row.gain:SetPoint("LEFT", 444, 0)
    row.gain:SetWidth(52)
    row.gain:SetJustifyH("RIGHT")
    row.price = text(row)
    row.price:SetPoint("RIGHT", -4, 0)
    row.price:SetJustifyH("RIGHT")
    row:SetScript("OnClick", function(self, button) FU.click(self.r, button) end)
    row:SetScript("OnEnter", function(self) FU.tipRow(self, self.r) end)
    row:SetScript("OnLeave", hideTip)
    f.rows[i] = row
  end
  f.empty = text(body, "GameFontDisable")
  f.empty:SetPoint("TOP", list, "TOP", 0, -40)
  f.empty:SetWidth(LIST_W - 40)
  f.scrollText = text(body, "GameFontDisableSmall")
  f.scrollText:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -4)

  -- Rodapé ------------------------------------------------------------------
  f.rescan = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
  f.rescan:SetSize(110, 22)
  f.rescan:SetPoint("BOTTOMLEFT", 12, 12)
  f.rescan:SetText("Varrer o AH")
  f.rescan:SetScript("OnClick", function() FU.rescan() end)
  f.status = text(body)
  f.status:SetPoint("LEFT", f.rescan, "RIGHT", 10, 0)
  f.hint = text(body, "GameFontDisableSmall")
  f.hint:SetPoint("BOTTOMRIGHT", -14, 18)
  f.hint:SetText("Clique: busca no AH · Shift-clique: link no chat · roda do mouse: rola")

  FU.applySkin(f)
  return f
end

-- ElvUI: as mesmas primitivas, feitas com o módulo Skins dele (só se o EllesmereUI não pintou).
local function elvSkin()
  if type(ElvUI) ~= "table" then return nil end
  local ok, E = pcall(function() return unpack(ElvUI) end)
  if not (ok and type(E) == "table" and E.GetModule) then return nil end
  local okS, Sk = pcall(E.GetModule, E, "Skins")
  if not (okS and type(Sk) == "table") then return nil end
  local function call(name) return function(frame) if Sk[name] then Sk[name](Sk, frame) end end end
  return {
    Shell = function(frame)
      if frame.StripTextures then frame:StripTextures() end
      if frame.SetTemplate then frame:SetTemplate("Transparent") end
    end,
    Button = call("HandleButton"), EditBox = call("HandleEditBox"), Checkbox = call("HandleCheckBox"),
    CloseButton = call("HandleCloseButton"),
  }
end

function FU.applySkin(f)
  if not skin then skin = elvSkin() end
  if not (skin and f) then return end
  S("Shell", f)
  S("CloseButton", f.close)
  S("Button", f.rescan)
  S("EditBox", f.maxBox, { padInput = true })
  S("Checkbox", f.fitGold)
  if FU.ahButton then S("Button", FU.ahButton) end
end

-- Nome da linha: as peças na cor da qualidade ("já tem" em cinza) e o level se passar do meu.
function FU.rowName(r, ctx)
  local parts = {}
  for _, c in ipairs(r.parts) do
    if c.kept then
      parts[#parts + 1] = "|cff9d9d9d" .. (c.g.name or "?") .. " (já tem)|r"
    else
      local col = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[c.g.quality or 2]
      parts[#parts + 1] = (col and col.hex or "|cff1eff00") .. (c.g.name or "?") .. "|r"
    end
  end
  local s = table.concat(parts, " + ")
  if ctx and r.req > ctx.level then s = s .. string.format(" |cffff8040lvl %d|r", r.req) end
  return s
end

local function drawRow(row, r, ctx, overview)
  local off = overview and 62 or 0
  row.slot:SetShown(overview)
  row.slot:SetText(overview and groupLabel(r.group, ctx, r) or "")
  for k = 1, 2 do
    local ib, c = row.icons[k], r.parts[k]
    ib:SetShown(c ~= nil)
    if c then
      ib:ClearAllPoints()
      ib:SetPoint("LEFT", row, "LEFT", off + (k - 1) * 22, 0)
      ib.tex:SetTexture(itemIcon(c.g.id))
      ib.tex:SetDesaturated(c.kept and true or false)
      ib:SetAlpha(c.kept and 0.55 or 1)
    end
  end
  local nameX = off + #r.parts * 22 + 4
  row.name:ClearAllPoints()
  row.name:SetPoint("LEFT", row, "LEFT", nameX, 0)
  row.name:SetWidth(300 - nameX - 6)
  row.name:SetText(FU.rowName(r, ctx))
  row.stats:SetText(FU.statText(r.s) .. (r.breaksSet and " |cffff8040set|r" or ""))
  row.gain:SetText("|cff40ff40+" .. FU.num(r.gain) .. "|r")
  local src = r.parts[1] and (r.parts[1].kept and r.parts[2] or r.parts[1]).g.src
  if src then
    row.price:SetText("|cffffd200" .. FU.src.short(src) .. "|r")
  else
    local over = ctx and r.price > ctx.money
    row.price:SetText((over and "|cffff5050" or "") .. FU.coins(r.price) .. (over and "|r" or ""))
  end
end

-- Texto em cima da lista: o que está equipado no slot (ou o resumo do "Tudo").
local function subHeader(f, ctx, res, key)
  local icon, s
  if not ctx then
    s = ""
  elseif key == "all" then
    local rows, gain, price = FU.overview(res)
    icon = COIN_ICON
    if #rows == 0 then
      s = "Nada que seja upgrade com esses filtros."
    else
      local over = price > ctx.money
      s = FU.mode() == "src" and string.format("O melhor de cada slot · pegando tudo: |cff40ff40+%s|r", FU.num(gain)) or string.format("O melhor de cada slot · comprando tudo: |cff40ff40+%s|r por %s%s%s", FU.num(gain),
        over and "|cffff5050" or "", FU.coins(price), over and "|r" or "")
    end
  elseif key == "weapon" then
    local m, o = ctx.eq.MainHand, ctx.eq.OffHand
    icon = m.icon or emptySlotIcon("MainHandSlot")
    local base = m.score + (o.link and o.score or 0)
    s = "Na mão: " .. (m.link and m.name or "nada") .. (o.link and (" + " .. o.name) or "") .. " (" .. FU.num(base) .. ")"
  else
    local slots = FU.GROUP_BY[key].slots
    local parts = {}
    for _, n in ipairs(slots) do
      local e = ctx.eq[n]
      parts[#parts + 1] = (e.link and e.name or "nada") .. " (" .. FU.num(e.score) .. ")"
      icon = icon or e.icon
    end
    icon = icon or emptySlotIcon(FU.GROUP_BY[key].inv)
    s = (#slots > 1 and "Equipados: " or "Equipado: ") .. table.concat(parts, " · ")
  end
  f.subIcon:SetShown(icon ~= nil)
  if icon then f.subIcon:SetTexture(icon) end
  f.sub:SetWidth(key == "weapon" and (LIST_W - 270) or (LIST_W - 26))
  f.sub:SetText(s)
end

function FU.draw()
  local f = FU.frame
  if not f then return end
  local db = FU.db()
  local ctx, res = FU.ctx, FU.res
  local ah = FU.ah

  local srcMode = FU.mode() == "src"
  local info
  if FU.noData and srcMode then
    info = "|cffff8040O banco de fontes (SourcesData.lua) não carregou: reinstala o FindUpgrade.|r"
  elseif FU.noData then
    info = "Ainda não tem varredura do AH. Abre o leiloeiro e clica em Varrer o AH (1 a cada 15 min)."
  elseif not ctx then
    info = "Calculando..."
  elseif srcMode then
    local names = { quest = "Quests", dungeon = "Dungeons", vendor = "Vendedores" }
    info = string.format("%s · %d itens no banco (de %s) · lvl %d", names[FU.view()] or "Fontes", ctx.total or 0,
      FU.src.available() or "?", ctx.level)
    if (ctx.pending or 0) > 0 then info = info .. string.format(" · %d ainda sem dados (abre de novo daqui a pouco)", ctx.pending) end
  else
    info = string.format("Varredura de %s · %d peças · teu gold %s · lvl %d", scanWhen(), ctx.total or 0,
      FU.coins(ctx.money), ctx.level)
    if ah.mode == "vaultsync" then info = info .. " · varredura do VaultSync" end
    if (ctx.skipped or 0) > 0 then info = info .. string.format(" · %d pedem profissão/reputação", ctx.skipped) end
    if (ctx.pending or 0) > 0 then info = info .. string.format(" · %d sem dados", ctx.pending) end
    if (ctx.missing or 0) > 0 then
      info = info .. string.format(" · |cffff5050%d peça(s) equipada(s) sem dados: fecha e abre a janela|r", ctx.missing)
    end
    if FU.computing then info = info .. " · recalculando..." end
  end
  f.info:SetText(info)

  f.levelSeg.Select(db.plus)
  f.levelSeg.buttons[1].label:SetText(ctx and ("Meu lvl (" .. ctx.level .. ")") or "Meu lvl")
  f.fitGold:SetChecked(db.fitGold)
  f.modeSeg.Select(FU.view())
  for _, w in ipairs(f.priceBits) do w:SetShown(not srcMode) end
  local unit = FU.UNIT_BY[db.maxUnit] or FU.UNIT_BY.g
  f.unit.Set(nil, unit.icon)
  do
    local _, cls = UnitClass("player")
    local ci = (ctx and ctx.ci) or FU.CLASSES[cls or ""] or FU.CLASSES.WARRIOR
    f.role.Set(FU.ROLES[FU.roleFor(ci)].label)
  end
  f.weaponSeg.buttons[2].label:SetText(twoHandLabel(ctx and ctx.ci))

  local overview = res and FU.overview(res)
  local ar, ag, ab = accent()
  for _, b in ipairs(f.groups) do
    local rows = res and (b.key == "all" and overview or res[b.key])
    local best = rows and rows[1]
    b.gain:SetText(best and ("|cff40ff40+" .. FU.num(best.gain) .. "|r") or "|cff555555—|r")
    if b.key ~= "all" then
      local e = ctx and ctx.eq[FU.GROUP_BY[b.key].slots[1]]
      b.icon:SetTexture(e and e.icon or emptySlotIcon(b.inv))
      b.icon:SetDesaturated(not (e and e.link))
      b.label:SetText(groupLabel(b.key, ctx))
    end
    local on = b.key == db.group
    b.bg:SetColorTexture(1, 1, 1, on and 0.10 or 0)
    b.bar:SetColorTexture(ar, ag, ab, 1)
    b.bar:SetShown(on)
    if on then b.label:SetTextColor(1, 1, 1) else b.label:SetTextColor(0.75, 0.75, 0.75) end
  end

  local key = FU.GROUP_BY[db.group] and db.group or "all"
  local list = {}
  if res then list = key == "all" and overview or res[key] or {} end
  f.weaponSeg.SetShown(key == "weapon")
  f.weaponSeg.Select(db.weaponMode)
  subHeader(f, ctx, res, key)

  local maxOff = math.max(0, #list - NROWS)
  if FU.offset > maxOff then FU.offset = maxOff end
  for i, row in ipairs(f.rows) do
    local r = list[i + FU.offset]
    row.r = r
    row:SetShown(r ~= nil)
    if r then drawRow(row, r, ctx, key == "all") end
  end
  local empty = ""
  if ctx and #list == 0 then
    empty = "Nada que seja upgrade aqui com esses filtros."
    if db.plus == 0 then empty = empty .. "\nTenta +3 levels" .. (FU.maxPiece() and " ou um preço máximo maior." or ".") end
    if db.plus ~= 0 and FU.maxPiece() then empty = empty .. "\nTenta um preço máximo maior." end
    if db.fitGold then empty = empty .. "\nTá marcado: só o que cabe no teu gold." end
  end
  f.empty:SetText(empty)
  f.scrollText:SetText(#list > NROWS and string.format("%d–%d de %d", FU.offset + 1, math.min(#list, FU.offset + NROWS), #list) or "")

  local status, canScan
  if srcMode then
    status = "Não precisa do leiloeiro: vem do banco de fontes do addon."
  elseif ah.scanning() then
    status = "|cff88ccff" .. (ah.status() or "Varrendo o AH") .. ": a lista atualiza sozinha quando acabar.|r"
  elseif not ah.isOpen() then
    status = "Abre o leiloeiro pra varrer de novo."
  elseif ah.wait() > 0 then
    status = string.format("Próxima varredura liberada em %d min.", math.ceil(ah.wait() / 60))
  else
    status = "Varredura liberada."
    canScan = true
  end
  f.status:SetText(status)
  f.rescan:SetEnabled(canScan and true or false)
end

-- Recalcula só os filtros (sem varrer o equipamento de novo) e redesenha.
function FU.refresh()
  if FU.ctx then FU.res = FU.results(FU.ctx, FU.filters(FU.ctx)) end
  local ok, err = pcall(FU.draw)
  if not ok then say("erro desenhando a janela: " .. tostring(err)) end
end

-- Abre a janela e recalcula com a varredura que tiver.
-- A conta guardada de cada família (ah, src). Joga fora quando muda o que entra nela:
-- FU.invalidate() tudo (peça, level, papel, pesos), FU.invalidate("ah") varredura nova,
-- FU.invalidate("src") quest entregue.
FU.ctxBy = FU.ctxBy or {}
function FU.invalidate(family)
  if family then FU.ctxBy[family] = nil else FU.ctxBy = {} end
end

-- Abre a janela. Com a conta da família guardada, só redesenha (troca de botão na hora); senão
-- começa uma conta nova e larga a que estava rodando (ela para no meio, sem travar nada).
function FU.show()
  if not FU.frame then
    local ok, f = pcall(FU.build)
    if not ok then
      say("erro abrindo a janela: " .. tostring(f))
      return
    end
    FU.frame = f
  end
  FU.frame:Show()
  local fam = FU.mode()
  local cached = FU.ctxBy[fam]
  if cached then
    FU.gen = (FU.gen or 0) + 1 -- a conta da outra família, se rodando, não serve mais
    FU.computing, FU.noData, FU.ctx = false, false, cached
    FU.refresh()
    return
  end
  FU.gen = (FU.gen or 0) + 1
  local gen = FU.gen
  FU.computing, FU.ctx, FU.res = true, nil, nil
  FU.refresh()
  FU.compute(function(ctx)
    if gen ~= FU.gen then return end
    FU.computing = false
    FU.noData = ctx == nil
    FU.ctx = ctx
    if ctx then FU.ctxBy[fam] = ctx end
    FU.refresh()
  end, gen)
end

-- Tooltips e cliques ------------------------------------------------------------

local function boughtParts(r)
  local out = {}
  for k, c in ipairs(r.parts) do
    if not c.kept then out[#out + 1] = k end
  end
  return out
end

function FU.tipPart(owner, r, k)
  local c = r and r.parts[k]
  if not (c and GameTooltip) then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if c.g.link then GameTooltip:SetHyperlink(c.g.link) end
  GameTooltip:AddLine(" ")
  if c.kept then
    GameTooltip:AddLine("Já é teu: fica no combo.", 0.7, 0.7, 0.7)
  elseif c.g.src then
    for i, l in ipairs(FU.src.lines(c.g.src)) do GameTooltip:AddLine(l, i == 1 and 1 or 0.8, i == 1 and 0.82 or 0.8, i == 1 and 0 or 0.8, true) end
    GameTooltip:AddLine("Clique: escreve no chat de onde vem · Shift-clique: link", 0.6, 0.6, 0.6)
  else
    local n = c.g.n or 1
    GameTooltip:AddLine(string.format("%s · %d anúncio%s", FU.coins(c.price), n, n == 1 and "" or "s"), 1, 1, 1)
    GameTooltip:AddLine("Clique: busca no AH · Shift-clique: link no chat", 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

function FU.tipRow(owner, r)
  if not (r and GameTooltip) then return end
  local idx = boughtParts(r)
  local c = r.parts[idx[1] or 1]
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if c.g.link then GameTooltip:SetHyperlink(c.g.link) end
  GameTooltip:AddLine(" ")
  if #r.parts > 1 then
    local names = {}
    for _, p in ipairs(r.parts) do names[#names + 1] = (p.g.name or "?") .. (p.kept and " (já tem)" or "") end
    GameTooltip:AddLine("Combo: " .. table.concat(names, " + ") .. " · " .. FU.coins(r.price), 1, 1, 1, true)
    local pg = r.partGain
    if pg and (pg[1] or pg[2]) then
      local bits = {}
      if pg[1] then bits[#bits + 1] = "arma +" .. FU.num(pg[1]) end
      if pg[2] then bits[#bits + 1] = "off-hand +" .. FU.num(pg[2]) end
      GameTooltip:AddLine("Cada peça contra o que tu tem: " .. table.concat(bits, " · "), 0.7, 0.9, 0.7, true)
    end
  end
  for _, k in ipairs(idx) do
    for i, l in ipairs(FU.src.lines(r.parts[k].g.src)) do
      GameTooltip:AddLine(l, i == 1 and 1 or 0.8, i == 1 and 0.82 or 0.8, i == 1 and 0 or 0.8, true)
    end
  end
  GameTooltip:AddLine("Troca: " .. r.replaces .. (r.breaksSet and " |cffff8040(quebra o set)|r" or ""), 1, 0.82, 0, true)
  if c.g.src then
    GameTooltip:AddLine("Ganho +" .. FU.num(r.gain), 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Clique: escreve no chat de onde vem · Shift-clique: link", 0.6, 0.6, 0.6, true)
  else
    GameTooltip:AddLine(string.format("Ganho +%s · %d anúncio%s", FU.num(r.gain), c.g.n or 1, (c.g.n or 1) == 1 and "" or "s"),
      0.7, 0.7, 0.7)
    GameTooltip:AddLine(#idx > 1 and "Clique busca a 1ª peça, o 2º clique a outra. Ou clica no ícone de cada uma."
      or "Clique: busca no AH · Shift-clique: link no chat", 0.6, 0.6, 0.6, true)
  end
  GameTooltip:Show()
end

-- Busca a peça no AH (aba Comprar). Item com sufixo: busca o nome base e diz qual pegar.
function FU.search(c)
  local g = c.g
  local ahf = _G.AuctionHouseFrame
  if not (FU.ah.isOpen() and ahf and ahf.SearchBar) then
    say("abre o leiloeiro pra buscar " .. (g.link or g.name or "o item") .. ".")
    return false
  end
  local name = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(g.id)) or g.name
  local ok = pcall(function()
    if ahf.SetDisplayMode and AuctionHouseFrameDisplayMode then ahf:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy) end
    ahf.SearchBar:SetSearchText(name)
    ahf.SearchBar:StartSearch()
  end)
  if ok and g.name and g.name ~= name then
    say("buscando " .. name .. ". Pega o " .. g.name .. " (" .. FU.coins(c.price) .. ").")
  end
  return ok
end

local function linkToChat(c)
  if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick and c.g.link then
    HandleModifiedItemClick(c.g.link)
    return true
  end
end

-- Item de quest ou dungeon: escreve no chat de onde vem e como pegar.
function FU.tellSource(c)
  local lines = FU.src.lines(c.g.src)
  say((c.g.name or "?") .. ": " .. table.concat(lines, " — "))
end

function FU.clickPart(r, k)
  local c = r and r.parts[k]
  if not c or linkToChat(c) or c.kept then return end
  if c.g.src then return FU.tellSource(c) end
  FU.search(c)
end

-- Clique na linha: busca a peça; num combo de duas compras, o clique seguinte busca a outra.
function FU.click(r)
  if not r then return end
  local idx = boughtParts(r)
  local k = idx[1]
  if not k then return end
  if #idx > 1 and r.nextPart then k = idx[2] end
  local c = r.parts[k]
  if linkToChat(c) then return end
  if c.g.src then
    for _, i in ipairs(idx) do FU.tellSource(r.parts[i]) end
    return
  end
  if FU.search(c) and #idx > 1 then
    r.nextPart = not r.nextPart
    if r.nextPart then say("clica de novo na linha pra buscar " .. (r.parts[idx[2]].g.name or "a outra peça") .. ".") end
  end
end

-- Varredura e comando --------------------------------------------------------------

function FU.rescan()
  if not FU.ah.isOpen() then
    say("abre o leiloeiro pra varrer o AH.")
    return
  end
  FU.ah.start(function()
    if FU.frame and FU.frame:IsShown() then FU.refresh() end
  end)
  FU.refresh()
end

-- A varredura terminou (do botão, do VaultSync ou do Auctionator): recalcula se aberta.
function FU.gearChanged()
  FU.invalidate("ah")
  if FU.mode() == "ah" and FU.frame and FU.frame:IsShown() then FU.show() end
end

-- /findupgrade: abre com a última varredura; com o leiloeiro aberto e a varredura liberada,
-- varre de novo. "/findupgrade scan" só varre.
function FU.run(msg)
  msg = (msg or ""):lower()
  local ah = FU.ah
  if msg == "scan" or msg == "varrer" then
    ah.start(function() if FU.frame and FU.frame:IsShown() then FU.refresh() end end)
    return
  end
  -- "/fu config" abre as configurações.
  if msg == "config" or msg == "opcoes" or msg == "opções" or msg == "options" then
    FU.cfg.show()
    return
  end
  -- "/fu debug": quanto a última conta levou (pra achar travada).
  if msg == "debug" then
    local p = FU.perf
    if not p then
      say("ainda não teve conta nesta sessão.")
    else
      say(string.format("última conta (%s): %d itens · %.0f ms de trabalho em %d fatias (maior %.1f ms) · %d sem dados depois de %d tentativas",
        p.mode, p.items, p.work, p.slices, p.maxSlice, p.pending or 0, p.tries or 0))
    end
    return
  end
  -- "/fu quests", "/fu dungeons", "/fu vendedores" e "/fu ah" abrem direto no botão.
  local views = { quests = "quest", quest = "quest", fontes = "quest", dungeons = "dungeon", dungeon = "dungeon",
    vendedores = "vendor", vendedor = "vendor", ah = "ah", leilao = "ah" }
  if views[msg] then FU.db().mode = views[msg] end
  if FU.mode() == "src" then
    if not FU.src.available() then
      say("o banco de fontes (SourcesData.lua) não carregou: reinstala o FindUpgrade.")
      return
    end
    FU.show()
    return
  end
  local canScan = ah.isOpen() and not ah.scanning() and ah.wait() == 0
  if not canScan and not FU.load() then
    say("ainda não tem varredura do AH. Abre o leiloeiro e digita /findupgrade.")
    return
  end
  FU.show()
  if canScan and FU.db().autoScan ~= false then FU.rescan() end
end

-- Botões no topo do leiloeiro: uma fila só, da direita pra esquerda a partir do X, sem buraco.
-- A lista é global (VaultAHButtons) e o Profissões ("Lucro de craft") faz a mesma conta;
-- ahOrder diz a ordem (1 = mais à direita). Sozinho, o botão fica colado no X.
local function placeAHButton(b, order)
  local bar = _G.VaultAHButtons or {}
  _G.VaultAHButtons = bar
  b.ahOrder = order
  bar[#bar + 1] = b
  table.sort(bar, function(x, y) return (x.ahOrder or 9) < (y.ahOrder or 9) end)
  local prev
  for _, x in ipairs(bar) do
    x:ClearAllPoints()
    if prev then
      x:SetPoint("RIGHT", prev, "LEFT", -4, 0)
    else
      x:SetPoint("TOPRIGHT", _G.AuctionHouseFrame, "TOPRIGHT", -30, -2)
    end
    prev = x
  end
end

function FU.attachAHButton()
  local ahf = _G.AuctionHouseFrame
  if not ahf or FU.ahButton then return end
  local b = CreateFrame("Button", nil, ahf, "UIPanelButtonTemplate")
  b:SetSize(96, 20)
  b:SetText("Gear upgrade")
  placeAHButton(b, 2)
  b:SetFrameStrata("HIGH")
  b:SetScript("OnClick", function() FU.run() end)
  S("Button", b)
  FU.ahButton = b
  b:SetShown(FU.db().ahButton ~= false)
end

-- Mostra ou esconde os botões de abrir conforme a configuração.
function FU.applyButtons()
  local db = FU.db()
  if FU.charButton then FU.charButton:SetShown(db.charButton ~= false) end
  if FU.ahButton then FU.ahButton:SetShown(db.ahButton ~= false) end
end

-- Abre ou fecha a janela no último modo (leilão ou quests e dungeons), sem varrer nada.
function FU.toggle()
  if FU.frame and FU.frame:IsShown() then
    FU.frame:Hide()
    return
  end
  FU.show()
end
-- Global pro atalho de teclado (Bindings.xml) e pro menu de addons do minimapa (.toc).
FindUpgrade_Toggle = function() FU.toggle() end
BINDING_HEADER_FINDUPGRADE = "FindUpgrade"
BINDING_NAME_FINDUPGRADE_TOGGLE = "Abrir/fechar a janela de upgrades"

-- Botão na janela do personagem (tecla C): uma aba colada na borda direita, por fora, pra não
-- cobrir nada do que a janela (ou o skin do EllesmereUI) desenha dentro. Abre e fecha a janela.
local CHAR_ICON = "Interface\\Icons\\Spell_ChargePositive"
function FU.attachCharButton()
  local cf = _G.CharacterFrame
  if not cf or FU.charButton then return end
  local b = CreateFrame("Button", "FindUpgradeCharButton", cf)
  b:SetSize(34, 34)
  b:SetPoint("TOPLEFT", cf, "TOPRIGHT", 2, -64)
  flat(b, 0.05, 0.05, 0.07, 0.92)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 3, -3)
  b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  b.icon:SetTexture(CHAR_ICON)
  flat(b, 1, 1, 1, 0.15, "HIGHLIGHT")
  S("SquareIcon", b.icon, b)
  b:SetScript("OnClick", function() FU.toggle() end)
  b:SetScript("OnEnter", function(self)
    tip(self, { "Upgrades", "O que vale a pena no leilão, em quests e em dungeons, pro teu papel.", "Clique abre e fecha." })
  end)
  b:SetScript("OnLeave", hideTip)
  FU.charButton = b
  b:SetShown(FU.db().charButton ~= false)
end

SLASH_FINDUPGRADE1 = "/findupgrade"
SLASH_FINDUPGRADE2 = "/fu"
SlashCmdList.FINDUPGRADE = function(msg) FU.run(msg) end

table.insert(FU.ah.listeners, function() FU.gearChanged() end)

-- Durante a varredura própria, o rodapé mostra o progresso (no máximo 4 vezes por segundo).
local progressPending = false
function FU.onScanProgress()
  if progressPending or not (FU.frame and FU.frame:IsShown()) then return end
  progressPending = true
  C_Timer.After(0.25, function()
    progressPending = false
    pcall(FU.draw)
  end)
end

if EllesmereUI and EllesmereUI.RegisterSkin then
  pcall(EllesmereUI.RegisterSkin, ADDON, function(s)
    skin = s
    if FU.frame then FU.applySkin(FU.frame) end
  end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "PLAYER_MONEY",
  "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then FU.db() end
    return
  end
  if event == "PLAYER_LOGIN" then
    pcall(FU.attachCharButton)
    return
  end
  if event == "AUCTION_HOUSE_SHOW" then pcall(FU.attachAHButton) end
  local f = FU.frame
  if not (f and f:IsShown()) then return end
  if event == "PLAYER_MONEY" then
    if FU.ctx then FU.ctx.money = GetMoney() or FU.ctx.money end
    FU.refresh()
  elseif event == "QUEST_TURNED_IN" then
    FU.invalidate("src") -- a quest entregue sai da lista na próxima vez
    if FU.mode() == "src" then FU.show() end
  elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
    FU.invalidate()
    if FU.debounce then return end
    FU.debounce = true
    C_Timer.After(1, function()
      FU.debounce = false
      if f:IsShown() then FU.show() end
    end)
  else
    FU.refresh()
  end
end)
