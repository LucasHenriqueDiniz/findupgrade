# Quests e dungeons (banco de fontes)

O modo **Quests e dungeons** mostra upgrades que não estão no leilão:
- recompensa de quest;
- drop de dungeon, com o boss e a % de drop quando o banco tem;
- vendedor;
- intendente de reputação.

Ele abre pelo botão no alto da janela ou com `/fu quests`, e não precisa do leiloeiro.

O jogo não tem essa lista, então ela vem num **banco que já vem junto com o addon**: `FindUpgrade/SourcesData.lua`, carregado em `FU.SOURCES`. Não precisa de nenhum outro addon instalado.

## O banco

É gerado por `tools/build-sources.mjs`. De onde vem cada dado e as licenças estão em [THIRD_PARTY.md](../THIRD_PARTY.md).

| Tabela | Linha |
|---|---|
| `instances[n]` | `{ nome, zona, level mínimo, level máximo }` |
| `quests[id]` | `{ nome, level pra pegar, level da quest, zona }` |
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

Em 14/11/2026, o banco tinha 4.226 itens, 1.075 quests e 28 dungeons, em 272 KB. Dos drops de dungeon, 496 têm a %.

**Pra gerar de novo** (com dados mais novos em `tools/fontes/` ou com o gerador mudado):

```bash
node tools/build-sources.mjs
```

## No jogo

- **`FU.src.load()`** (`Sources.lua`) monta os candidatos no mesmo formato do equipamento do leilão. Por isso notas, slots, combos e filtros são os mesmos. O preço é zero e a fonte vai em `g.src`.
- **Sai:**
  - a peça da outra facção;
  - o vendedor ou intendente da outra facção;
  - a recompensa de quest que você já fez (`C_QuestLog.IsQuestFlaggedCompleted`).
- **Item com mais de uma fonte:** a coluna mostra a melhor, nesta ordem: quest ainda não feita, dungeon (a de maior %), vendedor, reputação. O filtro Quests/Dungeons olha todas.
- **Nome, qualidade e stats** vêm do jogo quando o item carrega. O cálculo pede os dados e espera até cerca de 16 segundos. O que não chegar aparece na linha de cima como "ainda sem dados".
- **Clique** escreve no chat de onde vem. **Shift+clique** põe o link.

## Limites

- **Item com sufixo aleatório** ("of Healing") entra com os stats do item base, que são baixos. Ele quase nunca aparece, mesmo quando o sufixo certo seria um bom upgrade.
- **World drop e item de profissão** ficam de fora, porque não dá pra ir buscar. **Raid** também fica de fora por enquanto.
- **A % de drop** vem do Wishwell. Em muitas dungeons antigas, ela é o número do Classic, ainda sem a medição do Forever.
