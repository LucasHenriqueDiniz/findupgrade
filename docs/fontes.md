# Quests, Dungeons e Vendedores (banco de fontes)

Os botões **Quests**, **Dungeons** e **Vendedores** mostram upgrades que não estão no leilão:
- recompensa de quest;
- drop de dungeon, com o boss e a % de drop quando o banco tem;
- vendedor;
- intendente de reputação.

Eles abrem pelos botões no alto da janela ou com `/fu quests`, `/fu dungeons` e `/fu vendedores`, e não precisam do leiloeiro. Os três dividem a mesma conta: trocar entre eles é na hora.

O jogo não tem essa lista, então ela vem num **banco que já vem junto com o addon**: `FindUpgrade/SourcesData.lua`, carregado em `FU.SOURCES`. Não precisa de nenhum outro addon instalado.

## O banco

É gerado por `tools/build-sources.mjs`. De onde vem cada dado e as licenças estão em [THIRD_PARTY.md](../THIRD_PARTY.md).

| Tabela | Linha |
|---|---|
| `instances[n]` | `{ nome, zona, level mínimo, level máximo }` |
| `quests[id]` | `{ nome, level pra pegar, level da quest, zona, raças, classes, todas antes, uma antes, quem dá }`. Raças e classes são bits (`raceID`/`classID` − 1; 0 = todas). "Antes" são os ids das quests que vêm antes. Vêm também as quests que só abrem a corrente. |
| `items[id]` | `{ level pedido, facção, fonte, fonte... }` |

- **Level pedido:** negativo quando o banco só sabe o level mínimo da dungeon. O level do item vem do jogo quando ele carrega.
- **Facção:** 0 = as duas, 1 = Aliança, 2 = Horda.
- **Fontes:**

| Fonte | Formato |
|---|---|
| Quest | `{ 1, id da quest }` |
| Dungeon | `{ 2, dungeon, boss ("Trash" = qualquer mob), % de drop ou nil }` |
| Vendedor | `{ 3, NPC, zona, facção }` |
| Intendente de reputação | `{ 4, NPC, zona, facção }` |
| Quest de dungeon sem o id | `{ 5, dungeon }` |

Em 16/11/2026, o banco tinha 4.226 itens, 2.420 quests e 28 dungeons, em 463 KB. Dos drops de dungeon, 496 têm a %.

**Pra gerar de novo** (com dados mais novos em `tools/fontes/` ou com o gerador mudado):

```bash
node tools/build-sources.mjs
```

## No jogo

- **`FU.src.load()`** (`Sources.lua`) monta os candidatos no mesmo formato do equipamento do leilão. Por isso notas, slots, combos e filtros são os mesmos. O preço é zero e a fonte vai em `g.src`.
- **Sai:**
  - a peça da outra facção;
  - o vendedor ou intendente da outra facção;
  - a recompensa de quest que você já fez (`C_QuestLog.IsQuestFlaggedCompleted`);
  - a quest de outra raça ou classe, e a que só abre por uma corrente que você não pega.
- **O level é o da fonte:** o maior entre o que o item pede e o level pra pegar a quest (ou o mínimo da dungeon). A Zandalarian Hero Charm não pede level, mas vem de quest de lvl 58: no lvl 24 ela não aparece.
- **Ordem em Quests:** primeiro as que estão no seu log ("No log"), depois as que dá pra pegar agora ("Pegar"), depois as que têm quest antes ("+2 quests"). Dentro de cada uma, o maior ganho primeiro. O tooltip diz quantas vêm antes e por qual a corrente começa (nome, level, quem dá e zona).
- **Item com mais de uma fonte** aparece em cada botão que vale pra ele (uma quest que também dropa em dungeon está em Quests e em Dungeons), e cada botão mostra a fonte dele. Vendedores junta vendedor e intendente de reputação.
- **Nome, qualidade e stats** vêm do jogo quando o item carrega. Uns segundos depois do login o addon já pede ao servidor os itens que você pode usar, e a janela abre cheia. O que ainda faltar vai entrando enquanto a janela está aberta ("carregando N itens...").
- **Clique** escreve no chat de onde vem. **Shift+clique** põe o link.

## Limites

- **Item com sufixo aleatório** ("of Healing") entra com os stats do item base, que são baixos. Ele quase nunca aparece, mesmo quando o sufixo certo seria um bom upgrade.
- **World drop e item de profissão** ficam de fora, porque não dá pra ir buscar. **Raid** também fica de fora por enquanto.
- **A % de drop** vem do Wishwell. Em muitas dungeons antigas, ela é o número do Classic, ainda sem a medição do Forever.
