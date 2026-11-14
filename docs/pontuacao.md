# Pontuação

## A conta

```
nota da peça  = Σ (stat × peso do papel)          (o DPS da arma × dpsBy[mão])
ganho         = nota da peça − nota do que ela substitui
```

- **Stats:** vêm do `C_Item.GetItemStats`, completados pelo tooltip. Por stat, vale o maior dos dois.
- **Slot com duas peças (anel, trinket):** a peça nova compete com a **mais fraca** das duas.
- **Arma de 2 mãos no lugar de 1 mão + secundária:** compete com a soma das duas.
- **Mínimo:** só aparece o que ganha pelo menos o `min` do papel. É 2 pontos nos papéis de feitiço (≈ +2 de cura) e 4 nos físicos (≈ 2 de Força).

## Pesos de cada papel

**Dá pra mudar** na tela de configurações (engrenagem → Pesos). O valor que você põe vale por cima do padrão, só no seu personagem e só naquele papel. Peso 0 tira o stat da conta, e "Voltar ao padrão" apaga as mudanças. O ganho mínimo também muda lá.

Ficam em `FU.ROLES`, no `Data.lua`.

| Stat | Cura | Dano mágico | DPS (força) | DPS (agilidade) | Caçador | Tank |
|---|---|---|---|---|---|---|
| Cura | 1 | | | | | |
| Dano mágico | | 1 | | | | |
| Int | 0,9 | 0,7 | | | 0,5 | |
| Spi | 0,6 | 0,3 | | | | |
| mp5 | 1,6 | 1,2 | | | 1 | |
| Sta | 0,25 | 0,4 | 0,5 | 0,5 | 0,5 | 2,5 |
| Str | | | 2 | 1 | | 1 |
| Agi | | | 1 | 2 | 2 | 1,5 |
| AP | | | 1 | 1 | 0,2 | 0,3 |
| AP de distância | | | | | 1 | |
| 1% crítico | | 10 (feitiço) | 20 | 20 | 20 | |
| 1% acerto | | 10 (feitiço) | 15 | 15 | 15 | 8 |
| 1 DPS de arma | | | 14 | 14 | 14 | 3 |
| Defesa | | | | | | 3 |
| 1% esquiva / aparar | | | | | | 25 |
| 1% bloqueio | | | | | | 15 |
| Valor de bloqueio | | | | | | 0,5 |
| Armadura | 0,004 | 0,004 | 0,02 | 0,02 | 0,02 | 0,1 |

O Warlock usa o Dano mágico com mais Sta (0,6) e Spi (0,4).

**De onde vêm os números físicos.** Estão em pontos de Attack Power, com as conversões do Classic:
- 1 de Força = 2 AP pro warrior;
- 20 de Agilidade ≈ 1% de crítico (e Agi não dá AP pro warrior);
- 1 de DPS de arma ≈ 14 AP.

Os guias do Forever pra warrior upando dão a mesma ordem: DPS da arma, depois Força/AP, Stamina, Agilidade e Armadura ([Warcraft Tavern: Warrior Leveling (Forever)](https://www.warcrafttavern.com/forever/guides/warrior-leveling/)). Os pesos de cura são os que o dono do addon usa no priest. São um ponto de partida: se um peso não bate com o que você sente no jogo, mude no `Data.lua`.

### `dpsBy`: quanto o DPS de cada arma conta

| Papel | Mão principal | Off-hand | Distância |
|---|---|---|---|
| DPS (força), DPS (agilidade) | 1 | 0,5 | 0,1 |
| Caçador | 0,15 | 0,05 | 1 |
| Tank | 1 | 0 | 0 |

No Classic, a arma da off-hand bate com metade do dano. O talento de duas armas aumenta isso, mas não está na conta.

## Combos de arma (aba Armas)

- **2 mãos:** cada arma de 2 mãos à venda contra o que está nas mãos (principal + secundária).
- **1 mão + secundária:** as 12 melhores armas de 1 mão × (nenhuma, as 12 melhores secundárias). A secundária é escudo, livro/orbe ou, pra quem luta com duas armas, outra arma. Entram também as peças que **você já tem** naquela mão, marcadas "(já tem)" e com preço zero.
- **Cada peça comprada tem que valer sozinha** contra a que ela tira da mão (pelo menos o `min`). Senão o combo certo é comprar só a outra peça. Exemplo: uma maça +1 de cura não entra num combo só porque a off-hand dele é boa.
- A mesma arma comprada aparece no máximo em 3 combos.
- O tooltip do combo mostra o ganho de cada peça sozinha.

## Filtros

| Filtro | Efeito |
|---|---|
| Level | só peças que pedem até o seu level + 0, 3, 5 ou 10 |
| Máx. por peça | cada peça comprada custa até o valor (no combo, vale peça por peça) |
| Só o que cabe no meu gold | o total da linha cabe no seu dinheiro |

Sem o filtro de gold, o que passa do seu dinheiro aparece com o preço em vermelho.

## O que não entra na conta

- **Bônus de set.** Trocar uma peça de set aparece marcado "set" e no tooltip "(quebra o set)", mas o bônus não é descontado.
- **Efeitos de "Use:" e "Chance on hit:"** (procs). Só os stats fixos contam.
- **A penalidade de acerto de quem luta com duas armas.** A off-hand conta 50% do DPS, mas os erros a mais não.
- **Velocidade da arma.** Conta só o DPS.
- **Armadura de outro tipo.** O warrior no 20 só vê malha, e no 40 só placa. É o tipo que a classe deve usar.
- **Resistências.**
