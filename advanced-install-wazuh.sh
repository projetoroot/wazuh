#!/bin/bash
###############################################################################
# Instalacao avançada e automatica Wazuh (all-in-one) em Debian 13
# Autor: Diego Costa (@diegocostaroot) / Projeto Root (youtube.com/projetoroot)
# Versão: 1.0
# Veja o link: https://wiki.projetoroot.com.br
# 2026
###############################################################################

echo "==========================================================="
echo "Instalacao automatica Wazuh (all-in-one) avançada "
echo "Debian 13"
echo "Log: $LOG"
echo "==========================================================="

set -e

LOG="/var/log/wazuh-soc-install.log"
WAZUH_VERSION="4.14"

exec > >(tee -a $LOG) 2>&1

if [ "$EUID" -ne 0 ]; then
    echo "Execute como root"
    exit 1
fi

if [ -d "/var/ossec" ]; then
    echo "Wazuh ja instalado"
    exit 1
fi

echo
echo "[1] Detectando sistema"

OS=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

echo "Sistema: $OS $VERSION"

echo
echo "[2] Verificando recursos"

RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
RAM_GB=$((RAM_MB/1024))
CPU=$(nproc)

echo "CPU: $CPU cores"
echo "RAM: ${RAM_GB}GB"

echo
echo "[3] Ajustando heap OpenSearch"

HEAP=$((RAM_MB/2))

if [ "$HEAP" -gt 4096 ]; then
    HEAP=4096
fi

echo "Heap definido: ${HEAP}MB"

echo
echo "[4] Ajuste kernel necessário para OpenSearch"

sysctl -w vm.max_map_count=262144

if ! grep -q vm.max_map_count /etc/sysctl.conf; then
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi

echo
echo "[5] Instalando dependencias"

apt update

apt install -y \
curl \
tar \
gnupg \
apt-transport-https \
lsb-release \
jq \
chrony

systemctl enable chrony
systemctl start chrony

echo
echo "[6] Baixando instalador oficial"

curl -sO https://packages.wazuh.com/$WAZUH_VERSION/wazuh-install.sh

chmod +x wazuh-install.sh

echo
echo "[7] Criando config da stack"

cat <<EOF > config.yml
nodes:
  indexer:
    - name: node-1
      ip: "127.0.0.1"

  server:
    - name: wazuh-1
      ip: "127.0.0.1"

  dashboard:
    - name: dashboard
      ip: "127.0.0.1"
EOF

echo
echo "[8] Gerando certificados"

./wazuh-install.sh --generate-config-files

echo
echo "[9] Instalando Indexer"

./wazuh-install.sh --wazuh-indexer node-1

echo
echo "[10] Ajustando heap"

sed -i "s/^-Xms.*/-Xms${HEAP}m/" /etc/wazuh-indexer/jvm.options
sed -i "s/^-Xmx.*/-Xmx${HEAP}m/" /etc/wazuh-indexer/jvm.options

echo
echo "[11] Otimizando shards"

cat >> /etc/wazuh-indexer/opensearch.yml <<EOF

cluster.max_shards_per_node: 1000
indices.query.bool.max_clause_count: 8192
EOF

echo
echo "[12] Inicializando cluster"

./wazuh-install.sh --start-cluster

echo
echo "[13] Instalando Manager"

./wazuh-install.sh --wazuh-server wazuh-1

echo
echo "[14] Instalando Dashboard"

./wazuh-install.sh --wazuh-dashboard dashboard

echo
echo "[15] Ajustando limite de arquivos"

cat >> /etc/security/limits.conf <<EOF

wazuh soft nofile 65536
wazuh hard nofile 65536
EOF

echo
echo "[16] Rotacao de logs"

cat <<EOF > /etc/logrotate.d/wazuh

/var/ossec/logs/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    copytruncate
}
EOF

echo "[17] Aplicando regra customizada para falso positivo rootcheck"
echo
RULE_FILE="/var/ossec/etc/rules/local_rules.xml"

if ! grep -q "100100" $RULE_FILE; then

cat <<EOF >> $RULE_FILE

<rule id="100100" level="0">
  <if_group>rootcheck</if_group>
  <match>/dev/.blkid.tab</match>
  <description>Ignore false positive for /dev/.blkid.tab</description>
</rule>

EOF

fi

echo
echo "[18] Ativando servicos"

systemctl enable wazuh-indexer
systemctl enable wazuh-manager
systemctl enable wazuh-dashboard

systemctl restart wazuh-indexer
systemctl restart wazuh-manager
systemctl restart wazuh-dashboard


IP=$(hostname -I | awk '{print $1}')

echo
echo "======================================="
echo "INSTALACAO FINALIZADA"
echo "======================================="

echo
echo "Dashboard:"
echo "https://$IP"
echo

echo "Diretorio do manager:"
echo "/var/ossec"

echo
echo "Log completo:"
echo "$LOG"
echo

echo "Credenciais do Wazuh:"
echo

if [ -f wazuh-install-files/wazuh-passwords.txt ]; then
    cat wazuh-install-files/wazuh-passwords.txt
fi


echo
