// Priest de cura, lvl 20, sem o VaultSync: o addon varre o AH sozinho, guarda por reino, compara
// com o equipado (GetItemStats + tooltip), separa por slot, filtra por level, preço (com a moeda
// no dropdown) e gold, monta os combos de arma, tira item de profissão e o que a classe não usa,
// espera item sem dados, e o clique busca no AH. Depois do /reload usa a varredura guardada.
const { run } = require('./harness.cjs');

const setup = String.raw`
CLASS, LEVEL, MONEY = "PRIEST", 20, 5686
ITEMS = {
  [4314] = { "Double-Stitched Woolen Shoulders", "INVTYPE_SHOULDER", 4, 1, 17, { ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 4 } },
  [6378] = { "Seer's Cape", "INVTYPE_CLOAK", 4, 1, 11, { ITEM_MOD_INTELLECT_SHORT = 2, ITEM_MOD_SPIRIT_SHORT = 2 } },
  -- a staff equipada só traz a cura no tooltip e chega sem dados (nome vazio) logo depois do /reload
  [2042] = { "Staff of Westfall", "INVTYPE_2HWEAPON", 2, 10, 18, {}, { "Staff of Westfall", "+5 Intellect", "+6 Spirit", "+48 Spell Healing", "+16 Spell Damage" } },
  [12006] = { "Meadow Ring of the Owl", "INVTYPE_FINGER", 4, 0, 17, { ITEM_MOD_INTELLECT_SHORT = 3, ITEM_MOD_SPIRIT_SHORT = 3 } },
  [11967] = { "Zircon Band of Concentration", "INVTYPE_FINGER", 4, 0, 18, { ITEM_MOD_MANA_REGENERATION_SHORT = 2 } },
  -- à venda
  [4315] = { "Reinforced Woolen Shoulders", "INVTYPE_SHOULDER", 4, 1, 19, { ITEM_MOD_INTELLECT_SHORT = 4, ITEM_MOD_SPELL_POWER_SHORT = 5 } },
  [6604] = { "Dervish Cape", "INVTYPE_CLOAK", 4, 1, 21, {}, { "Dervish Cape of Healing", "Equip: Increases healing done by spells and effects by up to 11." } },
  [3184] = { "Hook Dagger", "INVTYPE_WEAPON", 2, 15, 17, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 27 } },
  [4368] = { "Flying Tiger Goggles", "INVTYPE_HEAD", 4, 1, 18, { ITEM_MOD_INTELLECT_SHORT = 10 }, { "Flying Tiger Goggles", { "Requires Engineering (100)" } } },
  [12998] = { "Magician's Mantle", "INVTYPE_SHOULDER", 4, 1, 20, { ITEM_MOD_INTELLECT_SHORT = 9, ITEM_MOD_SPELL_POWER_SHORT = 5 } },
  [9999] = { "Robe of the Far Future", "INVTYPE_ROBE", 4, 1, 25, { ITEM_MOD_INTELLECT_SHORT = 30 } },
  [1449] = { "Minor Channeling Ring", "INVTYPE_FINGER", 4, 0, 18, { ITEM_MOD_INTELLECT_SHORT = 2, ITEM_MOD_SPELL_POWER_SHORT = 5 } },
  [2583] = { "Woolen Boots", "INVTYPE_FEET", 4, 1, 14, { ITEM_MOD_INTELLECT_SHORT = 2, ITEM_MOD_SPIRIT_SHORT = 2, ITEM_MOD_SPELL_POWER_SHORT = 2, ITEM_MOD_NEW_THING = 7 } },
  [8888] = { "Plate Pauldrons", "INVTYPE_SHOULDER", 4, 4, 20, { ITEM_MOD_INTELLECT_SHORT = 20 } },
  -- maça + tomo contra a staff: 48 + (6*0,9 + 4*0,6 + 8) = 63,8 contra 56,1 (48 + 5*0,9 + 6*0,6): +7,7
  [5000] = { "Mace of Mending", "INVTYPE_WEAPONMAINHAND", 2, 4, 19, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 48 } },
  [5001] = { "Tome of Knowledge", "INVTYPE_HOLDABLE", 4, 0, 18, { ITEM_MOD_INTELLECT_SHORT = 6, ITEM_MOD_SPIRIT_SHORT = 4, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 8 } },
}
CACHED = { [2583] = false, [2042] = false }
EQUIP = { [3] = link(4314), [15] = link(6378), [16] = link(2042), [11] = link(12006), [12] = link(11967) }
LISTINGS = {
  { 4315, 2000, link(4315) }, { 4315, 2400, link(4315) }, { 6604, 2200, link(6604, 1) }, { 3184, 1400, link(3184) },
  { 4368, 900, link(4368) }, { 12998, 16900, link(12998) }, { 9999, 500, link(9999) }, { 1449, 1500, link(1449) },
  { 2583, 700, link(2583) }, { 5000, 1500, link(5000) }, { 5001, 800, link(5001) }, { 8888, 300, link(8888) },
}
`;

