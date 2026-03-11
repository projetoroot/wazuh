#!/bin/bash
###############################################################################
# Wazuh Agent + Docker Monitoring 
# Autor: Diego Costa (@diegocostaroot) / Projeto Root (youtube.com/projetoroot)
# Versão: 1.0
# Veja o link: https://wiki.projetoroot.com.br
# 2026
###############################################################################

clear
echo "======================================="
echo " Wazuh Agent + Docker Monitoring"
echo "======================================="
echo

if [ "$EUID" -ne 0 ]; then
  echo "Execute como root."
  exit 1
fi

# Verifica se já existe instalação
if dpkg -l | grep -q wazuh-agent || [ -d "/var/ossec" ]; then
  echo
  echo "Wazuh Agent já está instalado neste host."
  echo "Instalação cancelada."
  exit 0
fi

read -p "Informe o IP do Wazuh Manager: " WAZUH_MANAGER
read -p "Informe o nome do Agent: " WAZUH_AGENT_NAME
read -p "Informe o grupo do Agent [default]: " WAZUH_AGENT_GROUP

if [ -z "$WAZUH_AGENT_GROUP" ]; then
  WAZUH_AGENT_GROUP="default"
fi

echo
echo "Manager: $WAZUH_MANAGER"
echo "Agent:   $WAZUH_AGENT_NAME"
echo "Grupo:   $WAZUH_AGENT_GROUP"
echo

read -p "Continuar instalação? (y/n): " confirm
[ "$confirm" != "y" ] && exit 0

echo
echo "Atualizando sistema..."
apt update -y
apt install -y wget python3 python3-pip

echo
echo "Baixando Wazuh Agent..."
cd /tmp
wget -q https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.3-1_amd64.deb

echo
echo "Instalando agente..."
WAZUH_MANAGER="$WAZUH_MANAGER" \
WAZUH_AGENT_GROUP="$WAZUH_AGENT_GROUP" \
WAZUH_AGENT_NAME="$WAZUH_AGENT_NAME" \
dpkg -i wazuh-agent_4.14.3-1_amd64.deb

systemctl daemon-reload
systemctl enable wazuh-agent

echo
echo "Verificando urllib3 do sistema..."
PKG=$(dpkg -l | grep python3-urllib3 | awk '{print $2}')

if [ ! -z "$PKG" ]; then
  apt remove -y python3-urllib3
fi

echo
echo "Instalando dependências Docker..."
pip3 install docker==7.1.0 urllib3==1.26.20 requests==2.32.2 \
--ignore-installed urllib3 \
--break-system-packages

echo
echo "Configurando ossec.conf..."

cat > /var/ossec/etc/ossec.conf <<EOF
<!--
  Wazuh 4.14 - Agent configuration otimizada para Debian 13 ou Ubuntu 24.04 com monitoramento Docker - by Diego Costa
  Data: 11/03/2026
-->
<ossec_config>

  <client>
    <server>
      <address>${WAZUH_MANAGER}</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>ubuntu, ubuntu24, ubuntu24.04</config-profile>
    <notify_time>20</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>
    <enrollment>
      <enabled>yes</enabled>
      <agent_name>${WAZUH_AGENT_NAME}</agent_name>
      <groups>${WAZUH_AGENT_GROUP}</groups>
      <authorization_pass_path>etc/authd.pass</authorization_pass_path>
    </enrollment>
  </client>

  <client_buffer>
    <disabled>no</disabled>
    <queue_size>5000</queue_size>
    <events_per_second>500</events_per_second>
  </client_buffer>

  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <check_dev>yes</check_dev>
    <check_sys>yes</check_sys>
    <check_pids>yes</check_pids>
    <check_ports>yes</check_ports>
    <check_if>yes</check_if>
    <frequency>300</frequency>
    <rootkit_files>etc/shared/rootkit_files.txt</rootkit_files>
    <rootkit_trojans>etc/shared/rootkit_trojans.txt</rootkit_trojans>
    <skip_nfs>yes</skip_nfs>
    <ignore>/var/lib/containerd</ignore>
    <ignore>/var/lib/docker/overlay2</ignore>
  </rootcheck>

  <wodle name="docker-listener">
    <disabled>no</disabled>
    <interval>10m</interval>
    <run_on_start>yes</run_on_start>
    <attempts>5</attempts>
  </wodle>

  <wodle name="cis-cat">
    <disabled>yes</disabled>
  </wodle>

  <wodle name="osquery">
    <disabled>yes</disabled>
  </wodle>

  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>1h</interval>
    <scan_on_start>yes</scan_on_start>
    <hardware>yes</hardware>
    <os>yes</os>
    <network>yes</network>
    <packages>yes</packages>
    <ports all="yes">yes</ports>
    <processes>yes</processes>
    <users>yes</users>
    <groups>yes</groups>
    <services>yes</services>
  </wodle>

  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>12h</interval>
  </sca>

  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <scan_on_start>yes</scan_on_start>

    <directories>/etc,/usr/bin,/usr/sbin</directories>
    <directories>/bin,/sbin,/boot</directories>

    <directories check_all="yes">/var/lib/docker/volumes</directories>
    <directories check_all="yes">/var/lib/docker/containers/*/config.v2.json</directories>

    <ignore>/var/lib/docker/overlay2</ignore>
    <ignore>/var/lib/docker/containers</ignore>
    <ignore>/var/lib/docker/image</ignore>

    <skip_nfs>yes</skip_nfs>
    <skip_dev>yes</skip_dev>
    <skip_proc>yes</skip_proc>
    <skip_sys>yes</skip_sys>

  </syscheck>

  <localfile>
    <log_format>json</log_format>
    <location>/var/lib/docker/containers/*/*.log</location>
  </localfile>

  <localfile>
    <log_format>journald</log_format>
    <location>journald</location>
    <query>COMM=dockerd OR _SYSTEMD_UNIT=docker.service</query>
  </localfile>

  <active-response>
    <disabled>no</disabled>
    <ca_store>etc/wpk_root.pem</ca_store>
    <ca_verification>yes</ca_verification>
  </active-response>

  <logging>
    <log_format>plain</log_format>
  </logging>

</ossec_config>
EOF

echo "Adicionando usuário wazuh ao grupo docker..."
usermod -aG docker wazuh
echo

echo "Reiniciando agente..."
systemctl restart wazuh-agent

echo
echo "Instalação concluída."
systemctl status wazuh-agent --no-pager
