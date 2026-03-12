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
echo "==========================================================="
set -e

LOGFILE="/var/log/wazuh-install.log"
WAZUH_VERSION="4.14"

exec > >(tee -a $LOGFILE) 2>&1

echo "======================================"
echo "Instalacao automatica Wazuh"
echo "Debian 13"
echo "Log: $LOGFILE"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
    echo "Execute como root"
    exit 1
fi

if [ -d "/var/ossec" ]; then
    echo "Wazuh ja instalado em /var/ossec"
    exit 1
fi

echo
echo "[1] Verificando requisitos do sistema"

RAM=$(free -g | awk '/Mem:/ {print $2}')
CPU=$(nproc)

if [ "$RAM" -lt 4 ]; then
    echo "Aviso: recomendado minimo 4GB RAM"
fi

echo "CPU cores: $CPU"
echo "RAM: ${RAM}GB"

echo
echo "[2] Verificando portas utilizadas"

PORTS=(1514 1515 55000 9200 5601)

for PORT in "${PORTS[@]}"; do
    if ss -lnt | grep -q ":$PORT "; then
        echo "Porta $PORT ja esta em uso"
        exit 1
    fi
done

echo
echo "[3] Ajustando parametros do kernel"

sysctl -w vm.max_map_count=262144

if ! grep -q vm.max_map_count /etc/sysctl.conf; then
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi

echo
echo "[4] Instalando dependencias"

apt update
apt install -y curl tar gnupg apt-transport-https lsb-release jq

echo
echo "[5] Baixando instalador oficial"

curl -sO https://packages.wazuh.com/$WAZUH_VERSION/wazuh-install.sh
chmod +x wazuh-install.sh

echo
echo "[6] Criando configuracao da stack"

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
echo "[7] Gerando certificados"

./wazuh-install.sh --generate-config-files

echo
echo "[8] Instalando Wazuh Indexer"

./wazuh-install.sh --wazuh-indexer node-1

echo
echo "[9] Instalando Wazuh Manager"

./wazuh-install.sh --wazuh-server wazuh-1

echo
echo "[10] Instalando Wazuh Dashboard"

./wazuh-install.sh --wazuh-dashboard dashboard

IP=$(hostname -I | awk '{print $1}')

echo
echo "======================================"
echo "INSTALACAO FINALIZADA"
echo "======================================"

echo
echo "Dashboard:"
echo "https://$IP"

echo
echo "Servicos instalados:"
echo "systemctl status wazuh-manager"
echo "systemctl status wazuh-indexer"
echo "systemctl status wazuh-dashboard"

echo
echo "Logs da instalacao:"
echo "$LOGFILE"

echo
