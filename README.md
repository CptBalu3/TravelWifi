# TravelWiFi

**TravelWiFi** verwandelt einen Raspberry Pi oder kompatible Hardware in einen mobilen WLAN-Repeater, der automatisch bekannte Netze verbindet und ein einheitliches AP-WLAN bereitstellt.

---

## Features

- **Automatische Verbindung** mit bekannten Netzwerken
- **Captive Portal Handling** (manuelle Anmeldung am AP möglich)
- **Dual Adapter Support:** 
  - Ein Adapter als Client (externe Antenne empfohlen)
  - Ein Adapter als Access Point
- **Dynamische AP-Kanalwahl** basierend auf dem Client-WLAN
- **Lite-Mode:** abgespeckter AP bei fehlendem Adapter oder Ressourcenbeschränkung
- **Status-API:** CPU, RAM, Temperatur, Netzwerkstatistik
- **Wigle-Abfrage:** Upload und lokale Speicherung bekannter Netze
- **Netzwerke permanent/static markieren**
- **NTP / Zeitsynchronisierung**
- **Mobil-optimiertes WebUI**
- **Ente-Logo** als freundliches Branding
- **Systemd Service** für Autostart und Auto-Restart

---

## Installation

```bash
git clone <DEIN_REPO_URL> TravelWiFi
cd TravelWiFi
chmod +x install.sh
./install.sh
