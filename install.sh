#!/bin/bash
# TravelWiFi Installation
set -e
echo "[TravelWiFi] Installation gestartet..."

# --- Root prüfen ---
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Bitte mit sudo ausführen!"
   exit 1
fi

# --- Pakete installieren ---
apt update
apt install -y python3 python3-pip dnsmasq hostapd iw wireless-tools net-tools curl git

# --- Python Pakete ---
pip3 install --upgrade pip
pip3 install flask requests

# --- Verzeichnisse ---
mkdir -p /etc/travelwifi
mkdir -p /usr/local/bin/travelwifi
mkdir -p /var/log/travelwifi
mkdir -p /usr/local/bin/travelwifi/templates
mkdir -p /usr/local/bin/travelwifi/static

# --- Wigle Config ---
if [ ! -f /etc/travelwifi/wigle.conf ]; then
cat <<EOL > /etc/travelwifi/wigle.conf
# Wigle API-Zugang
username=DEIN_USERNAME
password=DEIN_PASSWORT
EOL
fi

# --- Ente Logo ---
if [ ! -f /usr/local/bin/travelwifi/static/duck_logo.png ]; then
    curl -sL -o /usr/local/bin/travelwifi/static/duck_logo.png \
    https://upload.wikimedia.org/wikipedia/commons/thumb/0/0b/Yellow_duck_icon.png/64px-Yellow_duck_icon.png
fi

# --- Python Script ---
cat <<'EOF' > /usr/local/bin/travelwifi/travelwifi_final.py
#!/usr/bin/env python3
import os, json, time, platform, subprocess, requests
from flask import Flask, jsonify, render_template

app = Flask(__name__)
NETWORKS_FILE = "/etc/travelwifi/networks.json"
WIGLE_CONF = "/etc/travelwifi/wigle.conf"
IS_HP = platform.machine() in ["x86_64","i686"]

def load_networks():
    if os.path.exists(NETWORKS_FILE):
        with open(NETWORKS_FILE,"r") as f:
            return json.load(f)
    return []

def save_networks(networks):
    with open(NETWORKS_FILE,"w") as f:
        json.dump(networks,f,indent=2)

def clean_old_networks(max_age_hours=72):
    networks = load_networks()
    now = time.time()
    cleaned = [n for n in networks if n.get("permanent") or now - n.get("timestamp",now) < max_age_hours*3600]
    save_networks(cleaned)

def check_captive_portal(test_url="http://clients3.google.com/generate_204"):
    try:
        r = requests.get(test_url, timeout=5)
        if r.status_code != 204:
            return True, r.url
        return False, None
    except:
        return True, None

def get_system_status():
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)'")
    mem = subprocess.getoutput("free -m")
    temp = subprocess.getoutput("vcgencmd measure_temp || echo 'N/A'")
    net = subprocess.getoutput("ifstat -i wlan0 1 1 || echo 'N/A'")
    return {"cpu":cpu,"mem":mem,"temp":temp,"net":net}

@app.route("/")
def index():
    networks = load_networks()
    return render_template("index.html", networks=networks, is_hp=IS_HP)

@app.route("/status")
def status():
    return jsonify(get_system_status())

@app.route("/refresh_networks")
def refresh_networks():
    clean_old_networks()
    return jsonify({"result":"ok"})

if __name__=="__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

chmod +x /usr/local/bin/travelwifi/travelwifi_final.py

# --- WebUI ---
cat <<'EOF' > /usr/local/bin/travelwifi/templates/index.html
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>TravelWiFi</title>
<link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
</head>
<body class="bg-gray-100 font-sans">
<header class="flex items-center justify-between p-4 bg-blue-500 text-white">
  <div class="flex items-center space-x-2">
    <img src="/static/duck_logo.png" alt="Ente" class="h-10 w-10 rounded-full">
    <h1 class="text-xl font-bold">TravelWiFi</h1>
  </div>
  <div>Status: <span class="font-semibold">{{ 'HP Mini Mode' if is_hp else 'Pi Mode' }}</span></div>
</header>
<main class="p-4 grid grid-cols-1 md:grid-cols-3 gap-4">
  <div class="bg-white p-4 rounded shadow">
    <h2 class="text-lg font-bold mb-2">Netzwerke</h2>
    <ul>
      {% for n in networks %}
      <li class="mb-1">{{n['ssid']}} - {{n.get('signal','N/A')}}dBm {% if n.get('permanent') %}(Permanent){% endif %}</li>
      {% endfor %}
    </ul>
  </div>
  <div class="bg-white p-4 rounded shadow">
    <h2 class="text-lg font-bold mb-2">Systemstatus</h2>
    <p>Siehe /status API</p>
  </div>
  <div class="bg-white p-4 rounded shadow">
    <h2 class="text-lg font-bold mb-2">Captive Portal</h2>
    {% if is_hp %}<p>Automatische Portal-Erkennung aktiv</p>{% else %}<p>Nicht aktiviert auf Pi</p>{% endif %}
  </div>
</main>
</body>
</html>
EOF

# --- Systemd Service ---
cat <<'EOF' > /etc/systemd/system/travelwifi.service
[Unit]
Description=TravelWiFi Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/travelwifi/travelwifi_final.py
Restart=always
User=root
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable travelwifi.service
systemctl start travelwifi.service

echo "[TravelWiFi] Installation abgeschlossen. WebUI erreichbar auf http://<IP>:5000"
