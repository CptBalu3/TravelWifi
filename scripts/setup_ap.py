import os
import subprocess
import json

CONFIG_FILE = '../config.json'

def get_config():
    """Lädt die Konfiguration aus der config.json."""
    try:
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        return None

def start_ap(ap_interface, ap_ssid, ap_password):
    """Startet den Access Point und den DHCP-Server."""
    print(f"Starte AP auf {ap_interface} mit SSID {ap_ssid}...")

    # 1. Erstelle die hostapd.conf
    hostapd_conf = f"""
interface={ap_interface}
driver=nl80211
ssid={ap_ssid}
hw_mode=g
channel=7
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase={ap_password}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
"""
    with open('/etc/hostapd/hostapd.conf', 'w') as f:
        f.write(hostapd_conf)

    # 2. Starte hostapd
    try:
        subprocess.run(['hostapd', '/etc/hostapd/hostapd.conf'], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Fehler beim Starten von hostapd: {e}")
        return False

    # 3. Erstelle dnsmasq.conf
    dnsmasq_conf = f"""
interface={ap_interface}
dhcp-range=192.168.4.2,192.168.4.254,12h
dhcp-option=option:router,192.168.4.1
dhcp-option=option:dns-server,192.168.4.1
bind-interfaces
"""
    with open('/etc/dnsmasq.d/ap.conf', 'w') as f:
        f.write(dnsmasq_conf)
    
    # 4. Starte dnsmasq
    try:
        subprocess.run(['dnsmasq', '--conf-file=/etc/dnsmasq.d/ap.conf'], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Fehler beim Starten von dnsmasq: {e}")
        return False
        
    return True

def stop_ap(ap_interface):
    """Stoppt den Access Point und den DHCP-Server."""
    print(f"Stoppe AP auf {ap_interface}...")
    
    try:
        subprocess.run(['pkill', 'hostapd'], check=True)
        subprocess.run(['pkill', 'dnsmasq'], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Fehler beim Stoppen der Dienste: {e}")
        return False
        
    return True

if __name__ == '__main__':
    config = get_config()
    if config:
        # Beispielaufruf
        start_ap(config['ap_interface'], config['ap_ssid'], config['ap_password'])
    else:
        print("Konfiguration konnte nicht geladen werden.")