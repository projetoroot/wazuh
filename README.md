# 🛡️ Wazuh SOC Installer (All-in-One) – Debian 13

Script automatizado para instalação completa do Wazuh All-in-One em Debian 13, com ajustes de performance, hardening básico e otimizações para ambiente SOC.

---

## 📌 Sobre o Wazuh

O Wazuh é uma plataforma open source de segurança que atua como:

- SIEM, centralização e correlação de logs  
- XDR, detecção e resposta a ameaças  
- HIDS, monitoramento de integridade  
- Análise de vulnerabilidades  
- Detecção de rootkits e comportamentos suspeitos  

Ele é composto por três partes principais:

- Wazuh Manager – processamento e correlação de eventos  
- Wazuh Indexer (OpenSearch) – armazenamento e busca  
- Wazuh Dashboard – interface web  

---

## 🎯 Finalidade do Script

Este script automatiza a instalação completa do Wazuh em modo all-in-one, ou seja, todos os componentes na mesma máquina, já com:

- Ajustes automáticos baseados no hardware  
- Configuração de heap da JVM  
- Otimizações do OpenSearch  
- Hardening básico do sistema  
- Rotação de logs  
- Correção de falso positivo do rootcheck  

Ideal para:

- Laboratórios SOC  
- Ambientes de teste  
- Pequenas e médias operações de segurança  
- Provas de conceito  

---

## ⚙️ O que o Script Faz

### 🔎 1. Validação inicial

- Verifica se está sendo executado como root  
- Evita reinstalação se o Wazuh já existir  
- Detecta sistema operacional e versão  

---

### 🧠 2. Análise de recursos

- Identifica quantidade de CPU  
- Calcula memória disponível  
- Define automaticamente o heap ideal  

---

### ⚡ 3. Otimizações de sistema

- Ajusta vm.max_map_count para OpenSearch  
- Configura limites de arquivos abertos  
- Ativa sincronização de tempo com chrony  

---

### 📦 4. Instala dependências

Instala automaticamente:

- curl  
- gnupg  
- jq  
- chrony  
- e outros pacotes necessários  

---

### ⬇️ 5. Download do instalador oficial

Baixa diretamente do repositório oficial do Wazuh:

https://packages.wazuh.com/

---

### 🧩 6. Configuração da stack

Cria automaticamente o arquivo:

```yaml
config.yml
```

Com definição de:

- Indexer  
- Manager  
- Dashboard  

---

### 🔐 7. Geração de certificados

- Executa geração de certificados TLS automaticamente  
- Prepara comunicação segura entre os componentes  

---

### 🗄️ 8. Instalação do Indexer

- Instala o OpenSearch via Wazuh  
- Ajusta heap da JVM dinamicamente  
- Otimiza parâmetros de shards  

---

### 🚀 9. Inicialização do cluster

- Sobe o cluster do indexador  
- Prepara ambiente para ingestão de logs  

---

### 🧠 10. Instalação do Manager

- Configura engine de análise de segurança  
- Ativa regras e monitoramento  

---

### 🌐 11. Instalação do Dashboard

- Interface web pronta para uso  
- Acesso via HTTPS  

---

### 📂 12. Hardening e ajustes

- Limite de arquivos (nofile)  
- Rotação de logs automática  
- Regra customizada para evitar falso positivo:

```xml
/dev/.blkid.tab
```

---

### 🧮 13. Ajuste inteligente de memória

- Detecta RAM real  
- Aplica regra:

| RAM        | Heap |
|------------|------|
| até 4GB    | 1GB  |
| até 8GB    | 2GB  |
| acima      | 50%  |

---

### 🔄 14. Ativação dos serviços

- Habilita serviços no boot  
- Reinicia todos os componentes  

---

### 📡 15. Exibição de informações finais

Ao final, o script mostra:

- URL do dashboard  
- Diretório do manager  
- Caminho do log  
- Usuário e senha automaticamente extraídos  

---

## 🌍 Acesso ao Dashboard

Após a instalação:

```
https://IP_DO_SERVIDOR
```

---

## 📁 Logs

O log completo da instalação fica em:

```
/var/log/wazuh-soc-install.log
```

---

## 🔐 Credenciais

O script tenta extrair automaticamente:

- Usuário  
- Senha  

Diretamente do arquivo gerado pelo instalador do Wazuh.

---

## 🚀 Como usar

```bash
wget https://raw.githubusercontent.com/projetoroot/wazuh/refs/heads/main/advanced-install-wazuh.sh
chmod +x install-wazuh.sh
sudo ./install-wazuh.sh
```

---

## ⚠️ Requisitos

- Debian 13  
- Acesso root  
- Internet ativa  

Mínimo recomendado:

- 2 CPU  
- 4 GB RAM  

---

## 📊 Cenários recomendados

- SOC em laboratório  
- Testes de segurança  
- Ambientes educacionais  
- Pequenos ambientes produtivos  

---

## 👨‍💻 Autor

Diego Costa  
Projeto Root  
https://wiki.projetoroot.com.br  

---
