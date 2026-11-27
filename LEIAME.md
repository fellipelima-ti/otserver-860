# FolgaOt (8.60)

> O servidor se chamava Helblazer OT. Os nomes internos (serviço `helblazer`, banco `helblazer`, pasta `/opt/helblazer` e os arquivos `helblazer*`) continuam iguais, para não quebrar instalações que já existem.

Servidor de Tibia 8.60 baseado no **TFS 1.5, downgrade 8.60 do Nekiro**, com correções e o sistema de teleportes do FolgaOt.

| Configuração | Valor |
|---|---|
| Versão do cliente | 8.60 |
| Experiência | 50x (fixa) |
| Skill | 10x |
| Magic level | 5x |
| Loot | 2x |
| Tipo de mundo | PvP normal |
| Portas | 7171 (login) e 7172 (jogo) |

## Instalação no Ubuntu (22.04 ou 24.04)

Entre na VPS por SSH e rode:

```bash
sudo apt-get install -y git
sudo git clone https://github.com/fellipelima-ti/otserver-860.git /opt/helblazer
cd /opt/helblazer
sudo ./install.sh
```

O `install.sh` faz tudo:

1. Instala as dependências e o MariaDB
2. Compila o servidor
3. Cria o banco `helblazer` com uma senha aleatória e importa as tabelas
4. Gera o `config.lua` com o IP público da VPS (para forçar um IP: `sudo ./install.sh 1.2.3.4`)
5. Cria o serviço `helblazer`, que liga sozinho no boot e reinicia se o servidor cair
6. Libera as portas 7171 e 7172 no UFW

> Se a hospedagem tiver firewall no painel, libere lá também as portas **7171 e 7172 TCP**.

**Atenção:** o servidor precisa ficar em `/opt/helblazer` (ou outra pasta fora de `/root` e `/home`). O script recusa outras pastas porque o usuário do serviço não conseguiria ler os arquivos.

## Criar contas

Não existe "account manager" no TFS. Crie as contas pelo terminal:

```bash
sudo ./criar-conta.sh minhaconta minhasenha "Nome Do Char" knight
```

Vocações: `sorcerer`, `druid`, `paladin`, `knight`. O personagem começa no level 8, em Trekolt.

Para a **sua conta de administrador (God)**, coloque `--admin` no final:

```bash
sudo ./criar-conta.sh admin SenhaForte123 "GM Folga" sorcerer --admin
```

Mais tarde dá para instalar um site (MyAAC ou Znote AAC) para os jogadores criarem contas sozinhos.

## Comandos do dia a dia

| O que fazer | Comando |
|---|---|
| Ver o console ao vivo | `journalctl -u helblazer -f` |
| Reiniciar | `sudo systemctl restart helblazer` |
| Parar | `sudo systemctl stop helblazer` |
| Ligar | `sudo systemctl start helblazer` |
| Atualizar depois de mudanças no GitHub | `cd /opt/helblazer && sudo git pull && sudo ./install.sh` |

O `install.sh` pode ser rodado de novo sem perigo: ele **não apaga** o banco nem troca a senha.

## Como os jogadores conectam

Use o **OTClient** ou o cliente 8.60 com um IP changer:

- IP: o IP da VPS
- Porta: 7171
- Versão: 8.60

## Teleportes

Tudo fica em `data/scripts/helblazer/teleports.lua`.

**Portais físicos.** São criados automaticamente toda vez que o servidor liga:

- No templo de **Trekolt**: portais para Rhyves, Varak, Jorvik e Saund
- No templo de cada uma dessas cidades: um portal de volta para Trekolt

**Comando `!tp`.** Digite `!tp` no jogo para ver a lista e `!tp jorvik` para ir.

- Destinos: as 5 cidades e 10 hunts (trolls, rotworms, orcs, amazons, ghouls, cyclops, spiders, dragons, vampires e demons)
- Cada hunt tem level mínimo e algumas cobram gold
- Só funciona em protection zone (templo ou depot) e sem battle, para ninguém fugir de PvP
- GMs e Gods não têm restrição

Para adicionar um portal ou destino, basta incluir uma linha na tabela do arquivo. Para descobrir as coordenadas, fique no lugar dentro do jogo e digite `!pos`. Depois reinicie o servidor.

## Vocações e promoções

Não precisa de premium para promover. Existem duas promoções:

| Vocação | 1ª promoção (level 20, 20k) | 2ª promoção (level 150, 150k) |
|---|---|---|
| Sorcerer | Master Sorcerer | **Arch Sorcerer** |
| Druid | Elder Druid | **Ancient Druid** |
| Paladin | Royal Paladin | **Divine Paladin** |
| Knight | Elite Knight | **Supreme Knight** |

**Como promover:**
- Comando `!promote` mostra a próxima promoção, o level e o preço. `!promote sim` confirma.
- Ou fale `hi` e depois `promocao` com o NPC **The Forgotten King**, no templo de Trekolt (na frente do monumento, ao norte de onde o personagem nasce).
- O gold sai da mochila ou do banco.

Level e preço ficam em `data/lib/core/helblazer.lua` (`HELBLAZER_PROMOCOES`).

**Bônus da 2ª promoção** (em relação à 1ª):

| Vocação | HP/level | Mana/level | Regeneração | Outros |
|---|---|---|---|---|
| Arch Sorcerer / Ancient Druid | 5 | 35 (antes 30) | mana +50% | magic level sobe ~5% mais rápido |
| Divine Paladin | 12 (antes 10) | 17 (antes 15) | HP e mana +20% | distance sobe mais rápido, +5% de dano à distância |
| Supreme Knight | 18 (antes 15) | 5 | HP +50% | skills de melee e shielding sobem mais rápido, +5% de dano melee |

A 2ª promoção herda **todas** as magias, armas, wands/rods, poções e equipamentos da vocação. Os valores ficam em `data/XML/vocations.xml` (ids 9 a 12).

## Loja de jogador

Qualquer jogador pode montar uma loja na cidade. Um vendedor com a roupa dele, chamado **"Loja de Fulano"**, fica parado vendendo o tempo todo: com o dono online, offline ou caçando. A loja continua no lugar depois de reiniciar o servidor.

**Para vender:**

| Comando | O que faz |
|---|---|
| `!loja` | Mostra a ajuda e a situação da sua loja |
| `!loja abrir` | Coloca o vendedor no piso **à sua frente** (precisa ser protection zone da cidade, fora de casas) |
| `!loja vender 500` | Põe à venda o item do **slot da flecha** por 500 gold cada (se for um monte, vende o monte inteiro) |
| `!loja vender 20 coins` | O mesmo, cobrando em coins |
| `!loja itens` | Lista o que está à venda, com números |
| `!loja remover 2` | Devolve o item número 2 para a sua mochila |
| `!loja fechar` | Tira o vendedor do mapa e devolve os itens |

- Gold das vendas vai direto para o **banco** do vendedor; coins vão para a conta.
- O servidor fica com **10%** de cada venda.
- Se você estiver online, recebe uma mensagem a cada venda. Se estiver offline, recebe um resumo quando logar.
- Itens com texto, tempo de uso (anéis ligados), action id ou containers com coisas dentro não podem ser vendidos.

**Para comprar:** chegue perto do vendedor, fale `hi` e depois `trade` (itens em gold) ou `coins` (itens em coins). Abre a janela de trade normal de NPC. O número entre parênteses no nome do item é o estoque. Em gold, dá para pagar com o dinheiro da mochila ou do banco.

**Coins:** são uma moeda do servidor, guardada na conta (vale para todos os personagens dela).
- `!coins` mostra quantas você tem.
- O God dá coins com `/coins Nome, 100` (com número negativo, tira).

Taxa, número máximo de itens por loja e preço máximo ficam em `data/lib/core/helblazer_loja.lua` (`HELBLAZER_LOJA`). As tabelas do banco (`player_shops`, `player_shop_items`, `player_shop_sales` e a coluna `coins` de `accounts`) são criadas sozinhas quando o servidor liga.

## Tasks, recompensa diária, autoloot e criatura do dia

Sistemas inspirados em outros servidores 8.60. Tudo fica configurável em `data/lib/core/helblazer_sistemas.lua`.

**Tasks (`!task`).** Mostra as tasks do seu level, com o progresso.
- `!task dragons` começa uma task. Só dá para ter uma por vez, e pode repetir quantas vezes quiser.
- O progresso aparece a cada 10 kills e nas 5 últimas.
- Ao terminar, você ganha experiência, gold (no banco) e coins.
- `!task cancelar` desiste da task.
- **Task diária:** `!task diaria` aceita uma task sorteada para você no dia (entre as mais altas do seu level). Ela vale 1,5x a recompensa normal, mais 5 coins, e muda à meia-noite.