const driver = String.raw`
local FU = loadAddon()
fire("PLAYER_LOGIN")
assert(FindUpgrade == FU and FU.ah.mode == "proprio", "sem o VaultSync: varredura própria")

-- Sem varredura e sem leiloeiro: avisa e não abre nada.
SlashCmdList.FINDUPGRADE("")
assert(has("ainda não tem varredura"), "sem varredura devia avisar")
assert(not FindUpgradeFrame, "sem varredura não devia abrir janela")

-- Leiloeiro aberto: botão Gear upgrade, e o /findupgrade abre a janela e varre.
openAH()
assert(FU.ahButton and FU.ahButton.text == "Gear upgrade" and VaultAHButtons and VaultAHButtons[1] == FU.ahButton, "botão Gear upgrade no leiloeiro, na fila")
SlashCmdList.FINDUPGRADE("")
assert(REPLICATED == 1, "devia varrer o AH")
local f = FindUpgradeFrame
assert(f and f.shown, "janela não abriu")
assert(f.status.text:find("Pedindo o AH inteiro", 1, true), "rodapé com o progresso: " .. tostring(f.status.text))
fire("REPLICATE_ITEM_LIST_UPDATE")
local R = FindUpgradeAH["Normal - Alliance"]
local nGear = R and R.gear and select(2, R.gear:gsub("\n", "")) + 1
assert(nGear == 10, "o reino devia guardar 10 peças (2 anúncios do mesmo item viram 1; a placa fica fora): " .. tostring(nGear))
assert(has("AH lido: 12 anúncios, 10 peças"), "aviso de fim da varredura")
assert(FU.ctx and not FU.computing, "devia ter calculado depois da varredura")
noErrors()

local db = FindUpgradeDB
assert(db.plus == 0 and db.group == "all" and db.weaponMode == "all" and db.fitGold == false and db.maxUnit == "g", "filtros padrão")
assert(FU.ctx.role == "heal" and f.role.label.text == "Cura", "priest começa no papel de cura")
local res = FU.res
-- Armas: maça + tomo no lugar da staff (+7,7, 23s).
assert(#res.weapon == 1, "armas devia ter 1 combo: " .. #res.weapon)
local combo = res.weapon[1]
assert(combo.parts[1].g.id == 5000 and combo.parts[2].g.id == 5001 and near(combo.gain, 7.7) and combo.price == 2300, "combo maça + tomo")
assert(combo.replaces == "Staff of Westfall", "a staff equipada devia ter nome depois de carregar: " .. tostring(combo.replaces))
assert(db.eq.MainHand:find("Staff of Westfall = 56.1", 1, true), "eq da staff: " .. tostring(db.eq.MainHand))
assert(EQTIP and EQTIP > 0, "devia ler o tooltip da peça equipada")
assert(ids(res.Shoulder) == "12998,4315" and near(res.Shoulder[2].gain, 3.6) and res.Shoulder[2].price == 2000, "ombros")
assert(#res.Feet == 1 and near(res.Feet[1].gain, 5.0), "botas (dados só no 2º pedido) +5")
assert(#res.Finger == 1 and res.Finger[1].slot == "Finger2" and res.Finger[1].replaces == "Zircon Band of Concentration", "anel troca o Zircon")
assert(#res.Back == 0 and #res.Chest == 0 and #res.Head == 0, "capa/robe/óculos fora no lvl 20")
assert(f.info.text:find("1 pedem profissão", 1, true), "info conta o item de profissão: " .. tostring(f.info.text))
assert(db.statKeys.ITEM_MOD_NEW_THING == false and db.statKeys.ITEM_MOD_SPELL_POWER_SHORT == true, "anota chaves de stat")

-- "Tudo": o melhor de cada slot e o total.
local rows = shownRows(f)
assert(#rows == 4 and rows[1].r.parts[1].g.id == 12998 and rows[2].r == combo, "Tudo: 4 linhas na ordem")
assert(rows[2].slot.text == "Arma+OH" and rows[2].name.text:find("Mace of Mending|r + |cff1eff00Tome of Knowledge", 1, true), "linha do combo")
assert(rows[1].price.text:find("ff5050", 1, true), "preço acima do gold em vermelho")
assert(f.sub.text:find("comprando tudo", 1, true) and f.sub.text:find("+24,4", 1, true), "resumo: " .. f.sub.text)
assert(group(f, "Ranged").label.text == "Wand", "priest: Distância vira Wand")

-- Gold, level e preço máximo com a moeda no dropdown.
f.fitGold.scripts.OnClick(f.fitGold)
assert(db.fitGold and ids(FU.res.Shoulder) == "4315", "com o gold: só o Reinforced")
f.fitGold.scripts.OnClick(f.fitGold)
f.levelSeg.buttons[2].scripts.OnClick(f.levelSeg.buttons[2])
assert(db.plus == 3 and #FU.res.Back == 1 and near(FU.res.Back[1].gain, 8), "+3: capa do 21 (+8, cura só no tooltip)")
f.levelSeg.buttons[3].scripts.OnClick(f.levelSeg.buttons[3])
assert(db.plus == 5 and #FU.res.Chest == 1 and near(FU.res.Chest[1].gain, 27), "+5: robe +27")
choose(f.unit, 2) -- Prata
assert(db.maxUnit == "s" and f.unit.icon.tex:find("SilverIcon", 1, true), "moeda: prata")
f.maxBox.text = "15"
f.maxBox.scripts.OnTextChanged(f.maxBox, true)
assert(db.maxValue == 15 and FU.maxPiece() == 1500, "15 de prata = 1500c")
assert(#FU.res.Shoulder == 0 and #FU.res.Back == 0 and #FU.res.weapon == 1, "15s: sem ombro nem capa; o combo fica (15s + 8s)")
choose(f.unit, 1) -- Ouro
assert(db.maxUnit == "g" and FU.maxPiece() == 150000 and #FU.res.Shoulder == 2, "15 de ouro: tudo de novo")
f.maxBox.text = "0,1"
f.maxBox.scripts.OnTextChanged(f.maxBox, true)
assert(FU.maxPiece() == 1000 and #FU.res.weapon == 0, "0,1 de ouro = 10s: a maça (15s) sai")
f.maxBox.scripts.OnEnterPressed(f.maxBox)
assert(f.maxBox.text == "0,1", "caixa mostra 0,1: " .. tostring(f.maxBox.text))
f.maxBox.text = ""
f.maxBox.scripts.OnTextChanged(f.maxBox, true)
assert(FU.maxPiece() == nil and #FU.res.weapon == 1, "vazio: sem limite")

-- Armas: só 2 mãos (não tem à venda) e só arma + secundária; cliques.
pick(f, "weapon")
assert(f.weaponSeg.buttons[2].label.text == "Staff", "priest: o botão de 2 mãos diz Staff")
f.weaponSeg.buttons[2].scripts.OnClick(f.weaponSeg.buttons[2])
assert(#FU.res.weapon == 0 and f.empty.text:find("Nada que seja upgrade", 1, true), "só staff: nada")
f.weaponSeg.buttons[3].scripts.OnClick(f.weaponSeg.buttons[3])
rows = shownRows(f)
assert(#rows == 1, "arma + secundária: o combo")
rows[1].scripts.OnClick(rows[1], "LeftButton")
assert(SEARCHED.text == "Mace of Mending" and SEARCHED.mode == 1 and has("clica de novo"), "1o clique: maça")
rows[1].scripts.OnClick(rows[1], "LeftButton")
assert(SEARCHED.text == "Tome of Knowledge", "2o clique: tomo")
pick(f, "Back")
rows = shownRows(f)
rows[1].scripts.OnClick(rows[1], "LeftButton")
assert(SEARCHED.text == "Dervish Cape" and has("Pega o Dervish Cape of Healing"), "sufixo: busca o nome base e avisa")

-- Papel: dano mágico muda os pesos (a maça e o tomo só têm cura).
choose(f.role, 2)
assert(db.role == "spell" and FU.ctx.role == "spell" and f.role.label.text == "Dano mágico", "papel: dano mágico")
choose(f.role, 1)
assert(db.role == "heal" and FU.ctx.role == "heal", "volta pra cura")
noErrors()

-- /reload: varredura guardada, filtros salvos, sem varrer de novo.
FindUpgradeFrame = nil
fire("AUCTION_HOUSE_CLOSED")
clearEvents()
FU = loadAddon()
fire("PLAYER_LOGIN")
SlashCmdList.FINDUPGRADE("")
assert(REPLICATED == 1, "sem leiloeiro não devia varrer")
f = FindUpgradeFrame
assert(f and f.shown and FindUpgradeDB.plus == 5 and FindUpgradeDB.weaponMode == "pair", "abre com os filtros salvos")
assert(#FU.res.weapon == 1 and near(FU.res.weapon[1].gain, 7.7) and FU.res.Shoulder[1].parts[1].g.quality == 2, "mesma conta")

-- Faca de 1 mão (+1 Int +9 cura +3 dano) sem off-hand: a maça +2 Int +10 SP só dá +1,9 e não
-- entra em combo; a off-hand entra com a faca dele ("já tem").
do
  local w = FU.ROLES.heal.w
  local ctx2 = { ci = FU.CLASSES.PRIEST, rs = FU.ROLES.heal, w = w, min = 2, level = 13, money = 100000, twoHand = false, cand = {}, w2h = {},
    eq = { MainHand = { link = "faca", name = "Carving Knife of Healing", id = 2140, s = { int = 1, heal = 9, dmg = 3 }, score = 9.9 },
      OffHand = { name = "vazio", score = 0, s = {} } },
    wmh = { { g = { id = 2079, name = "Sergeant's Warhammer of Magic" }, s = { int = 2, heal = 10, dmg = 10 }, score = 11.8, price = 933, req = 12 } },
    woh = { { g = { id = 5001, name = "Tome of Knowledge" }, s = { int = 6, spi = 4, heal = 8 }, score = 15.8, price = 800, req = 13 } } }
  local rows2 = {}
  FU.weaponRows(ctx2, { maxLevel = 23, weaponMode = "all" }, rows2)
  assert(#rows2 == 1 and rows2[1].parts[1].kept and rows2[1].parts[2].g.id == 5001 and near(rows2[1].partGain[2], 15.8),
    "só a faca dele + o tomo; a maça (+1,9) fica fora: " .. #rows2)
end

-- Reino sem varredura há 14 dias sai no login.
FindUpgradeAH["Velho - Horde"] = { at = time() - 20 * 86400, gear = "x" }
fire("PLAYER_LOGIN")
assert(FindUpgradeAH["Velho - Horde"] == nil and FindUpgradeAH["Normal - Alliance"], "reino velho sai, o atual fica")
noErrors()
`;

run('priest de cura (varredura própria)', setup, driver);
