# Dados de terceiros

O FindUpgrade é GPL-3.0 (ver `LICENSE`). Ele já foi MIT até a versão 1.3.0. Mudou na 1.4.0 porque o banco de fontes do modo **Quests e dungeons** (`FindUpgrade/SourcesData.lua`) junta dados que vêm de projetos GPL.

O banco é gerado por `tools/build-sources.mjs` a partir das cópias que ficam em `tools/fontes/`:

| Fonte | Versão | Licença | O que entra no banco |
|---|---|---|---|
| **LootGoblin**, de LeetGeek ([CurseForge](https://www.curseforge.com/wow/addons/lootgoblin)) | 1.3.0 | MIT, segundo a página do CurseForge. Os dados que ele traz têm as licenças próprias, em `tools/fontes/lootgoblin/`: QuestieDB (GPL-3.0), um catálogo GPL-2.0, outro MIT (© 2019 Nakroma) e RandomProperties (GPL-3.0) | Itens equipáveis com as fontes: quest com o id, boss de dungeon, vendedor e intendente de reputação. Também o level pedido, a facção e as quests (nome, level, zona) |
| **Wishwell Forever**, de sockss / Squirt ([CurseForge](https://www.curseforge.com/wow/addons/wishwell-forever)) | 1.4.2 | GPL-3.0. Junta dados do wowtbc.gg, do Questie (GPL-3.0) e do AtlasLootClassic | A faixa de level das dungeons, a % de drop dos bosses, os itens de dungeon que faltavam no LootGoblin e o nome das zonas |

A origem desses dados é o [Wowhead Forever](https://www.wowhead.com/forever), o [QuestieDB](https://github.com/Questie/QuestieDB) e o próprio cliente do jogo.

**O que não entra:** o banco do **GearQuest Forever**. A licença dele é "All Rights Reserved", e tudo o que o FindUpgrade usa dele (quest, boss, vendedor, facção) os outros dois também têm.

Os arquivos em `tools/fontes/` são cópias sem alteração, guardadas pra dar pra gerar o banco de novo e com as licenças junto.
