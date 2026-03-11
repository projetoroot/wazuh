#!/usr/bin/env python3
"""
Wazuh → Microsoft Teams Integration (Workflows)
Author: Diego Costa (github.com/projetoroot)
License: GPL
"""

import sys
import json
import requests
import time
import os

WEBHOOK = "SUA-URL-WEBHOOK-AQUI"




CACHE_FILE = "/var/ossec/tmp/teams_alert_cache.json"
WINDOW = 300      # 5 minutos para deduplicação

alert_file = sys.argv[1]

with open(alert_file) as f:
    alert = json.load(f)

rule = alert.get("rule", {})
agent = alert.get("agent", {})

level = int(rule.get("level", 0))
rule_id = str(rule.get("id", "0"))
description = rule.get("description", "")
hostname = agent.get("name", "unknown")
ip = agent.get("ip", "unknown")
timestamp = alert.get("timestamp", "")

event_key = f"{hostname}-{rule_id}"

now = int(time.time())

cache = {}

if os.path.exists(CACHE_FILE):
    with open(CACHE_FILE) as f:
        cache = json.load(f)

# remover eventos antigos
cache = {k:v for k,v in cache.items() if now - v["time"] < WINDOW}

# verificar duplicado
if event_key in cache:
    cache[event_key]["count"] += 1
    cache[event_key]["time"] = now
    with open(CACHE_FILE, "w") as f:
        json.dump(cache, f)
    sys.exit(0)

cache[event_key] = {
    "time": now,
    "count": 1
}

with open(CACHE_FILE, "w") as f:
    json.dump(cache, f)

color = "0076D7"
if level >= 10:
    color = "FF0000"
elif level >= 7:
    color = "FFA500"

payload = {
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "summary": "Wazuh Alert",
    "themeColor": color,
    "title": f"Wazuh Alert Level {level}",
    "sections": [
        {
            "facts": [
                {"name": "Agent", "value": hostname},
                {"name": "IP", "value": ip},
                {"name": "Rule ID", "value": rule_id},
                {"name": "Description", "value": description},
                {"name": "Timestamp", "value": timestamp}
            ]
        }
    ]
}

requests.post(WEBHOOK, json=payload)
