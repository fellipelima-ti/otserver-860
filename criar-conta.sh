#!/usr/bin/env bash
# Helblazer OT - cria uma conta com um personagem.
# Uso: sudo ./criar-conta.sh <conta> <senha> "<Nome do Char>" <vocacao> [--admin]
#   vocacao: sorcerer | druid | paladin | knight
#   --admin: cria a conta como God (acesso a comandos de GM)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
if [ $# -lt 4 ]; then
	echo "Uso: sudo $0 <conta> <senha> \"<Nome do Char>\" <sorcerer|druid|paladin|knight> [--admin]"
	exit 1
fi

CONTA="$1"; SENHA="$2"; NOME="$3"; VOC_NOME="$(echo "$4" | tr '[:upper:]' '[:lower:]')"; ADMIN="${5:-}"

case "$VOC_NOME" in
	sorcerer) VOC=1; HP=185; MANA=90; CAP=470 ;;
	druid)    VOC=2; HP=185; MANA=90; CAP=470 ;;
	paladin)  VOC=3; HP=185; MANA=90; CAP=470 ;;
	knight)   VOC=4; HP=185; MANA=90; CAP=470 ;;
	*) echo "Vocacao invalida: use sorcerer, druid, paladin ou knight"; exit 1 ;;
esac

if ! [[ "$CONTA" =~ ^[A-Za-z0-9]{3,32}$ ]]; then
	echo "Nome da conta: 3 a 32 letras/numeros, sem espacos."; exit 1
fi
if ! [[ "$NOME" =~ ^[A-Za-z][A-Za-z\ ]{1,28}[A-Za-z]$ ]]; then
	echo "Nome do char: so letras e espacos (3 a 30 caracteres)."; exit 1
fi
if [ ${#SENHA} -lt 6 ]; then
	echo "A senha precisa ter pelo menos 6 caracteres."; exit 1
fi

cfg() { grep -oP "^$1 = \"\K[^\"]*" "$DIR/config.lua"; }
DB="$(cfg mysqlDatabase)"; USER="$(cfg mysqlUser)"; PASS="$(cfg mysqlPass)"

TIPO=1; GRUPO=1
if [ "$ADMIN" = "--admin" ]; then TIPO=5; GRUPO=6; fi

# Escapa aspas simples para o SQL
esc() { printf "%s" "$1" | sed -e 's/\\/\\\\/g' -e "s/'/''/g"; }

MYSQL_PWD="$PASS" mysql -u "$USER" "$DB" <<SQL
START TRANSACTION;
INSERT INTO accounts (name, password, type, creation)
	VALUES ('$(esc "$CONTA")', SHA1('$(esc "$SENHA")'), $TIPO, UNIX_TIMESTAMP());
INSERT INTO players (name, group_id, account_id, level, vocation, health, healthmax, experience,
	mana, manamax, cap, town_id, posx, posy, posz, looktype, lookhead, lookbody, looklegs, lookfeet, sex, conditions)
	VALUES ('$(esc "$NOME")', $GRUPO, LAST_INSERT_ID(), 8, $VOC, $HP, $HP, 4200,
	$MANA, $MANA, $CAP, 1, 0, 0, 0, 128, 78, 69, 58, 76, 1, '');
COMMIT;
SQL

echo "Conta '$CONTA' criada com o personagem '$NOME' ($VOC_NOME, level 8, em Trekolt)."
[ "$ADMIN" = "--admin" ] && echo "Conta de ADMIN (God)."
exit 0
