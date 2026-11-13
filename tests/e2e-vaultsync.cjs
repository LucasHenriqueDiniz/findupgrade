// Com o addon VaultSync ligado, o FindUpgrade usa a varredura dele (VaultSyncAPI) em vez de
// varrer de novo: o contrato é loadGear, scanAt, startScan, ahOpen, scanning, scanWait e
// listeners (ver docs/arquitetura.md).
const { run } = require('./harness.cjs');

const setup = String.raw`
CLASS, LEVEL, MONEY = "PRIEST", 20, 100000
ITEMS = {
  [4315] = { "Reinforced Woolen Shoulders", "INVTYPE_SHOULDER", 4, 1, 19, { ITEM_MOD_INTELLECT_SHORT = 4, ITEM_MOD_SPELL_POWER_SHORT = 5 } },
}
local gear = { { id = 4315, link = link(4315), name = "Reinforced Woolen Shoulders", price = 2000, n = 2, level = 19,
  loc = "INVTYPE_SHOULDER", class = 4, sub = 1, quality = 2 } }
VS = { open = false, started = 0 }
VaultSyncAPI = {
  listeners = {},
  loadGear = function() return gear, "2026-11-13 10:00:00" end,
  scanAt = function() return time() - 120, "2026-11-13 10:00:00" end,
  startScan = function(after) VS.started = VS.started + 1; VS.after = after end,
  ahOpen = function() return VS.open end,
  scanning = function() return false end,
  scanWait = function() return 0 end,
}
`;

const driver = String.raw`
local FU = loadAddon()
fire("PLAYER_LOGIN")
assert(FU.ah.mode == "vaultsync", "com o VaultSync: usa a varredura dele")
SlashCmdList.FINDUPGRADE("")
local f = FindUpgradeFrame
assert(f and f.shown and FU.ctx, "abre com a varredura do VaultSync, sem leiloeiro")
assert(not REPLICATED, "não varre sozinho")
assert(#FU.res.Shoulder == 1 and near(FU.res.Shoulder[1].gain, 8.6), "ombro do VaultSync: +8,6")
assert(f.info.text:find("varredura do VaultSync", 1, true), "info diz de onde veio: " .. f.info.text)
-- Leiloeiro aberto: o /findupgrade pede a varredura ao VaultSync, e o aviso dele recalcula.
VS.open = true
SlashCmdList.FINDUPGRADE("")
assert(VS.started == 1, "pede a varredura ao VaultSync")
local before = FU.ctx
for _, fn in ipairs(VaultSyncAPI.listeners) do fn() end
runTimers()
assert(FU.ctx ~= before, "varredura nova do VaultSync recalcula a janela")
noErrors()
`;

run('com o VaultSync (usa a varredura dele)', setup, driver);
