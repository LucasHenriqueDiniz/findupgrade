# Desenvolvimento

## Testes fora do jogo

Os testes rodam o código de verdade do addon numa VM Lua ([fengari](https://github.com/fengari-lua/fengari)), com a API do WoW simulada. Precisa de Node 18 ou mais novo.

```bash
cd tests
npm install
npm test
```

| Arquivo | O que testa |
|---|---|
| `check.cjs` | sintaxe Lua 5.1 (a do WoW) de todo `.lua` |
| `e2e-priest.cjs` | priest de cura sem o VaultSync: varredura própria, notas, filtros, moeda, combos, cliques, papel, `/reload`, apagar reino velho |
| `e2e-warrior.cjs` | warrior: 2 mãos × duas armas × arma + escudo, crítico e AP do tooltip, tank, placa no 40 |
| `e2e-vaultsync.cjs` | com o VaultSync: usa a varredura dele (o contrato do `VaultSyncAPI`) |
| `e2e-sources.cjs` | Quests e dungeons: o banco de verdade carrega, e com um banco pequeno de teste: facção, quest feita, level do item, filtro de tipo e o botão da janela do personagem |
| `harness.cjs` | carrega os arquivos na ordem do `.toc` e roda um teste |
| `stubs.lua` | a API do WoW simulada: frames, eventos, timers, `C_Item`, `C_TooltipInfo`, `C_AuctionHouse` |

Num teste, você define antes `ITEMS[id] = { nome, equipLoc, classe, subclasse, level, stats, linhas do tooltip }`, `EQUIP[slot] = link(id)` e `LISTINGS = { { id, preço, link } }`, mais `CLASS`, `LEVEL` e `MONEY`. Depois chama `loadAddon()` e dispara os eventos com `fire(...)`. Os timers (`C_Timer.After`) rodam na hora, dentro do `fire`.

O GitHub roda os testes a cada push (`.github/workflows/tests.yml`).

## Banco de fontes

`node tools/build-sources.mjs` gera o `FindUpgrade/SourcesData.lua` a partir de `tools/fontes/`. Ver [fontes.md](fontes.md) e [THIRD_PARTY.md](../THIRD_PARTY.md).

## Testar no jogo

1. Copie a pasta `FindUpgrade` pro `Interface\AddOns` do `_forever_`. Faça um link simbólico se for mexer muito: `mklink /D` no Windows.
2. Arquivo novo ou mudança no `.toc` pede **fechar e abrir o jogo**. Mudança só em `.lua` vai com `/reload`.
3. `/dump FindUpgrade.ctx`, `/dump FindUpgrade.res` e `/dump FindUpgradeDB.statKeys` ajudam a ver o que ele leu.

## Estilo

- Lua 5.1 (o WoW), sem `goto` e sem divisão inteira.
- Comentários e textos da janela em português. Nomes de função da API ficam como são.
- Todo arquivo começa com `local _, FU = ...`. Nada de variável global além de `FindUpgrade`, `FindUpgradeAH`, `FindUpgradeDB` e dos `SLASH_`.
- Mudou uma regra (peso, classe, filtro)? Escreva o teste que mostra o caso.

## Versão

Mude `## Version` no `.toc`, `FU.VERSION` no `Data.lua` e o `CHANGELOG.md`.
