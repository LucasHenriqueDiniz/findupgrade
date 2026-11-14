# Arquitetura

O addon é a pasta `FindUpgrade/`. O `FindUpgrade.toc` carrega os arquivos nesta ordem, e todos dividem a mesma tabela (`local _, FU = ...`). Ela também fica visível como `FindUpgrade` no `/dump`.

| Arquivo | O que tem |
|---|---|
| `Data.lua` | Tabelas fixas: slots, classes (armadura, armas, escudo, duas armas, papéis), papéis com os pesos, chaves do `GetItemStats`, nomes de stat do tooltip, grupos da coluna da esquerda e moedas |
| `Util.lua` | O que todo mundo usa: escolhas salvas (`FU.db`), preço máximo em cobre, dinheiro em texto, números com vírgula |
| `Stats.lua` | Os stats de uma peça (`GetItemStats` + tooltip), a nota dela pro papel (`FU.scoreFor`), o item que pede profissão ou reputação (`FU.blocked`), stats e pesos em texto |
| `Scan.lua` | O equipamento à venda (`FU.ah`): a varredura própria ou a do VaultSync |
| `SourcesData.lua` | O banco de fontes (`FU.SOURCES`): de onde vem cada item fora do leilão. Gerado por `tools/build-sources.mjs`; não edite à mão |
| `Sources.lua` | Lê o banco de fontes pro modo Quests e dungeons (`FU.src`). Ver [fontes.md](fontes.md) |
| `Engine.lua` | A conta: equipado, candidatos por slot, combos de arma, filtros e resultados |
| `Tooltip.lua` | A linha de upgrade no tooltip dos itens (`FU.tip`): mesma nota da janela, contra a peça que sairia, com a diferença dos stats e de onde vem. Usa o `TooltipDataProcessor`, ou o `OnTooltipSetItem` se o cliente não tiver. Desliga com `FindUpgradeDB.tooltipOff` |
| `UI.lua` | A janela, os dropdowns, os cliques, o skin, os eventos, o `/findupgrade` e os botões de abrir (leiloeiro, janela do personagem, atalho, menu de addons) |
| `Config.lua` | A tela de configurações (`FU.cfg`): engrenagem da janela, `/fu config` e uma página em Opções → AddOns. Grava em `FindUpgradeDB`: `tooltipOff`, `tipStats`, `tipSource`, `charButton`, `ahButton`, `autoScan`, `minGain` e `weights[papel][stat]` |
| `Bindings.xml` | O atalho de teclado (o jogo lê sozinho, não vai no `.toc`) |

## O caminho dos dados

```
AH ──ReplicateItems──▶ Scan.lua ──(FindUpgradeAH)──▶ FU.ah.load()
                                                        │
equipado ──GetInventoryItemLink──▶ FU.context() ◀───────┘
                                        │ evaluate (em pedaços de 60 por frame)
                                        ▼
                        ctx.cand (por slot) · ctx.w2h / ctx.wmh / ctx.woh (armas)
                                        │ FU.results(ctx, filtros)
                                        ▼
                                  linhas da janela
```

1. **Varredura.** O `FU.ah.start()` chama `C_AuctionHouse.ReplicateItems`. Quando chega o `REPLICATE_ITEM_LIST_UPDATE`, lê os anúncios em pedaços de 4000 por frame, pra não travar o jogo. Guarda só o que a classe usa: um anúncio por item+sufixo, com o menor preço. Item que ainda não está em cache vem sem link. O addon pede os dados e relê até 4 vezes.
2. **Contexto.** O `FU.context()` lê a classe, o papel, o level, o gold e cada peça equipada, com a nota de cada uma. Logo depois do `/reload`, a peça equipada pode vir sem dados (nome vazio). O `compute` espera até cerca de 3 segundos.
3. **Candidatos.** Cada peça à venda que a classe usa e que pede até o level + 10 vira candidata. No slot normal, só entra se ganha do equipado por pelo menos o mínimo do papel. Arma entra sempre, porque é nos combos que se decide.
4. **Resultados.** O `FU.results()` aplica os filtros (level, preço por peça, gold) e monta os combos de arma. Mexer em filtro não recalcula as notas, só refaz essa parte.

