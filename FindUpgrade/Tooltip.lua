-- FindUpgrade · Tooltip.lua
-- No tooltip de qualquer item que ele pode equipar (bolsa, vendedor, leilão, loot, recompensa de
-- quest, link no chat): se é upgrade pro papel dele e quanto, contra a peça que sairia. A ideia
-- veio do "Upgrade tips everywhere" do Wishwell, mas mais direta: o número e o que muda, sem
-- explicação em frase.
--
--   Upgrade +7,7 · no lugar de Staff of Westfall
--   +6 Int  +4 Spi  -40 Cura
--   Drop: Mr. Smite · Deadmines · 2%
--
-- A nota é a mesma da janela (FU.scoreFor, pesos do papel escolhido). O equipado é lido uma vez
-- e guardado até ele trocar de peça, subir de level ou mudar o papel na janela.

local _, FU = ...
FU = FU or FindUpgrade

local tip = {}
FU.tip = tip

local cached -- { ctx, role }

function tip.reset() cached = nil end

function tip.ctx()
  local role = FU.db().role
  if cached and cached.role == role then return cached.ctx end
  local ctx = FU.context()
  -- Peça equipada ainda sem dados (logo depois do /reload): não guarda, lê de novo no próximo.
  if (ctx.missing or 0) == 0 then cached = { ctx = ctx, role = role } end
  return ctx
end

local LABEL = { heal = "Cura", dmg = "Dano", str = "Str", agi = "Agi", int = "Int", spi = "Spi", mp5 = "mp5",
  sta = "Sta", ap = "AP", rap = "RAP", def = "Def", blockValue = "bloqueio", dps = "dps" }
local PCT = { crit = "crít", hit = "acerto", spellcrit = "crít mág", spellhit = "acerto mág", dodge = "esquiva",
  parry = "aparar", block = "bloqueio" }

local function num(v)
  if math.abs(v - math.floor(v + 0.5)) < 0.05 then return tostring(math.floor(v + 0.5)) end
  return (string.format("%.1f", v):gsub("%.", ","))
end

