# Quests e dungeons (fontes)

O modo **Quests e dungeons** mostra upgrades que não estão no leilão: recompensa de quest, drop de boss de dungeon, rare e vendedor. É um botão no alto da janela, ou `/fu quests`.

O jogo não tem essa lista, porque não existe função que diga o que cada boss dropa ou o que cada quest dá. Então o FindUpgrade **lê o banco de outro addon instalado**, dentro do jogo. Ele **não traz nem copia** esses dados: sem um desses addons, o modo avisa o que instalar.

| Addon | O que o FindUpgrade lê | Pra quê |
|---|---|---|
| [GearQuest Forever](https://www.curseforge.com/wow/addons/gearquest-forever) | `GearQuest.Data.<classe>ItemFacts`: por item da classe, de onde vem (`sourceType`), level pedido, zona, NPC, nome da quest e o texto de como pegar. Também `GearQuest.Data.questFaction`, que diz qual recompensa é só da Aliança ou só da Horda | a lista principal: quest, boss, rare e vendedor |
| [Wishwell Forever](https://www.curseforge.com/wow/addons/wishwell-forever) | `WishwellData.instances` e `.items`, as tabelas de loot das dungeons com a **% de drop**, e `WishwellData.quests`, com o id de cada quest | % de drop, itens de dungeon que o GearQuest não tem, e esconder as quests já feitas |

Os dois são opcionais. Com os dois, o mesmo item junta as informações: o boss e o texto vêm do GearQuest, e a % e a dungeon vêm do Wishwell.

## Como funciona

1. **`FU.src.load()`** (`Sources.lua`) monta a lista no mesmo formato do equipamento do leilão. Por isso o resto do addon (notas, slots, combos, filtros) não muda. O preço é zero e a fonte vai em `g.src`.
2. **Entra** quem é `quest_reward`, `boss_drop`, `rare_npc` ou `vendor` no GearQuest, e o loot de dungeon do Wishwell (sem as raids).
3. **Sai:**
   - a recompensa da outra facção;
   - a quest que você já fez, pelo `C_QuestLog.IsQuestFlaggedCompleted`, com o id que vem do Wishwell;
   - o world drop, a profissão e o item "sem fonte", porque não dá pra ir buscar.
4. **Level:** o do GearQuest é o level pedido do item. No item que só o Wishwell tem, até o cliente carregar os dados, vale o level mínimo da dungeon. Depois vale o do item.
5. **Dados dos itens:** são centenas de itens que o cliente ainda não viu. O cálculo pede os dados e espera até cerca de 16 segundos. O que não chegar aparece na linha de cima como "ainda sem dados". Abra a janela de novo daqui a pouco.

## Na janela

- **Filtro de tipo**, no lugar do preço: Tudo, Quests ou Dungeons.
- **Coluna da direita:** a fonte, por exemplo "Quest" ou "Hall of Thanes 12%".
- **Tooltip:** de onde vem, mais o texto de como pegar.
- **Clique:** escreve no chat de onde vem. **Shift+clique:** link.

## Limites

- **Item com sufixo aleatório** ("of Healing", "of the Owl") entra com os stats do item base, que são baixos. Por isso ele quase nunca aparece, mesmo quando o sufixo certo seria um bom upgrade.
- **O GearQuest só tem o banco da sua classe**, e não tem o do Paladino. Pra Paladino, só o Wishwell (drops de dungeon).
- **Sem o Wishwell**, não dá pra saber o id da quest, então as já feitas continuam aparecendo.
- **Os nomes das tabelas são internos desses addons.** Se uma versão nova mudar o formato, o modo para de achar o banco e avisa que não tem. Os testes (`tests/e2e-sources.cjs`) mostram o formato esperado.
