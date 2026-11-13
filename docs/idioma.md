# Idioma do cliente

Os stats de uma peça vêm de dois lugares:

1. **`C_Item.GetItemStats`.** Devolve chaves como `ITEM_MOD_INTELLECT_SHORT`, que são **iguais em qualquer idioma**. Força, Agilidade, Stamina, Intelecto, Espírito, AP, mp5, DPS da arma e armadura funcionam sempre.
2. **O tooltip** (`C_TooltipInfo`). Completa o que o `GetItemStats` não traz no Forever, lendo o texto.

| Do tooltip | Idioma |
|---|---|
| `+5 Intellect`, `+6 Spirit`... (atributos) | qualquer: o nome vem das strings do próprio jogo (`ITEM_MOD_INTELLECT_SHORT` = "Intelecto" no ptBR) |
| `+48 Spell Healing`, `+16 Spell Damage` | só inglês |
| `Equip: Increases healing done ... by up to 11` | só inglês |
| `Equip: Improves your chance to get a critical strike by 1%` (crítico, acerto, esquiva, aparar, bloqueio) | só inglês |
| `Equip: Increased Defense +7`, `Equip: +20 Attack Power` | só inglês |
| `150 Armor`, `12 Block`, `(10.0 damage per second)` | só inglês |
| `Requires Engineering (100)` (item que pede profissão ou reputação) | só inglês |

Com o jogo em outro idioma, os stats que só aparecem no tooltip ficam de fora, e o ganho de algumas peças sai menor. Pra mostrar o que o cliente devolve, o `FindUpgradeDB.statKeys` guarda as chaves do `GetItemStats` (`false` = chave que o mapa não entende).

**Pra traduzir:** os padrões ficam no `Stats.lua` (`EQUIP_PATTERNS` e as linhas de `FU.tooltipStats`) e no `Data.lua` (`FU.TIP_NAMES`). Dá pra acrescentar as frases em português ao lado das em inglês. Mande um PR com um print do tooltip.
