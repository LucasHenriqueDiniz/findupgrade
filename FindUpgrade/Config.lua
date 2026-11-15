-- FindUpgrade · Config.lua
-- A tela de configurações: a engrenagem no alto da janela, /fu config ou Opções → AddOns.
--   Geral: dica no tooltip (e o que ela mostra), botões de abrir, varrer sozinho, ganho mínimo.
--   Pesos: o peso de cada stat no papel de agora, por cima do padrão (vazio = padrão; 0 tira).
-- Tudo fica em FindUpgradeDB (por personagem). Ver docs/pontuacao.md.

local _, FU = ...
FU = FU or FindUpgrade

local cfg = {}
FU.cfg = cfg

local W, H = 480, 600

local function db() return FU.db() end

-- Mudou algo: a dica do tooltip relê o equipado; a janela redesenha (ou recalcula, se mudou nota).
local function changed(recompute)
  if FU.tip and FU.tip.reset then FU.tip.reset() end
  if FU.frame and FU.frame:IsShown() then
    if recompute then
      FU.invalidate()
      FU.show()
    else
      FU.refresh()
    end
  end
end

local function currentRole()
  local _, cls = UnitClass("player")
  local ci = FU.CLASSES[cls or ""] or FU.CLASSES.WARRIOR
  local role = FU.roleFor(ci)
  return role, FU.ROLES[role]
end

-- "1,5" → 1.5; vazio → nil; aceita 0 (peso zero tira o stat).
local function parse(t)
  t = tostring(t or ""):gsub("%s", ""):gsub(",", ".")
  if t == "" then return nil end
  return tonumber(t)
end

local function fmt(v)
  if v == nil then return "" end
  return (string.format("%.3f", v):gsub("%.?0+$", ""):gsub("%.", ","))
end

local function check(parent, x, y, label, tipText, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  cb:SetPoint("TOPLEFT", x, y)
  local t = FU.ui.text(parent)
  t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  t:SetText(label)
  cb.label = t
  cb:SetScript("OnClick", function(self)
    set(not get())
    self:SetChecked(get())
  end)
  if tipText then
    cb:SetScript("OnEnter", function(self) FU.ui.tip(self, { label, tipText }) end)
    cb:SetScript("OnLeave", FU.ui.hideTip)
  end
  function cb.refresh() cb:SetChecked(get()) end
  FU.ui.skin("Checkbox", cb)
  return cb
end

local function box(parent, width)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(width, 18)
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(8)
  return eb
end

local function header(parent, y, label)
  local h = FU.ui.text(parent, "GameFontNormal")
  h:SetPoint("TOPLEFT", 14, y)
  h:SetText(label)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 14, y - 16)
  line:SetPoint("TOPRIGHT", -14, y - 16)
  line:SetHeight(1)
  line:SetColorTexture(1, 1, 1, 0.08)
  return h
end

