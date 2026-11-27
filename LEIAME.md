# Helblazer OT (8.60)

Servidor de Tibia 8.60 baseado no **TFS 1.5, downgrade 8.60 do Nekiro**, com correções e o sistema de teleportes do Helblazer.

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
sudo ./criar-conta.sh admin SenhaForte123 "GM Helblazer" sorcerer --admin
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

## Mapa

O mapa é o `data/world/forgotten.otbm`, com 5 cidades: Trekolt, Rhyves, Varak, Jorvik e Saund. Para editar o mapa, use o **Remere's Map Editor** com os arquivos do cliente 8.60. Os spawns ficam em `forgotten-spawn.xml` e as casas em `forgotten-house.xml`.

## Créditos e licença

- The Forgotten Server, por Mark Samman e a comunidade OTLand
- Downgrade 8.60 por Nekiro
- Monstros adicionados do TFS 1.4.2 oficial

Licença GPL-2.0 (veja `LICENSE`). O `key.pem` é a chave RSA padrão do OT, a mesma que o OTClient usa.
