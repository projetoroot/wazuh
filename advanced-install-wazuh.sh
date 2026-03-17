#!/bin/bash
###############################################################################
# Instalacao avançada e automatica Wazuh (all-in-one) em Debian 13
# Autor: Diego Costa (@diegocostaroot) / Projeto Root (youtube.com/projetoroot)
# Versão: 1.0
# Veja o link: https://wiki.projetoroot.com.br
# 2026
###############################################################################
set -e
LOG="/var/log/wazuh-soc-install.log"

echo "==========================================================="
echo "Instalacao automatica Wazuh (all-in-one) avançada "
echo "Debian 13"
echo "Log: $LOG"
echo "==========================================================="

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

CPU_CORES=$(nproc)

RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
RAM_GB=$((RAM_MB / 1024))

echo "CPU: $CPU_CORES cores"
echo "RAM: ${RAM_GB}GB"

echo
echo "[3] Ajustando heap OpenSearch"

if [ "$RAM_MB" -le 4096 ]; then
    HEAP_MB=1024
elif [ "$RAM_MB" -le 8192 ]; then
    HEAP_MB=2048
else
    HEAP_MB=$((RAM_MB / 2))
fi

echo "Heap definido: ${HEAP_MB}MB"
echo
echo "[4] Ajuste kernel necessário para OpenSearch"

SYSCTL_FILE="/etc/sysctl.conf"

touch $SYSCTL_FILE

if ! grep -q vm.max_map_count $SYSCTL_FILE; then
    echo "vm.max_map_count=262144" >> $SYSCTL_FILE
fi

sysctl -w vm.max_map_count=262144

echo
echo "[5] Instalando dependencias"

apt update

apt install -y \
sudo \
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

if ! grep -q "100100" "$RULE_FILE"; then

cat <<EOF >> "$RULE_FILE"

<group name="rootcheck_ignore,">
  <rule id="100100" level="0">
    <if_group>rootcheck</if_group>
    <match>/dev/.blkid.tab</match>
    <description>Ignore false positive for /dev/.blkid.tab</description>
  </rule>

</group>

EOF

fi


echo
echo "[18] Ajustando heap da JVM do Wazuh Indexer"

JVM_FILE="/etc/wazuh-indexer/jvm.options"

# Detectar RAM real do sistema
TOTAL_RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)

# Validação
if [ -z "$TOTAL_RAM_MB" ]; then
    echo "Erro: não foi possível detectar memória do sistema"
    TOTAL_RAM_MB=2048
fi

# Cálculo do heap
if [ "$TOTAL_RAM_MB" -le 4096 ]; then
    HEAP="1g"
elif [ "$TOTAL_RAM_MB" -le 8192 ]; then
    HEAP="2g"
else
    HEAP="$((TOTAL_RAM_MB / 2 / 1024))g"
fi

echo "RAM detectada: ${TOTAL_RAM_MB}MB"
echo "Heap configurado para: $HEAP"

# Aplicar no jvm.options
sed -i 's/^-Xms.*/-Xms'"$HEAP"'/' "$JVM_FILE"
sed -i 's/^-Xmx.*/-Xmx'"$HEAP"'/' "$JVM_FILE"

echo
echo "[19] Ajustando vm.max_map_count"

if ! grep -q vm.max_map_count /etc/sysctl.conf; then
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi

sysctl -w vm.max_map_count=262144 >/dev/null

echo
echo "[20] Ativando servicos"

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

TAR_FILE=$(find / -name wazuh-install-files.tar 2>/dev/null | head -1)

if [ -f "$TAR_FILE" ]; then
    USER=$(tar -xOf "$TAR_FILE" wazuh-install-files/wazuh-passwords.txt 2>/dev/null | awk -F"'" '/indexer_username/ {print $2; exit}')
    PASS=$(tar -xOf "$TAR_FILE" wazuh-install-files/wazuh-passwords.txt 2>/dev/null | awk -F"'" '/indexer_password/ {print $2; exit}')

    echo
    echo "Usuário: $USER"
    echo "Senha: $PASS"
fi


echo
