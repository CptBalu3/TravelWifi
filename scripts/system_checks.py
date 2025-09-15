import os
import subprocess
import psutil
import json

CONFIG_FILE = '../config.json'

def check_config_file():
    """Prüft, ob die Konfigurationsdatei vorhanden und gültig ist."""
    if not os.path.exists(CONFIG_FILE):
        return {"status": "error", "message": "Konfigurationsdatei nicht gefunden."}
    try:
        with open(CONFIG_FILE, 'r') as f:
            json.load(f)
        return {"status": "ok", "message": "Konfigurationsdatei gültig."}
    except json.JSONDecodeError:
        return {"status": "error", "message": "Konfigurationsdatei ist korrupt."}

def check_network_interfaces(ap_interface, client_interface):
    """Prüft, ob die benötigten Netzwerk-Interfaces existieren."""
    interfaces = os.listdir('/sys/class/net/')
    result = {"status": "ok", "message": "Netzwerk-Interfaces sind vorhanden."}
    if ap_interface not in interfaces:
        result["status"] = "error"
        result["message"] = f"AP-Adapter '{ap_interface}' nicht gefunden."
    if client_interface and client_interface not in interfaces:
        result["status"] = "error"
        result["message"] = f"Client-Adapter '{client_interface}' nicht gefunden."
    return result

def check_service_status(service_name):
    """Prüft, ob ein Systemdienst läuft."""
    try:
        subprocess.run(['systemctl', 'is-active', service_name], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"status": "ok", "message": f"Dienst '{service_name}' läuft."}
    except subprocess.CalledProcessError:
        return {"status": "error", "message": f"Dienst '{service_name}' ist nicht aktiv."}

def get_system_info():
    """Sammelt grundlegende Systeminformationen."""
    cpu_percent = psutil.cpu_percent(interval=1)
    ram = psutil.virtual_memory()
    disk = psutil.disk_usage('/')

    return {
        "cpu": cpu_percent,
        "ram_total": round(ram.total / (1024 * 1024), 2),
        "ram_used": round(ram.used / (1024 * 1024), 2),
        "ram_percent": ram.percent,
        "disk_total": round(disk.total / (1024 * 1024 * 1024), 2),
        "disk_used": round(disk.used / (1024 * 1024 * 1024), 2),
        "disk_percent": disk.percent
    }

def run_startup_diagnostics():
    """Führt alle Diagnoseschritte aus und gibt einen Bericht zurück."""
    diagnostics = {}
    
    # 1. Konfigurationsprüfung
    diagnostics['config'] = check_config_file()
    
    # Lade Konfiguration, um Adapter zu prüfen
    if diagnostics['config']['status'] == 'ok':
        with open(CONFIG_FILE, 'r') as f:
            cfg = json.load(f)
        diagnostics['interfaces'] = check_network_interfaces(cfg['ap_interface'], cfg['client_interface'])
    
    # 2. Dienst-Prüfung
    diagnostics['hostapd_service'] = check_service_status('hostapd')
    diagnostics['dnsmasq_service'] = check_service_status('dnsmasq')
    
    return diagnostics
    
if __name__ == '__main__':
    # Beispielaufruf
    print(run_startup_diagnostics())