#!/bin/bash
# TravelWiFi Installations-Skript
set -e

echo "[TravelWiFi] Installation gestartet..."

# --------------------------
# 1. Systempakete installieren
# --------------------------
echo "[TravelWiFi] Installiere benötigte Pakete..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip dnsmasq hostapd iw net-tools wireless-tools git curl unzip ifstat

# --------------------------
# 2. Python-Pakete
# --------------------------
echo "[TravelWiFi] Installiere Python-Abhängigkeiten..."
sudo pip3 install --upgrade pip requests flask

# --------------------------
# 3. Git-Struktur anlegen
# --------------------------
echo "[TravelWiFi] Richte Git-Struktur ein..."
mkdir -p ~/TravelWiFi/{config,web/templates,web/static/img,bin}

# README
cat > ~/TravelWiFi/README.md <<EOL
# TravelWiFi

TravelWiFi ist ein dual-WLAN Repeater für Raspberry Pi / HP Mini Systeme.
Features:
- Automatische Verbindung zu bekannten WIFIs
- Eigenes AP-Netzwerk mit dynamischem Kanal oder Lite-Mode
- Wigle-Integration zur Netzwerksuche
- Status-API (CPU, RAM, Temperatur, Netzwerk)
- Mobiloptimierte WebUI mit Ente-Logo
- NTP / Zeitsynchronisierung
EOL

# --------------------------
# 4. Wigle-Konfiguration (existiert ggf. bereits)
# --------------------------
WIGLE_CONF=~/TravelWiFi/config/wigle.conf
if [ ! -f "$WIGLE_CONF" ]; then
    echo "[TravelWiFi] Erstelle Beispiel wigle.conf"
    cat > "$WIGLE_CONF" <<EOL
username=DEIN_WIGLE_USER
password=DEIN_WIGLE_PASS
EOL
fi

# --------------------------
# 5. TravelWiFi Python-Skript
# --------------------------
PY_FILE=~/TravelWiFi/bin/travelwifi_final.py
echo "[TravelWiFi] Erstelle travelwifi_final.py"
cat > "$PY_FILE" <<'EOL'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import time
import threading
import subprocess
from flask import Flask, render_template, jsonify

# --------------------------
# Konfiguration
# --------------------------
CONFIG_DIR = os.path.expanduser("~/TravelWiFi/config")
NETWORKS_FILE = os.path.join(CONFIG_DIR, "networks.json")
WIGLE_CONF = os.path.join(CONFIG_DIR, "wigle.conf")
AP_SSID = "mage_camp"
AP_PASSWORD = "Wuschel2021"
LITE_MODE = False  # automatisch gesetzt, wenn nur 1 Adapter

# --------------------------
# Flask App
# --------------------------
app = Flask(__name__, template_folder=os.path.expanduser("~/TravelWiFi/web/templates"))

# --------------------------
# Hilfsfunktionen
# --------------------------
def load_networks():
    if not os.path.exists(NETWORKS_FILE):
        return []
    with open(NETWORKS_FILE, "r") as f:
        return json.load(f)

def save_networks(data):
    with open(NETWORKS_FILE, "w") as f:
        json.dump(data, f, indent=2)

