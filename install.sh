#!/usr/bin/env bash
# Helblazer OT - instalador para Ubuntu 22.04 / 24.04
# Uso (dentro da pasta do servidor):  sudo ./install.sh [IP_PUBLICO]
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICO="helblazer"
USUARIO="otserver"
DB_NOME="helblazer"
DB_USER="helblazer"

if [ "$(id -u)" -ne 0 ]; then
	echo "Rode como root: sudo ./install.sh"
	exit 1
fi

case "$DIR" in
	/root*|/home/*)
		echo "ERRO: o servidor esta em $DIR."
		echo "O usuario '$USUARIO' nao consegue ler essa pasta. Mova para /opt:"
		echo "  sudo mv \"$DIR\" /opt/helblazer && cd /opt/helblazer && sudo ./install.sh"
		exit 1 ;;
esac

echo ">> [1/6] Instalando dependencias..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq build-essential cmake git curl \
	libluajit-5.1-dev libmysqlclient-dev libpugixml-dev libcrypto++-dev libfmt-dev libgmp-dev \
	libboost-system-dev libboost-iostreams-dev libboost-filesystem-dev libboost-date-time-dev \
	mariadb-server
systemctl enable --now mariadb

echo ">> [2/6] Compilando o servidor (pode levar alguns minutos)..."
mkdir -p "$DIR/build"
cd "$DIR/build"
cmake .. -DCMAKE_BUILD_TYPE=Release > /dev/null
make -j"$(nproc)"
cp tfs "$DIR/tfs"
cd "$DIR"

echo ">> [3/6] Configurando o banco de dados..."
if [ -f "$DIR/config.lua" ]; then
	DB_PASS="$(grep -oP '^mysqlPass = "\K[^"]*' "$DIR/config.lua")"
	echo "   config.lua ja existe, mantendo a senha atual do banco."
else
	DB_PASS="$(openssl rand -hex 16)"
fi
mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NOME\`;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NOME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;"
TABELAS="$(mysql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NOME';")"
if [ "$TABELAS" = "0" ]; then
	mysql "$DB_NOME" < "$DIR/schema.sql"
	echo "   Schema importado."
else
	echo "   Banco ja tem tabelas, nada foi apagado."
fi

echo ">> [4/6] Gerando config.lua..."
IP="${1:-}"
if [ -z "$IP" ]; then
	IP="$(curl -4 -s --max-time 5 https://api.ipify.org || true)"
fi
if [ -z "$IP" ]; then
	IP="$(hostname -I | awk '{print $1}')"
fi
if [ ! -f "$DIR/config.lua" ]; then
	sed -e "s/^mysqlPass = .*/mysqlPass = \"$DB_PASS\"/" \
	    -e "s/^ip = .*/ip = \"$IP\"/" \
	    "$DIR/config.lua.dist" > "$DIR/config.lua"
else
	sed -i "s/^ip = .*/ip = \"$IP\"/" "$DIR/config.lua"
fi
chmod 640 "$DIR/config.lua"
echo "   IP do servidor: $IP"

echo ">> [5/6] Criando usuario '$USUARIO' e o servico systemd..."
id "$USUARIO" > /dev/null 2>&1 || useradd --system --home-dir "$DIR" --shell /usr/sbin/nologin "$USUARIO"
chown -R "$USUARIO:$USUARIO" "$DIR"
cat > /etc/systemd/system/$SERVICO.service <<EOF
[Unit]
Description=Helblazer OT (TFS 1.5 8.60)
After=network.target mariadb.service
Requires=mariadb.service

[Service]
Type=simple
User=$USUARIO
WorkingDirectory=$DIR
ExecStart=$DIR/tfs
Restart=always
RestartSec=10
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now $SERVICO

echo ">> [6/6] Liberando as portas 7171 e 7172 no firewall..."
if command -v ufw > /dev/null && ufw status | grep -q "Status: active"; then
	ufw allow 7171/tcp
	ufw allow 7172/tcp
else
	echo "   UFW inativo. Se a sua hospedagem tiver firewall no painel, libere 7171 e 7172 TCP la."
fi

echo
echo "=============================================="
echo " Helblazer OT instalado e rodando!"
echo " IP para o cliente: $IP  (porta 7171)"
echo " Ver o console:  journalctl -u $SERVICO -f"
echo " Reiniciar:      systemctl restart $SERVICO"
echo " Criar conta:    sudo ./criar-conta.sh conta senha \"Nome Do Char\" knight"
echo "=============================================="
