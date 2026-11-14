# Changelog

## 1.6.0 · 14/11/2026

- **Tela de configurações.** Abre pela engrenagem no alto da janela, com `/fu config` ou em Opções → AddOns. Tem:
  - a dica no tooltip, e o que ela mostra (stats, de onde vem);
  - os botões da janela do personagem e do leiloeiro;
  - varrer o leilão sozinho ao abrir;
  - o ganho mínimo;
  - o **peso de cada stat** do papel de agora, por cima do padrão, com "Voltar ao padrão".
- A caixinha "Dica no tooltip" saiu do alto da janela e foi pra tela de configurações.

## 1.5.0 · 14/11/2026

- **Dica no tooltip.** No tooltip de qualquer item que o personagem equipa aparece "Upgrade +X · no lugar de Y", "Pior que Y" ou "Igual". Embaixo, a diferença dos stats que pesam pro papel, o level pedido e, no upgrade, de onde vem. Usa a mesma nota da janela e fica no `Tooltip.lua`.
- **Caixinha "Dica no tooltip"** no alto da janela pra desligar (`FindUpgradeDB.tooltipOff`).

## 1.4.0 · 14/11/2026

- **Banco de fontes próprio.** `SourcesData.lua` tem 4.226 itens, 1.075 quests e 28 dungeons, em 272 KB. O modo Quests e dungeons não lê mais outro addon: não precisa do GearQuest nem do Wishwell instalados.
  - O banco junta o LootGoblin (quests com id, bosses, vendedores, reputação, facção) e o Wishwell Forever (% de drop, faixa das dungeons, itens que faltavam). É gerado por `tools/build-sources.mjs`.
  - O GearQuest não entra, porque a licença dele é "todos os direitos reservados".
- **Licença:** de MIT pra **GPL-3.0**, por causa dos dados GPL do banco. Ver `THIRD_PARTY.md`.
- **Fontes novas:** vendedor e intendente de reputação, com a facção. A quest já feita sai pelo id que vem do banco, sem depender de nome.

## 1.3.0 · 14/11/2026

- `VaultAH` no `OptionalDeps`: a varredura do VaultSync agora mora nesse addon pessoal, e o FindUpgrade precisa carregar depois dele pra usar a varredura em vez de varrer de novo.
- **Botão na janela do personagem.** É uma aba verde na borda direita (tecla C) que abre e fecha a janela no último modo, sem precisar do leiloeiro.
- **Atalho de teclado:** Opções → Atalhos → FindUpgrade (arquivo `Bindings.xml`).
- **Menu de addons do minimapa**, no cliente que tiver (`AddonCompartmentFunc` no `.toc`).

## 1.2.0 · 14/11/2026

- **Quests e dungeons.** Um modo novo, no alto da janela ou com `/fu quests`, mostra recompensa de quest, drop de boss com a % de drop, rare e vendedor. Lê, dentro do jogo, o banco do GearQuest Forever e/ou do Wishwell Forever, quando estão instalados; não copia nada. Tira a recompensa da outra facção e a quest já feita. Ver `docs/fontes.md`.
- O botão no leiloeiro agora se chama **Gear upgrade** e entra na fila de botões do topo (`VaultAHButtons`).

## 1.1.0 · 13/11/2026

- **Repo próprio.** O código foi dividido em `Data`, `Util`, `Stats`, `Scan`, `Engine` e `UI`, com documentação e testes.
- **Varredura própria.** Não precisa mais do VaultSync. Ela fica guardada por reino e facção em `FindUpgradeAH`, e o reino sem varredura há 14 dias sai. Com o VaultSync ligado, usa a dele.
- **Papéis:** Cura, Dano mágico, DPS (força), DPS (agilidade), Caçador e Tank, com um dropdown na janela.
- **Warrior e as outras classes físicas:**
  - armadura que muda no 40;
  - escudo;
  - duas armas, com a off-hand contando metade do DPS;
  - crítico, acerto, defesa, esquiva, aparar, bloqueio e AP lidos do tooltip;
  - todas as armas do Classic na tabela de cada classe.
- **Preço máximo:** o número, mais a moeda (ouro, prata ou cobre) num dropdown.
- **Skin do ElvUI**, além do EllesmereUI.
- **Ganho mínimo por papel.** No combo de arma, cada peça comprada tem que valer sozinha, e o tooltip mostra o ganho de cada uma.
- Os atributos do tooltip também são lidos no idioma do cliente.

## 1.0.0 · 13/11/2026

- Primeira versão, ainda dentro do vault e dependendo do VaultSync. Já tinha a janela por slot, os filtros de level e de gold, os combos de staff × arma + off-hand e o visual do EllesmereUI.
