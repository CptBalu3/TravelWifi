#!/bin/bash

# Dieses Skript automatisiert die Installation und Einrichtung des TravelWifi-Systems.

echo "Starte Installation des TravelWifi-Systems..."

# 1. Überprüfung der Root-Rechte
if [[ $EUID -ne 0 ]]; then
   echo "Dieses Skript muss mit Root-Rechten ausgeführt werden." 
   exit 1
fi

# 2. Installation der benötigten Systempakete
echo "Installiere Systempakete (hostapd, dnsmasq, etc.)..."
apt-get update
apt-get install -y git python3 python3-pip hostapd dnsmasq net-tools dnsutils

# 3. Installation der benötigten Python-Bibliotheken
echo "Installiere Python-Bibliotheken (Flask, psutil, requests)..."
pip3 install Flask psutil requests

# 4. Erstellung der Verzeichnisstruktur
echo "Erstelle die Verzeichnisstruktur..."
mkdir -p web/templates web/static/css web/static/images
mkdir -p scripts
mkdir -p systemd

# 5. Erstellung der systemd-Service-Datei
echo "Erstelle temporäre Service-Datei..."
cat > systemd/travelwifi.service <<EOL
[Unit]
Description=TravelWifi Webserver
After=network.target

[Service]
ExecStart=/usr/bin/python3 $(pwd)/webserver.py
WorkingDirectory=$(pwd)
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

# 6. Kopieren des Service-Files und Aktivierung des Dienstes
echo "Kopiere Service-Datei und aktiviere den Dienst..."
cp systemd/travelwifi.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable travelwifi.service

# 7. Setze Berechtigungen für das Hauptskript
echo "Setze Ausführungsrechte für webserver.py..."
chmod +x webserver.py

# 8. Konfiguriere sudoers für sichere Netzwerkbefehle ohne Passwort
echo "Konfiguriere sudoers für sichere Netzwerkbefehle..."
echo "pi ALL=(ALL) NOPASSWD: /usr/sbin/hostapd, /usr/sbin/dnsmasq, /usr/bin/nmcli, /usr/bin/ping" >> /etc/sudoers.d/travelwifi

echo "Installation abgeschlossen. Bitte starten Sie das System neu, um den Dienst zu aktivieren."