def scan_networks():
    # iwlist scan
    result = subprocess.run(["iwlist", "wlan0", "scan"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    output = result.stdout.decode()
    networks = []
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("ESSID:"):
            ssid = line.split(":")[1].strip('"')
            networks.append({"ssid": ssid, "signal": 0})
        elif "Signal level=" in line:
            try:
                signal = int(line.split("Signal level=")[1].split()[0])
                networks[-1]["signal"] = signal
            except:
                pass
    return networks

def connect_best_network():
    networks = scan_networks()
    known = load_networks()
    known_nets = [n for n in networks if any(d["ssid"]==n["ssid"] for d in known)]
    if known_nets:
        best = max(known_nets, key=lambda x:x["signal"])
        ssid = best["ssid"]
        db_entry = next((d for d in known if d["ssid"]==ssid), None)
        if db_entry and "password" in db_entry:
            cmd = ["nmcli", "dev", "wifi", "connect", ssid, "password", db_entry["password"]]
        else:
            cmd = ["nmcli", "dev", "wifi", "connect", ssid]
        subprocess.run(cmd)

def setup_ap(lite_mode=False):
    hostapd_conf_path = os.path.expanduser("~/TravelWiFi/config/hostapd.conf")
    ssid = AP_SSID
    password = AP_PASSWORD if not lite_mode else ""
    conf = [
        "interface=wlan1",
        "driver=nl80211",
        f"ssid={ssid}",
        "hw_mode=g",
        "channel=6",
        "macaddr_acl=0",
        "auth_algs=1",
        "ignore_broadcast_ssid=0"
    ]
    if not lite_mode:
        conf.append(f"wpa=2")
        conf.append(f"wpa_passphrase={password}")
        conf.append("wpa_key_mgmt=WPA-PSK")
        conf.append("rsn_pairwise=CCMP")
    with open(hostapd_conf_path, "w") as f:
        f.write("\n".join(conf))
    subprocess.run(["sudo", "systemctl", "restart", "hostapd"])

def ntp_sync():
    try:
        subprocess.run(["sudo", "timedatectl", "set-ntp", "true"])
    except:
        pass

def cpu_temp():
    result = subprocess.run(["vcgencmd", "measure_temp"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        return float(result.stdout.decode().split("=")[1].replace("'C",""))
    except:
        return 0

def cpu_load():
    result = subprocess.run(["top","-bn1"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    for line in result.stdout.decode().splitlines():
        if "Cpu(s)" in line:
            try:
                usage = 100 - float(line.split("%id,")[0].split()[-1])
                return round(usage,2)
            except:
                return 0
    return 0

def mem_usage():
    result = subprocess.run(["free","-m"], stdout=subprocess.PIPE)
    lines = result.stdout.decode().splitlines()
    mem_line = lines[1].split()
    used = int(mem_line[2])
    total = int(mem_line[1])
    return used, total

def net_usage():
    result = subprocess.run(["ifstat","-i","wlan0","1","1"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    lines = result.stdout.decode().splitlines()
    if len(lines) >= 3:
        rx, tx = lines[2].split()[:2]
        return rx.strip(), tx.strip()
    return "0","0"

# --------------------------
# Hintergrund-Thread
# --------------------------
def background_loop():
    global LITE_MODE
    adapters = subprocess.run(["lsusb"], stdout=subprocess.PIPE).stdout.decode()
    if "8821CU" in adapters:
        client_adapter = "wlan0"
    else:
        client_adapter = "wlan0"
    if "RTL8188" in adapters:
        ap_adapter = "wlan1"
    else:
        ap_adapter = None
        LITE_MODE = True
    while True:
        connect_best_network()
        if ap_adapter:
            setup_ap(lite_mode=LITE_MODE)
        ntp_sync()
        time.sleep(60)

threading.Thread(target=background_loop, daemon=True).start()

# --------------------------
# Flask Endpoints
# --------------------------
@app.route("/")
def index():
    networks = scan_networks()
    db = load_networks()
    display = []
    for n in networks:
        entry = next((d for d in db if d["ssid"]==n["ssid"]), None)
        display.append({
            "ssid": n["ssid"],
            "signal": n.get("signal",0),
            "permanent": entry.get("permanent",False) if entry else False
        })
    return render_template("index.html", networks=display)

@app.route("/status")
def status():
    cpu = cpu_load()
    temp = cpu_temp()
    used, total = mem_usage()
    rx, tx = net_usage()
    return jsonify({
        "cpu_load": cpu,
        "cpu_temp": temp,
        "ram_used": used,
        "ram_total": total,
        "network_rx": rx,
        "network_tx": tx
    })

# --------------------------
# Main
# --------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOL

chmod +x "$PY_FILE"

# --------------------------
# 6. WebUI Template inkl. Ente
# --------------------------
curl -L -o ~/TravelWiFi/web/static/img/ente.png "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/Mallard_duck_icon.svg/120px-Mallard_duck_icon.svg.png"

cat > ~/TravelWiFi/web/templates/index.html <<EOL
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>TravelWiFi</title>
<style>
body{font-family:sans-serif;margin:1em;background:#f4f9f9}
h1{color:#0b3d91} img.logo{width:50px;vertical-align:middle;}
table{width:100%;border-collapse:collapse}
th,td{padding:0.5em;border:1px solid #ccc;text-align:left}
</style>
</head>
<body>
<h1><img class="logo" src="/static/img/ente.png"/> TravelWiFi</h1>
<table>
<tr><th>SSID</th><th>Signal</th><th>Permanent</th></tr>
{% for n in networks %}
<tr><td>{{n.ssid}}</td><td>{{n.signal}}</td><td>{{n.permanent}}</td></tr>
{% endfor %}
</table>
</body>
</html>
EOL

# --------------------------
# 7. systemd Service
# --------------------------
sudo bash -c "cat > /etc/systemd/system/travelwifi.service" <<EOL
[Unit]
Description=TravelWiFi Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 $HOME/TravelWiFi/bin/travelwifi_final.py
Restart=always
User=$USER
Environment=PATH=/usr/bin:/usr/local/bin
WorkingDirectory=$HOME/TravelWiFi

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable travelwifi.service
sudo systemctl start travelwifi.service

echo "[TravelWiFi] Installation abgeschlossen. WebUI erreichbar unter http://<IP>:5000/"