function cfg.build()
  local f = CreateFrame("Frame", "FindUpgradeConfig", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(W, H)
  f:SetPoint("CENTER", 260, 20)
  f:SetFrameStrata("DIALOG")
  -- Toplevel e Raise ao abrir: fica inteira por cima da janela principal (antes as duas se
  -- misturavam, 14/11).
  if f.SetToplevel then f:SetToplevel(true) end
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UISpecialFrames then table.insert(UISpecialFrames, "FindUpgradeConfig") end
  FU.ui.flat(f, 0.055, 0.055, 0.07, 0.97)
  local top = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(28)
  top:SetColorTexture(0.1, 0.1, 0.125, 1)
  local body = CreateFrame("Frame", nil, f)
  body:SetAllPoints()
  f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.close:SetPoint("TOPRIGHT", 2, 2)
  local title = FU.ui.text(body, "GameFontNormal")
  title:SetPoint("TOPLEFT", 12, -8)
  title:SetText("FindUpgrade · Configurações")

  -- Geral ----------------------------------------------------------------------
  header(body, -40, "Geral")
  f.checks = {
    check(body, 14, -62, "Dica de upgrade no tooltip dos itens",
      "No tooltip de qualquer item que tu equipa: se é upgrade, quanto e no lugar de quê.",
      function() return not db().tooltipOff end, function(v) db().tooltipOff = not v; changed() end),
    check(body, 38, -86, "Mostrar o que muda nos stats", nil,
      function() return db().tipStats ~= false end, function(v) db().tipStats = v; changed() end),
    check(body, 38, -110, "Mostrar de onde vem (quest, dungeon, vendedor)", nil,
      function() return db().tipSource ~= false end, function(v) db().tipSource = v; changed() end),
    check(body, 14, -138, "Botão na janela do personagem (tecla C)", nil,
      function() return db().charButton ~= false end, function(v) db().charButton = v; FU.applyButtons() end),
    check(body, 14, -162, "Botão \"Gear upgrade\" no leiloeiro", nil,
      function() return db().ahButton ~= false end, function(v) db().ahButton = v; FU.applyButtons() end),
    check(body, 14, -186, "Varrer o leilão sozinho ao abrir (quando liberado)",
      "Com o leiloeiro aberto, o /findupgrade e o botão varrem o AH inteiro se já passou 15 min da última.",
      function() return db().autoScan ~= false end, function(v) db().autoScan = v end),
  }
  local minLabel = FU.ui.text(body)
  minLabel:SetPoint("TOPLEFT", 18, -220)
  minLabel:SetText("Ganho mínimo pra aparecer:")
  f.minBox = box(body, 46)
  f.minBox:SetPoint("LEFT", minLabel, "RIGHT", 12, 0)
  f.minHint = FU.ui.text(body, "GameFontDisableSmall")
  f.minHint:SetPoint("LEFT", f.minBox, "RIGHT", 8, 0)
  local function applyMin(self)
    local v = parse(self:GetText())
    db().minGain = (v and v > 0) and v or nil
    self:SetText(fmt(db().minGain))
    changed(true)
  end
  f.minBox:SetScript("OnEnterPressed", function(self) applyMin(self); self:ClearFocus() end)
  f.minBox:SetScript("OnEditFocusLost", applyMin)
  f.minBox:SetScript("OnEscapePressed", function(self) self:SetText(fmt(db().minGain)); self:ClearFocus() end)
  FU.ui.skin("EditBox", f.minBox)

  -- Pesos -----------------------------------------------------------------------
  f.weightsHeader = header(body, -254, "Pesos")
  local reset = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
  reset:SetSize(130, 20)
  reset:SetPoint("TOPRIGHT", -14, -250)
  reset:SetText("Voltar ao padrão")
  reset:SetScript("OnClick", function()
    local role = currentRole()
    if db().weights then db().weights[role] = nil end
    cfg.refresh()
    changed(true)
  end)
  FU.ui.skin("Button", reset)
  f.reset = reset
  local hint = FU.ui.text(body, "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 14, -278)
  hint:SetWidth(W - 28)
  hint:SetJustifyH("LEFT")
  hint:SetText("Quanto vale cada stat no papel de agora. Vazio = padrão (em cinza); 0 tira o stat da conta. Enter aplica. Cura e dano mágico valem menos antes do lvl 40.")
  f.weights = {}
  local per = math.ceil(#FU.STAT_ORDER / 2)
  for i, stat in ipairs(FU.STAT_ORDER) do
    local col, row = (i <= per) and 0 or 1, (i - 1) % per
    local x, y = 14 + col * 232, -300 - row * 26
    local label = FU.ui.text(body)
    label:SetPoint("TOPLEFT", x, y - 3)
    label:SetWidth(118)
    label:SetJustifyH("LEFT")
    label:SetText(FU.STAT_LABEL[stat] or stat)
    local eb = box(body, 44)
    eb:SetPoint("TOPLEFT", x + 124, y)
    local def = FU.ui.text(body, "GameFontDisableSmall")
    def:SetPoint("LEFT", eb, "RIGHT", 6, 0)
    eb.stat, eb.def = stat, def
    local function apply(self)
      local role = currentRole()
      local d = db()
      d.weights = d.weights or {}
      d.weights[role] = d.weights[role] or {}
      d.weights[role][self.stat] = parse(self:GetText())
      if not next(d.weights[role]) then d.weights[role] = nil end
      changed(true)
    end
    eb:SetScript("OnEnterPressed", function(self) apply(self); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", apply)
    FU.ui.skin("EditBox", eb)
    f.weights[i] = eb
  end
  local about = FU.ui.text(body, "GameFontDisableSmall")
  about:SetPoint("BOTTOM", 0, 12)
  about:SetText("FindUpgrade " .. (FU.VERSION or "") .. " · github.com/LucasHenriqueDiniz/findupgrade")
  FU.ui.skin("Shell", f)
  FU.ui.skin("CloseButton", f.close)
  return f
end

-- Mostra o que está salvo (e os pesos do papel de agora).
function cfg.refresh()
  local f = cfg.frame
  if not f then return end
  for _, cb in ipairs(f.checks) do cb.refresh() end
  local role, rs = currentRole()
  f.minBox:SetText(fmt(db().minGain))
  f.minHint:SetText("pontos (vazio = padrão do papel: " .. fmt(rs.min or 2) .. ")")
  f.weightsHeader:SetText("Pesos · " .. rs.label)
  local custom = db().weights and db().weights[role] or {}
  for _, eb in ipairs(f.weights) do
    eb:SetText(fmt(custom[eb.stat]))
    local v = FU.roleWeight(rs, eb.stat, UnitLevel("player"))
    eb.def:SetText(v and ("padrão " .. fmt(math.floor(v * 100 + 0.5) / 100)) or "padrão 0")
  end
end

function cfg.show()
  if not cfg.frame then
    local ok, f = pcall(cfg.build)
    if not ok then
      FU.say("erro abrindo as configurações: " .. tostring(f))
      return
    end
    cfg.frame = f
  end
  cfg.frame:Show()
  if cfg.frame.Raise then cfg.frame:Raise() end
  cfg.refresh()
end

function cfg.toggle()
  if cfg.frame and cfg.frame:IsShown() then
    cfg.frame:Hide()
  else
    cfg.show()
  end
end

-- Opções → AddOns do jogo: uma página com o botão que abre esta tela (quando o cliente tem).
local function registerSettings()
  local panel = CreateFrame("Frame")
  panel.name = "FindUpgrade"
  local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetText("FindUpgrade")
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(200, 24)
  b:SetPoint("TOPLEFT", 16, -50)
  b:SetText("Abrir as configurações")
  b:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel.Hide then pcall(SettingsPanel.Hide, SettingsPanel) end
    cfg.show()
  end)
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "FindUpgrade"))
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end
pcall(registerSettings)
