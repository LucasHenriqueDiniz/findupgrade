// Warrior lvl 20 de DPS (papel padrão "DPS (força)"): malha até o 40 e placa depois, nada de
// pano; arma de 2 mãos contra duas armas (a off-hand conta metade do DPS) e contra arma + escudo;
// crítico e Attack Power lidos do tooltip ("Equip: ..."); no papel de tank o escudo vale muito.
const { run } = require('./harness.cjs');

const setup = String.raw`
CLASS, LEVEL, MONEY = "WARRIOR", 20, 500000
ITEMS = {
  -- equipado: espada de 2 mãos, Str 4 e 10 de DPS → 4×2 + 10×14 = 148; peito de malha 150 de armadura + 3 Sta → 4,5
  [100] = { "Old Greatsword", "INVTYPE_2HWEAPON", 2, 8, 15, { ITEM_MOD_STRENGTH_SHORT = 4 }, { "Old Greatsword", "(10.0 damage per second)" } },
  [101] = { "Chain Vest", "INVTYPE_CHEST", 4, 3, 15, { ITEM_MOD_STAMINA_SHORT = 3 }, { "Chain Vest", "150 Armor" } },
  -- à venda
  [200] = { "Big Axe", "INVTYPE_2HWEAPON", 2, 1, 19, { ITEM_MOD_STRENGTH_SHORT = 8 }, { "Big Axe", "(18.0 damage per second)" } },
  [201] = { "Sword A", "INVTYPE_WEAPON", 2, 7, 18, { ITEM_MOD_STRENGTH_SHORT = 3 }, { "Sword A", "(11.0 damage per second)" } },
  [202] = { "Sword B", "INVTYPE_WEAPON", 2, 7, 17, { ITEM_MOD_AGILITY_SHORT = 4 }, { "Sword B", "(9.0 damage per second)" } },
  [203] = { "Tower Shield", "INVTYPE_SHIELD", 4, 6, 18, { ITEM_MOD_STAMINA_SHORT = 5 }, { "Tower Shield", "600 Armor", "12 Block" } },
  [204] = { "Plate Chest", "INVTYPE_CHEST", 4, 4, 20, { ITEM_MOD_STRENGTH_SHORT = 6 }, { "Plate Chest", "300 Armor" } },
  [205] = { "Mail of the Tiger", "INVTYPE_CHEST", 4, 3, 19, { ITEM_MOD_STRENGTH_SHORT = 5 }, { "Mail of the Tiger", "180 Armor", "Equip: Improves your chance to get a critical strike by 1%." } },
  [206] = { "Silk Robe", "INVTYPE_ROBE", 4, 1, 18, { ITEM_MOD_STRENGTH_SHORT = 20 } },
  [207] = { "Band of Might", "INVTYPE_FINGER", 4, 0, 15, {}, { "Band of Might", "Equip: +20 Attack Power." } },
  [208] = { "Holy Wand", "INVTYPE_RANGEDRIGHT", 2, 19, 15, { ITEM_MOD_INTELLECT_SHORT = 5 } },
  [209] = { "Hunting Bow", "INVTYPE_RANGED", 2, 2, 16, { ITEM_MOD_AGILITY_SHORT = 3 }, { "Hunting Bow", "(8.0 damage per second)" } },
}
EQUIP = { [16] = link(100), [5] = link(101) }
LISTINGS = {}
for _, id in ipairs({ 200, 201, 202, 203, 204, 205, 206, 207, 208, 209 }) do LISTINGS[#LISTINGS + 1] = { id, 1000 + id, link(id) } end
`;

const driver = String.raw`
local FU = loadAddon()
fire("PLAYER_LOGIN")
openAH()
SlashCmdList.FINDUPGRADE("")
fire("REPLICATE_ITEM_LIST_UPDATE")
local f = FindUpgradeFrame
assert(f and FU.ctx, "janela e conta")
noErrors()
local R = FindUpgradeAH["Normal - Alliance"]
assert(R.gear and not R.gear:find("Silk Robe", 1, true) and not R.gear:find("Holy Wand", 1, true),
  "a varredura não guarda pano nem varinha pro warrior")
local ctx, res = FU.ctx, FU.res
assert(ctx.role == "str" and f.role.label.text == "DPS (força)", "warrior começa no DPS de força")
assert(near(ctx.eq.MainHand.score, 148) and ctx.twoHand, "2 mãos equipada: 148")

-- Armas: a 2 mãos nova (8×2 + 18×14 = 268, +120) ganha de duas armas (A 160 + B na off-hand 67 = 227)
-- e de espada + escudo (160 + 14,5).
assert(res.weapon[1].kind == "2h" and res.weapon[1].parts[1].g.id == 200 and near(res.weapon[1].gain, 120), "1o: Big Axe +120")
local dw, shield
for _, r in ipairs(res.weapon) do
  if r.parts[2] and r.parts[2].g.id == 202 and r.parts[1].g.id == 201 then dw = r end
  if r.parts[2] and r.parts[2].g.id == 203 and r.parts[1].g.id == 201 then shield = r end
end
assert(dw and near(dw.gain, 79), "duas armas A + B: +79 (a off-hand conta metade do DPS)")
assert(shield and near(shield.gain, 26.5) and shield.gain < dw.gain, "espada + escudo: +26,5")
assert(f.weaponSeg.buttons[2].label.text == "2 mãos", "warrior: o botão diz 2 mãos")

-- Peito: malha com crítico do tooltip (5×2 + 180×0,02 + 1%×20 = 33,6 contra 4,5) e nada de placa no 20.
assert(#res.Chest == 1 and res.Chest[1].parts[1].g.id == 205 and near(res.Chest[1].gain, 29.1), "malha com crítico +29,1")
assert(res.Chest[1].parts[1].s.crit == 1, "crítico lido do Equip")
-- Anel: +20 AP do Equip.
assert(#res.Finger == 1 and near(res.Finger[1].gain, 20), "anel +20 AP")
-- Distância: arco (3×1 + 8×14×0,1 = 14,2); varinha fora.
assert(#res.Ranged == 1 and res.Ranged[1].parts[1].g.id == 209 and near(res.Ranged[1].gain, 14.2), "arco conta pouco o DPS")
assert(group(f, "Ranged").label.text == "Distância", "warrior: Distância")

-- Tank: o escudo vira o melhor combo (espada 3 + 11×3 = 36; escudo 600×0,1 + 5×2,5 + 12×0,5 = 78,5; contra 34).
choose(f.role, 2)
assert(FindUpgradeDB.role == "tank" and FU.ctx.role == "tank", "papel tank")
local top = FU.res.weapon[1]
assert(top.parts[1].g.id == 201 and top.parts[2] and top.parts[2].g.id == 203 and near(top.gain, 80.5), "tank: espada + escudo +80,5")
choose(f.role, 1)
assert(FU.ctx.role == "str", "volta pro DPS")

-- No 40 a placa entra (e a malha sai: a classe vai pra placa).
LEVEL = 40
fire("PLAYER_LEVEL_UP")
assert(FU.ctx.tier == 4 and #FU.res.Chest == 1 and FU.res.Chest[1].parts[1].g.id == 204, "lvl 40: peito de placa")
noErrors()
`;

run('warrior (DPS, duas armas, escudo, tank, placa no 40)', setup, driver);
