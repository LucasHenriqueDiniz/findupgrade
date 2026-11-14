# Changelog

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
