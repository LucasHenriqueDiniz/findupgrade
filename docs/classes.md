# Classes

Fica tudo em `FU.CLASSES`, no `Data.lua`. É a base do Classic. Se o Forever mudar alguma coisa, é aqui que se ajusta.

| Campo | O que é |
|---|---|
| `armor` | a armadura que a classe usa (1 pano, 2 couro, 3 malha, 4 placa) |
| `armor40` | a armadura a partir do level 40 |
| `shield` | usa escudo |
| `dw` | luta com duas armas: arma de 1 mão e arma de off-hand entram como secundária |
| `offhand` | segura item de mão secundária (livro, orbe) |
| `weapons` | as subclasses de arma que a classe usa |
| `roles` | papéis da classe; o primeiro é o padrão |

## Tabela

| Classe | Armadura | Escudo | Duas armas | Armas |
|---|---|---|---|---|
| Warrior | malha → placa no 40 | sim | sim | machado, maça e espada (1 e 2 mãos), lança, cajado, punho, adaga, arco, arma de fogo, besta, arremesso |
| Paladino | malha → placa no 40 | sim | não | machado, maça e espada (1 e 2 mãos), lança |
| Caçador | couro → malha no 40 | não | sim | machado e espada (1 e 2 mãos), lança, cajado, punho, adaga, arco, arma de fogo, besta, arremesso |
| Ladino | couro | não | sim | maça e espada de 1 mão, punho, adaga, arco, arma de fogo, besta, arremesso |
| Priest | pano | não | não | maça de 1 mão, cajado, adaga, varinha |
| Shaman | couro → malha no 40 | sim | não | machado e maça (1 e 2 mãos), cajado, punho, adaga |
| Mago | pano | não | não | espada de 1 mão, cajado, adaga, varinha |
| Warlock | pano | não | não | espada de 1 mão, cajado, adaga, varinha |
| Druida | couro | não | não | maça (1 e 2 mãos), cajado, punho, adaga |

Subclasse de arma (classe 2 do `GetItemInfoInstant`):

| Subclasse | Arma |
|---|---|
| 0 / 1 | machado de 1 / 2 mãos |
| 2 | arco |
| 3 | arma de fogo |
| 4 / 5 | maça de 1 / 2 mãos |
| 6 | lança (polearm) |
| 7 / 8 | espada de 1 / 2 mãos |
| 10 | cajado |
| 13 | arma de punho |
| 15 | adaga |
| 16 | arremesso |
| 18 | besta |
| 19 | varinha |

Armadura (classe 4): 0 diversos (anel, colar, trinket, livro), 1 pano, 2 couro, 3 malha, 4 placa, 6 escudo.

## Mudar ou acrescentar

- **Uma classe passou a usar outra arma:** ponha a subclasse no `set({ ... })` dela.
- **Um papel novo** (ex.: um warrior que quer pesar mais a Stamina): crie uma entrada em `FU.ROLES` com `label`, `min`, `w` e `dpsBy`, e ponha a chave nos `roles` da classe. O papel aparece sozinho no dropdown.
- **Uma classe nova:** uma entrada em `FU.CLASSES` com a chave em inglês, em maiúsculas, que o `UnitClass` devolve (ex.: `DEATHKNIGHT`).

Depois de mudar, rode os testes (ver [desenvolvimento.md](desenvolvimento.md)).
