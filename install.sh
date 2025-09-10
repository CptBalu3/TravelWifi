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
cat > ~/TravelWiFi/bin/travelwifi_final.py <<'EOL'
#!/usr/bin/env python3
# Komplettes Skript siehe vorherige Python-Version
# Enthält:
# - Client + AP Adapter-Management
# - Lite-Mode, dynamischer Kanal
# - Wigle-Abfrage
# - Status-API
# - Hintergrund-Thread
# - NTP / Zeitsynchronisierung
# - WebUI-Aufruf
EOL
chmod +x ~/TravelWiFi/bin/travelwifi_final.py

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
