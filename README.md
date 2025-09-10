# TravelWiFi

## Projektbeschreibung
TravelWiFi ist ein tragbarer WLAN-Repeater mit AP-Funktion, Captive-Portal-Handling (HP Mini), Wigle-Integration, moderner WebUI und Status-API.

## Installation
1. Root-Rechte sicherstellen
2. Dateien per Git klonen oder Copy-Paste einfügen
3. `sudo ./install.sh` ausführen
4. Browser öffnen: `http://<IP>:5000`

## Features
- Automatische WLAN-Verbindung
- AP-WLAN "mage_camp" (Wuschel2021)
- WebUI mobilfreundlich mit Ente-Logo
- Systemstatus: CPU, RAM, Temperatur, Traffic
- Captive Portal Handling (nur HP Mini)
- Wigle-Integration (nur HP Mini)
- NTP-Zeit, Logging, Bereinigung alter Netzwerke
- Light Mode / HTTPS optional

## Git-Struktur
travelwifi/
│
├─ install.sh
├─ README.md
├─ travelwifi_final.py
├─ templates/
│ └─ index.html
└─ static/
└─ duck_logo.png


## Hinweise
- Pi: Captive Portal muss manuell über Endgerät angemeldet werden
- HP Mini: Captive Portal wird automatisch erkannt
- System startet nach Stromausfall automatisch
- Netzwerke können permanent gespeichert werden
