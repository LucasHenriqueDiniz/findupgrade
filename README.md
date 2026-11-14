# FindUpgrade

Addon de **WoW Forever** que procura **upgrade de equipamento**: o que está **à venda no leilão (AH)** e o que vem de **quest e dungeon**. Ele compara cada peça com o que você está usando e mostra o que vale a pena, por slot, já filtrado pelo seu level e pelo seu dinheiro.

- **Lê o AH inteiro de uma vez**, com a varredura completa da Blizzard. Ela é liberada uma vez a cada 15 minutos e leva de 1 a 2 minutos.
- **Entende o seu papel.** Cada stat pesa de um jeito: Cura, Dano mágico, DPS de força (warrior), DPS de agilidade, Caçador e Tank. Dá pra trocar o papel na janela.
- **Sabe o que a sua classe usa:** tipo de armadura (malha até o 40, placa depois), armas, escudo e duas armas.
- **Armas em combo.** Compara arma de 2 mãos com 1 mão + secundária (escudo, livro ou outra arma). Usa a peça que você já tem quando ela ainda vale.
- **Tem filtros:** level (só o seu, até +3, +5 ou +10), **preço máximo por peça** (em ouro, prata ou cobre) e "só o que cabe no meu gold".
- **Busca no AH com um clique.** Shift+clique põe o link no chat.
- **Quests e dungeons:** recompensa de quest, drop de boss (com a % de drop), rare e vendedor. Usa o banco do [GearQuest Forever](https://www.curseforge.com/wow/addons/gearquest-forever) e/ou do [Wishwell Forever](https://www.curseforge.com/wow/addons/wishwell-forever), se você tiver um deles instalado. Esconde a quest que você já fez e a recompensa da outra facção. Ver [docs/fontes.md](docs/fontes.md).

## Instalar

1. Baixe o zip pelo **Code → Download ZIP** desta página, ou pela aba Releases se tiver uma.
2. Abra o zip e copie a pasta **`FindUpgrade`** (a que tem o `FindUpgrade.toc` dentro) para:
   ```
   World of Warcraft\_forever_\Interface\AddOns\
   ```
3. **Feche e abra o jogo.** Addon novo não aparece só com `/reload`.

## Usar

1. Abra o leiloeiro e clique em **Gear upgrade** no canto de cima, ou digite `/findupgrade` (ou `/fu`). No alto da janela, troque entre **Leilão** e **Quests e dungeons** (`/fu quests` abre direto no segundo, sem precisar do leiloeiro).
2. Na primeira vez ele varre o AH inteiro. Isso leva de 1 a 2 minutos, e a janela se atualiza sozinha quando acaba.
3. **Esquerda:** os slots, com o maior ganho de cada um. **Tudo** mostra o melhor de cada slot e quanto dá comprando tudo junto.
4. **Direita:** as opções do slot. Clique numa linha para buscar no AH. Num combo de arma, o 1º clique busca a arma e o 2º a secundária, ou clique no ícone de cada peça.
5. **Em cima:**
   - o **Papel**, no canto direito;
   - o **level** (Meu lvl, +3, +5, +10);
   - o **Máx. por peça**: o número, mais a moeda no botão do lado;
   - **Só o que cabe no meu gold**.

   Tudo fica salvo por personagem.

O ganho é em **pontos**: a soma de cada stat da peça vezes o peso do seu papel, menos a do que está equipado. Passe o mouse em **Ganho** para ver os pesos. O detalhe está em [docs/pontuacao.md](docs/pontuacao.md).

Sem o leiloeiro aberto, a janela usa a última varredura do reino, que fica guardada. Varreduras com mais de 14 dias são apagadas.

## Classes

Todas as classes do Classic estão na tabela. O primeiro papel de cada uma é o padrão.

| Classe | Armadura | Papéis |
|---|---|---|
| Warrior | malha, placa no 40 · escudo · duas armas | DPS (força), Tank |
| Paladino | malha, placa no 40 · escudo | Cura, Tank, DPS (força) |
| Caçador | couro, malha no 40 · duas armas | Caçador |
| Ladino | couro · duas armas | DPS (agilidade) |
| Priest, Mago, Warlock | pano | Cura ou Dano mágico |
| Shaman | couro, malha no 40 · escudo | Cura, Dano mágico, DPS (força) |
| Druida | couro | Cura, Dano mágico, DPS (agilidade), Tank |

As armas de cada classe estão em [docs/classes.md](docs/classes.md).

## Idioma do jogo

Os atributos vêm do `GetItemStats`, que funciona em qualquer idioma. Mas parte dos stats só aparece no tooltip, e essa leitura é **em inglês**: crítico, acerto, defesa, bloqueio e a cura de alguns itens do Forever. Com o jogo em outro idioma, esses stats ficam de fora. Veja [docs/idioma.md](docs/idioma.md).

## Junto com outros addons

- **EllesmereUI** ou **ElvUI**: a janela pega o visual deles.
- **Auctionator**: se ele fizer a varredura completa com o AH aberto, o FindUpgrade aproveita.
- **VaultSync** (addon pessoal): se estiver ligado, o FindUpgrade usa a varredura dele em vez de varrer de novo.

## Documentação

- [docs/arquitetura.md](docs/arquitetura.md): como o código está dividido, o caminho dos dados e o que fica salvo.
- [docs/pontuacao.md](docs/pontuacao.md): pesos de cada papel, combos de arma, filtros e o que não é levado em conta.
- [docs/fontes.md](docs/fontes.md): o modo Quests e dungeons e o que ele lê do GearQuest e do Wishwell.
- [docs/classes.md](docs/classes.md): armadura, armas e papéis de cada classe, e como mudar.
- [docs/idioma.md](docs/idioma.md): o que depende do idioma do cliente.
- [docs/desenvolvimento.md](docs/desenvolvimento.md): testes fora do jogo e como contribuir.

## Licença

[MIT](LICENSE).
