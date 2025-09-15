#!/bin/bash

# Dieses Skript automatisiert die Installation und Einrichtung des TravelWifi-Systems.

echo "Starte Installation des TravelWifi-Systems..."

# 1. Überprüfung der Root-Rechte
if [[ $EUID -ne 0 ]]; then
   echo "Dieses Skript muss mit Root-Rechten ausgeführt werden." 
   exit 1
fi

# 2. Installation der benötigten Systempakete
echo "Installiere Systempakete (git, python3-venv, hostapd, dnsmasq, net-tools, etc.)..."
apt-get update
apt-get install -y git python3 python3-pip python3-venv hostapd dnsmasq net-tools dnsutils

# 3. Erstellung der virtuellen Python-Umgebung
echo "Erstelle eine virtuelle Python-Umgebung..."
python3 -m venv venv

# 4. Installation der benötigten Python-Bibliotheken
echo "Installiere Python-Bibliotheken (Flask, psutil, requests) in die virtuelle Umgebung..."
./venv/bin/pip install Flask psutil requests

# 5. Erstellung der Verzeichnisstruktur
echo "Erstelle die Verzeichnisstruktur..."
mkdir -p web/templates web/static/css web/static/images
mkdir -p scripts
mkdir -p systemd

# 6. Erstellung der systemd-Service-Datei
echo "Erstelle temporäre Service-Datei..."
cat > systemd/travelwifi.service <<EOL
[Unit]
Description=TravelWifi Webserver
After=network.target

[Service]
ExecStart=$(pwd)/venv/bin/python $(pwd)/webserver.py
WorkingDirectory=$(pwd)
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

# 7. Kopieren des Service-Files und Aktivierung des Dienstes
echo "Kopiere Service-Datei und aktiviere den Dienst..."
cp systemd/travelwifi.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable travelwifi.service

# 8. Setze Berechtigungen für das Hauptskript
echo "Setze Ausführungsrechte für webserver.py..."
chmod +x webserver.py

# 9. Konfiguriere sudoers für sichere Netzwerkbefehle ohne Passwort
echo "Konfiguriere sudoers für sichere Netzwerkbefehle..."
echo "gdl ALL=(ALL) NOPASSWD: /usr/sbin/hostapd, /usr/sbin/dnsmasq, /usr/bin/nmcli, /usr/bin/ping" >> /etc/sudoers.d/travelwifi
chown gdl:gdl /etc/sudoers.d/travelwifi
chmod 0440 /etc/sudoers.d/travelwifi

echo "Installation abgeschlossen. Bitte starten Sie das System neu, um den Dienst zu aktivieren."