| Task | Kills | Level | Recompensa |
|---|---|---|---|
| Trolls | 100 | 8 | 15k exp, 2k gold |
| Rotworms | 100 | 8 | 20k exp, 2k gold |
| Orcs | 150 | 15 | 60k exp, 5k gold, 1 coin |
| Amazons | 150 | 25 | 120k exp, 8k gold, 2 coins |
| Ghouls | 150 | 30 | 180k exp, 10k gold, 2 coins |
| Cyclops | 200 | 40 | 400k exp, 15k gold, 3 coins |
| Spiders | 150 | 60 | 900k exp, 25k gold, 5 coins |
| Dragons | 200 | 70 | 2kk exp, 40k gold, 8 coins |
| Vampires | 200 | 80 | 2,5kk exp, 40k gold, 8 coins |
| Demons | 100 | 130 | 8kk exp, 100k gold, 20 coins |

**Recompensa diária (`!diario`).** Uma vez por dia, com aviso no login quando está disponível. Dias seguidos aumentam o prêmio: 5k gold, 10k gold, 25 poções, 20k gold, 50 poções, 30k gold e, no 7º dia, 50k gold + 10 coins. Depois recomeça. Se passar um dia sem pegar, volta para o dia 1. As poções são mana potion para magos e paladins e health potion para knights.

**Autoloot (`!autoloot`).** Quando o monstro morre, os itens da sua lista saem do corpo e vão direto para a sua mochila.
- `!autoloot add dragon ham` e `!autoloot remove dragon ham` (nome em inglês, como aparece no jogo). Até 20 itens.
- `!autoloot gold` liga e desliga: as moedas do loot vão direto para o banco.
- `!autoloot limpar` esvazia a lista.
- Só vale para o dono do loot e se ele estiver a até 10 sqm do monstro. Se a mochila encher, o resto fica no corpo.

**Criatura do dia (`!boosted`).** Todo dia um monstro sorteado dá **+50% de experiência** e tem o **loot sorteado duas vezes**. É anunciado no login e para todos quando o dia vira.

## Premium

`freePremium = true` no `config.lua`: todo mundo tem premium (magias premium, promoção etc.). Se um dia você quiser vender premium, mude para `false`.

## O que foi corrigido em relação ao original

- **Não compilava no Ubuntu 24.04** (erro com o GCC 13 em `src/lockfree.h`): corrigido.
- **Hunts vazias:** o downgrade vinha com só 12 monstros, mas o mapa tem spawns de 47 tipos. Faltavam trolls, wolves, cyclops, amazons, ghouls e muitos outros. Foram adicionados os 47 que faltavam.
- **Cyclops** tinha o arquivo mas não estava registrado em `monsters.xml`: corrigido.
- **Loots que não existem no 8.60** (medicine pouch, bag of apple slices, coal) quebravam o loot de Swamp Troll, Witch e Carrion Worm: removidos.
- O servidor agora liga **sem nenhum erro ou aviso** no console.
- Mensagens de login em português.
- **Promoção sumia sem premium:** o login rebaixava a vocação de quem não era premium. Removido.
- **Armas/magias/equipamentos só passavam uma promoção adiante:** corrigido no código (C++) para valer em toda a cadeia de promoções.
- **Magias premium inacessíveis** (não há como comprar premium): `freePremium` ativado.
- **Conta de admin não era God:** o `criar-conta.sh --admin` criava a conta com tipo 5 (community manager). Agora usa o tipo 6 (God).

## Mapa

O mapa é o `data/world/forgotten.otbm`, com 5 cidades: Trekolt, Rhyves, Varak, Jorvik e Saund. Para editar o mapa, use o **Remere's Map Editor** com os arquivos do cliente 8.60. Os spawns ficam em `forgotten-spawn.xml` e as casas em `forgotten-house.xml`.

## Créditos e licença

- The Forgotten Server, por Mark Samman e a comunidade OTLand
- Downgrade 8.60 por Nekiro
- Monstros adicionados do TFS 1.4.2 oficial

Licença GPL-2.0 (veja `LICENSE`). O `key.pem` é a chave RSA padrão do OT, a mesma que o OTClient usa.
