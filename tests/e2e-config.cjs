// Tela de configurações: dica no tooltip, botões de abrir, varrer sozinho, ganho mínimo e pesos
// por cima do papel (com "voltar ao padrão"), e a página em Opções → AddOns.
const { run } = require('./harness.cjs');

const setup = String.raw`
CLASS, LEVEL, MONEY = "PRIEST", 20, 100000
CharacterFrame = CreateFrame("Frame")
REG = {}
Settings = { RegisterCanvasLayoutCategory = function(panel, name) REG.name = name; return { panel = panel } end,
  RegisterAddOnCategory = function(cat) REG.added = cat end }
ITEMS = {
  [4314] = { "Double-Stitched Woolen Shoulders", "INVTYPE_SHOULDER", 4, 1, 17, { ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 4 } },
  [4315] = { "Reinforced Woolen Shoulders", "INVTYPE_SHOULDER", 4, 1, 19, { ITEM_MOD_INTELLECT_SHORT = 4, ITEM_MOD_SPELL_POWER_SHORT = 5 } },
  [1449] = { "Minor Channeling Ring", "INVTYPE_FINGER", 4, 0, 18, { ITEM_MOD_INTELLECT_SHORT = 2, ITEM_MOD_SPELL_POWER_SHORT = 5 } },
}
EQUIP = { [3] = link(4314) }
LISTINGS = { { 4315, 2000, link(4315) }, { 1449, 1500, link(1449) } }
`;

const driver = String.raw`
local FU = loadAddon()
fire("PLAYER_LOGIN")
assert(REG.name == "FindUpgrade" and REG.added, "página em Opções → AddOns")
assert(FU.charButton and FU.charButton.shown, "botão da janela do personagem ligado")

SlashCmdList.FINDUPGRADE("config")
local c = FindUpgradeConfig
assert(c and c.shown, "/fu config abre a tela")
local checks = c.checks
assert(checks[1].checked == true and checks[2].checked == true and checks[6].checked == true, "tudo ligado no começo")
-- Dica no tooltip e botões.
checks[1].scripts.OnClick(checks[1])
assert(FindUpgradeDB.tooltipOff == true and checks[1].checked == false, "desliga a dica no tooltip")
checks[4].scripts.OnClick(checks[4])
assert(FindUpgradeDB.charButton == false and not FU.charButton.shown, "esconde o botão da janela do personagem")
checks[4].scripts.OnClick(checks[4])
assert(FU.charButton.shown, "mostra de novo")
-- Varrer sozinho desligado: abre a janela sem varrer.
checks[6].scripts.OnClick(checks[6])
assert(FindUpgradeDB.autoScan == false, "varrer sozinho desligado")
openAH()
assert(FU.ahButton and FU.ahButton.shown, "botão no leiloeiro")
SlashCmdList.FINDUPGRADE("")
runTimers()
assert(not REPLICATED and FindUpgradeFrame and FindUpgradeFrame.shown, "abre sem varrer")
checks[6].scripts.OnClick(checks[6])
SlashCmdList.FINDUPGRADE("")
assert(REPLICATED == 1, "ligado de novo: varre")
fire("REPLICATE_ITEM_LIST_UPDATE")
assert(#FU.res.Shoulder == 1 and near(FU.res.Shoulder[1].gain, 3.6) and #FU.res.Finger == 1 and near(FU.res.Finger[1].gain, 6.8), "ombro +3,6 e anel +6,8")
checks[5].scripts.OnClick(checks[5])
assert(not FU.ahButton.shown, "esconde o botão do leiloeiro")
checks[5].scripts.OnClick(checks[5])

-- Ganho mínimo: 5 tira o ombro (+3,6), o anel (+6,8) fica.
assert(c.minHint.text:find("padrão do papel: 2", 1, true), "dica do mínimo: " .. tostring(c.minHint.text))
c.minBox.text = "5"
c.minBox.scripts.OnEnterPressed(c.minBox)
runTimers()
assert(FindUpgradeDB.minGain == 5 and #FU.res.Shoulder == 0 and #FU.res.Finger == 1, "mínimo 5")

-- Pesos: Int vale 3 → o ombro (4 Int + 5 SP = 17 contra 5) volta com +12.
assert(c.weightsHeader.text == "Pesos · Cura", "pesos do papel de agora")
local intBox
for _, eb in ipairs(c.weights) do if eb.stat == "int" then intBox = eb end end
assert(intBox.text == "" and intBox.def.text == "padrão 0,9", "Int no padrão (0,9)")
intBox.text = "3"
intBox.scripts.OnEnterPressed(intBox)
runTimers()
assert(FindUpgradeDB.weights.heal.int == 3 and FU.ctx.w.int == 3, "peso salvo e na conta")
assert(#FU.res.Shoulder == 1 and near(FU.res.Shoulder[1].gain, 12), "ombro +12 com Int 3")
-- Voltar ao padrão.
c.reset.scripts.OnClick(c.reset)
runTimers()
assert(FindUpgradeDB.weights.heal == nil and FU.ctx.w.int == 0.9 and intBox.text == "", "voltou ao padrão")
assert(#FU.res.Shoulder == 0, "ombro some de novo (mínimo 5)")
-- Engrenagem da janela abre e fecha.
local gear = FindUpgradeFrame.gear
gear.scripts.OnClick(gear)
assert(not c.shown, "engrenagem fecha")
gear.scripts.OnClick(gear)
assert(c.shown, "engrenagem abre")
noErrors()
`;

run('configurações', setup, driver);
