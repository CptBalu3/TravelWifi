import json
import subprocess
import requests
import re
import base64

CONFIG_FILE = '../config.json'

def get_config():
    """Lädt die Konfiguration aus der config.json."""
    try:
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        return None

def run_sudo_command(command_list):
    """Führt einen Befehl mit sudo aus und gibt die Ausgabe zurück."""
    try:
        # Führt den Befehl mit sudo aus und wartet auf das Ergebnis
        result = subprocess.run(['sudo'] + command_list, capture_output=True, text=True, check=True)
        return {"status": "success", "output": result.stdout}
    except subprocess.CalledProcessError as e:
        return {"status": "error", "message": f"Befehl '{' '.join(command_list)}' fehlgeschlagen. Grund: {e.stderr}"}
    except FileNotFoundError:
        return {"status": "error", "message": f"Befehl '{command_list[0]}' nicht gefunden."}

def scan_networks():
    """Scannt nach verfügbaren WLAN-Netzwerken mit nmcli und gibt eine robuste Ausgabe zurück."""
    result = run_sudo_command(['nmcli', '-t', '-f', 'SSID,SIGNAL,BSSID,CHAN,SECURITY', 'dev', 'wifi', 'list'])
    
    if result['status'] == 'error':
        return []

    networks = []
    # Robusteres Parsing, das leere Zeilen und unnötige Zeichen ignoriert
    for line in result['output'].strip().split('\n'):
        if not line:
            continue
        parts = line.split(':')
        if len(parts) >= 2:
            ssid = parts[0]
            signal = parts[1]
            try:
                networks.append({"ssid": ssid, "signal": int(signal)})
            except ValueError:
                # Signalstärke konnte nicht als Zahl geparst werden
                continue
    return networks

def connect_to_network(ssid, password):
    """Verbindet den Client-Adapter mit einem Netzwerk."""
    config = get_config()
    client_interface = config['client_interface']
    cmd = ['nmcli', 'dev', 'wifi', 'connect', ssid, 'password', password, 'ifname', client_interface]
    result = run_sudo_command(cmd)

    if result['status'] == 'success':
        return {"status": "success", "message": f"Verbunden mit {ssid}."}
    else:
        return {"status": "error", "message": result['message']}

def ping_test(target='8.8.8.8'):
    """Führt einen Ping-Test durch und gibt Latenz und Paketverlust zurück."""
    result = run_sudo_command(['ping', '-c', '4', target])
    
    if result['status'] == 'error':
        return {"status": "error", "message": result['message']}
        
    latency_match = re.search(r'min/avg/max/mdev = ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+) ms', result['output'])
    loss_match = re.search(r'(\d+)% packet loss', result['output'])

    if latency_match and loss_match:
        return {
            "status": "ok",
            "latency": float(latency_match.group(2)),
            "packet_loss": int(loss_match.group(1))
        }
    
    return {"status": "error", "message": "Ping-Ausgabe konnte nicht geparst werden."}

def wigle_search(location):
    """Sucht Netzwerke auf Wigle.net basierend auf einem Standort."""
    config = get_config()
    if not config or not config['wigle_api']['api_name'] or not config['wigle_api']['api_token']:
        return {"status": "error", "message": "WiGLE API-Zugangsdaten fehlen."}
    
    url = f"https://api.wigle.net/api/v2/network/search?location={location}"
    headers = {
        'Authorization': 'Basic ' + base64.b64encode(f"{config['wigle_api']['api_name']}:{config['wigle_api']['api_token']}".encode()).decode()
    }

    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
        return {"status": "success", "networks": data.get("results", [])}
    except requests.exceptions.RequestException as e:
        return {"status": "error", "message": f"Fehler bei der WiGLE-Suche: {e}"}

# Beispielaufruf
if __name__ == '__main__':
    print(scan_networks())
    print(ping_test())