-- "+6 Int  +4 Spi  -40 Cura": só os stats que pesam pro papel, do que pesa mais pro que pesa menos.
-- Cura e dano iguais (spell power) aparecem uma vez, como SP.
function tip.delta(s, old, w)
  old = old or {}
  local keys = {}
  for k in pairs(w) do
    if k ~= "armor" then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b)
    if w[a] ~= w[b] then return w[a] > w[b] end
    return a < b
  end)
  local function d(k) return (s[k] or 0) - (old[k] or 0) end
  local sp = w.heal and w.dmg and d("heal") == d("dmg")
  local parts = {}
  for _, k in ipairs(keys) do
    local v = d(k)
    local min = (k == "dps") and 0.1 or 0.5
    if math.abs(v) >= min and not (sp and k == "dmg") then
      local sign = v > 0 and "+" or "-"
      local label = (sp and k == "heal") and "SP" or LABEL[k]
      if PCT[k] then
        parts[#parts + 1] = sign .. num(math.abs(v)) .. "% " .. PCT[k]
      else
        parts[#parts + 1] = sign .. num(math.abs(v)) .. " " .. (label or k)
      end
    end
  end
  return table.concat(parts, "  ")
end

local function sum(a, b)
  local t = {}
  for k, v in pairs(a or {}) do t[k] = v end
  for k, v in pairs(b or {}) do t[k] = (t[k] or 0) + v end
  return t
end

-- O que um item vale pra ele, ou nil (não equipa, a classe não usa, sem dados ainda).
-- { equipped } · { needsMainHand, score } · { gain, vs, delta, req, note }
function tip.evaluate(link)
  local id = tonumber(link:match("item:(%d+)") or "")
  if not id then return nil end
  local _, _, _, loc, _, classID, subID = C_Item.GetItemInfoInstant(id)
  if not loc or loc == "" then return nil end
  local ctx = tip.ctx()
  local g = { id = id, link = link, loc = loc, class = classID, sub = subID }
  local slots = FU.slotsFor(g, ctx)
  if not slots then return nil end
  for _, n in ipairs(slots) do
    if ctx.eq[n] and ctx.eq[n].id == id then return { equipped = true } end
  end
  local s = FU.stats(link)
  if not s then return nil end
  local kind = FU.weaponKind(g)
  local slot = (kind == "oh" and "OffHand") or (kind and "MainHand") or slots[1]
  local score = FU.scoreFor(s, ctx, slot)
  local req = select(5, C_Item.GetItemInfo(link))
  local m, o = ctx.eq.MainHand, ctx.eq.OffHand
  local vsScore, vsName, vsStats, note
  if kind == "2h" then
    vsScore = m.score + (o.link and o.score or 0)
    vsName = (m.link and m.name or "mão vazia") .. (o.link and (" + " .. o.name) or "")
    vsStats = sum(m.s, o.link and o.s)
  elseif kind == "mh" then
    vsScore, vsName, vsStats = m.score, (m.link and m.name or "mão vazia"), m.s
    if ctx.twoHand then note = "sem off-hand; com uma, soma a dela" end
  elseif kind == "oh" then
    -- Com arma de 2 mãos, off-hand sozinha não entra: só junto com uma de 1 mão.
    if ctx.twoHand then return { needsMainHand = true, score = score, req = req } end
    vsScore, vsName, vsStats = o.score, (o.link and o.name or "nada na off-hand"), o.s
  else
    local b = FU.base(ctx, FU.GROUP_OF[slots[1]])
    vsScore, vsName, vsStats = b.score, b.name, ctx.eq[b.slot] and ctx.eq[b.slot].s
  end
  -- O DPS só entra no "o que muda" onde ele conta (a wand pra quem cura, não a staff).
  local wd = ctx.w
  local by = ctx.rs and ctx.rs.dpsBy
  if wd.dps and by and (by[slot] or 0) == 0 then
    wd = {}
    for k, v in pairs(ctx.w) do if k ~= "dps" then wd[k] = v end end
  end
  return { gain = score - vsScore, vs = vsName, delta = tip.delta(s, vsStats, wd), req = req, note = note,
    level = ctx.level, id = id }
end

-- As linhas do tooltip: { texto, r, g, b }.
function tip.lines(link)
  local e = tip.evaluate(link)
  if not e or e.equipped then return nil end
  local out = {}
  local lvl = (e.req and e.level and e.req > e.level) and string.format(" |cffff8040· pede lvl %d|r", e.req) or ""
  if e.needsMainHand then
    out[#out + 1] = { string.format("Off-hand: +%s junto com uma arma de 1 mão (tu usa 2 mãos)", FU.num(e.score)) .. lvl,
      0.8, 0.8, 0.8 }
    return out
  end
  if e.gain >= 0.5 then
    out[#out + 1] = { string.format("Upgrade +%s · no lugar de %s", FU.num(e.gain), e.vs) .. lvl, 0.25, 1, 0.25 }
  elseif e.gain <= -0.5 then
    out[#out + 1] = { string.format("Pior que %s (-%s)", e.vs, FU.num(-e.gain)) .. lvl, 0.85, 0.45, 0.45 }
  else
    out[#out + 1] = { "Igual ao que tu usa (" .. e.vs .. ")" .. lvl, 0.7, 0.7, 0.7 }
  end
  if e.delta ~= "" and math.abs(e.gain) >= 0.5 and FU.db().tipStats ~= false then out[#out + 1] = { e.delta, 0.75, 0.75, 0.75 } end
  if e.note and e.gain < 0.5 then out[#out + 1] = { e.note, 0.6, 0.6, 0.6 } end
  -- De onde vem, só no upgrade (o que já está na bolsa não precisa).
  if e.gain >= 0.5 and FU.db().tipSource ~= false and FU.src and FU.src.forItem then
    for _, l in ipairs(FU.src.lines(FU.src.forItem(e.id)) or {}) do out[#out + 1] = { l, 0.6, 0.6, 0.6 } end
  end
  return out
end

-- Tooltip principal e o de link no chat; os de comparação (ShoppingTooltip) ficam de fora.
local function onTooltip(tooltip)
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  if FU.db().tooltipOff or not tooltip.GetItem then return end
  local _, link = tooltip:GetItem()
  if not link then return end
  local ok, lines = pcall(tip.lines, link)
  if not (ok and lines and #lines > 0) then return end
  for _, l in ipairs(lines) do tooltip:AddLine(l[1], l[2], l[3], l[4], true) end
  if tooltip.Show then tooltip:Show() end
end
tip.onTooltip = onTooltip

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onTooltip)
elseif GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnTooltipSetItem", onTooltip)
  if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", onTooltip) end
end

-- Trocou peça ou subiu de level: o equipado muda. Pegou, largou ou entregou quest: a fonte muda.
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function() tip.reset() end)
for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE", "QUEST_ACCEPTED",
  "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
  pcall(ev.RegisterEvent, ev, e)
end
