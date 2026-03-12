#!/bin/bash
###############################################################################
# Instalacao automatica Wazuh (all-in-one) para apenas um nó em Debian 13
# Autor: Diego Costa (@diegocostaroot) / Projeto Root (youtube.com/projetoroot)
# Versão: 1.0
# Veja o link: https://wiki.projetoroot.com.br
# 2026
###############################################################################
set -e

echo "==========================================================="
echo "Instalacao automatica Wazuh (all-in-one) para apenas um nó "
echo "Debian 13"
echo "==========================================================="

if [ "$EUID" -ne 0 ]; then
  echo "Execute como root"
  exit 1
fi

# verificar se já existe instalação
if [ -d "/var/ossec" ]; then
  echo "Wazuh ja parece estar instalado em /var/ossec"
  exit 1
fi

echo "[1/7] Atualizando sistema"

apt update
apt install -y curl tar gnupg apt-transport-https lsb-release

echo "[2/7] Baixando instalador oficial do Wazuh"

curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
chmod +x wazuh-install.sh

echo "[3/7] Gerando arquivo de configuracao"

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

echo "[4/7] Gerando certificados da stack"

./wazuh-install.sh --generate-config-files

echo "[5/7] Instalando Wazuh Indexer"

./wazuh-install.sh --wazuh-indexer node-1

echo "[6/7] Instalando Wazuh Manager"

./wazuh-install.sh --wazuh-server wazuh-1

echo "[7/7] Instalando Wazuh Dashboard"

./wazuh-install.sh --wazuh-dashboard dashboard

IP=$(hostname -I | awk '{print $1}')

echo ""
echo "========================================"
echo "Instalacao concluida"
echo "========================================"
echo ""

echo "Dashboard:"
echo "https://$IP"

echo ""
echo "Credenciais:"
echo "usuario: admin"
echo "senha: gerada durante instalacao"
echo ""

echo "Servicos instalados:"
echo "systemctl status wazuh-manager"
echo "systemctl status wazuh-indexer"
echo "systemctl status wazuh-dashboard"
echo ""