## O que fica salvo

| SavedVariable | Onde | Campos |
|---|---|---|
| `FindUpgradeAH` | conta | `["<reino> - <facção>"] = { at, date, total, missing, gear }`. O `gear` é uma string, um item por linha, com link, preço, anúncios, level, slot, classe, subclasse e qualidade separados por tab. Ocupa bem menos que tabela. Reino sem varredura há 14 dias sai no login |
| `FindUpgradeDB` | personagem | `mode` (`"ah"` ou `"src"`), `srcKind` (tudo, quest, dungeon), `plus` (level), `maxValue` + `maxUnit` (preço máximo), `fitGold`, `group` (aba), `weaponMode`, `role`, `pos` (posição da janela), `statKeys` (chaves de stat que o cliente usa; `false` = não entendida) e `eq` (o que a janela leu do equipado, pra conferir) |

## `FU.ah`: de onde vem o AH

O `Scan.lua` decide na hora de carregar. Os dois modos têm a mesma cara:

| Função | O que faz |
|---|---|
| `FU.ah.mode` | `"proprio"` ou `"vaultsync"` |
| `isOpen()` | o leiloeiro está aberto? |
| `scanning()` | tem varredura rodando? |
| `wait()` | segundos até liberar a próxima (limite de 15 min) |
| `start(after)` | varre; `after` roda no fim |
| `load()` | `gear, date`: a varredura desta sessão ou a guardada |
| `at()` | `at, date` da última varredura |
| `status()` | texto do progresso, ou `nil` |
| `listeners` | funções chamadas quando uma varredura termina |

**Contrato com o VaultSync.** Se existir o `VaultSyncAPI` com `loadGear`, `startScan` e `ahOpen` (desde 14/11 quem completa isso é o addon pessoal VaultAH, que saiu do VaultSync; por isso ele está no `OptionalDeps`, pra carregar antes), o FindUpgrade não varre sozinho. Ele usa `loadGear`, `scanAt`, `startScan`, `ahOpen`, `scanning` e `scanWait`, e se registra em `VaultSyncAPI.listeners`. O formato do `gear` é o mesmo. O teste `tests/e2e-vaultsync.cjs` simula esse contrato.

## Eventos

| Evento | Quem | Pra quê |
|---|---|---|
| `AUCTION_HOUSE_SHOW` / `_CLOSED` | Scan, UI | leiloeiro aberto; botão Upgrades |
| `REPLICATE_ITEM_LIST_UPDATE` | Scan | a varredura chegou (a nossa ou a do Auctionator). Fora de uma varredura nossa, só conta se a última foi há mais de 15 min, senão vira loop |
| `PLAYER_LOGIN` | Scan | apaga reino velho |
| `PLAYER_MONEY` | UI | gold novo nos filtros, sem recalcular |
| `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_LEVEL_UP` | UI | recalcula, com 1s de espera |

## Visual

A janela tem um fundo escuro próprio. Os widgets não são templates da Blizzard: segmentados, dropdowns e linhas são frames simples. Por isso ela fica igual em qualquer cliente.

- **EllesmereUI:** `EllesmereUI.RegisterSkin("FindUpgrade", fn)` entrega as primitivas `S.Shell`, `S.Button`, `S.EditBox`, `S.Checkbox`, `S.CloseButton`, `S.Font`, `S.SquareIcon` e `S.GetAccentColor`. O documento delas está na pasta do EllesmereUI (`SKINNING_API.md`).
- **ElvUI:** se o EllesmereUI não pintou, usa o módulo `Skins` do ElvUI (`HandleButton`, `HandleEditBox`, `HandleCheckBox`, `HandleCloseButton` e `SetTemplate("Transparent")` na janela). **Não foi testado num ElvUI de verdade**; os erros ficam presos no `pcall`.

Os dropdowns (moeda, papel) são feitos à mão, em vez do `UIDropDownMenu` da Blizzard, que muda entre clientes e espalha taint.
