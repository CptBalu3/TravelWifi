import json
import os
from flask import Flask, render_template, request, redirect, url_for
import threading
import time

# --- Globale Variablen ---
CONFIG_FILE = 'config.json'
CONFIG_BAK_FILE = 'config.json.bak'
config = {}
is_power_saving = False

# --- Konfigurations-Funktionen ---
def load_config():
    """Lädt die Konfiguration aus der Hauptdatei oder dem Backup."""
    global config
    if not os.path.exists(CONFIG_FILE):
        print("Konfigurationsdatei nicht gefunden. Starte den Setup-Wizard.")
        config = {"setup_complete": False}
        return False

    try:
        with open(CONFIG_FILE, 'r') as f:
            config = json.load(f)
        print("Konfiguration erfolgreich geladen.")
        return True
    except json.JSONDecodeError:
        print("Fehler: Konfigurationsdatei korrupt. Versuche, Backup zu laden.")
        if os.path.exists(CONFIG_BAK_FILE):
            try:
                with open(CONFIG_BAK_FILE, 'r') as f:
                    config = json.load(f)
                print("Backup-Konfiguration erfolgreich geladen.")
                return True
            except json.JSONDecodeError:
                print("Fehler: Backup-Datei ebenfalls korrupt. Starte den Setup-Wizard.")
                config = {"setup_complete": False}
                return False
        else:
            print("Kein Backup gefunden. Starte den Setup-Wizard.")
            config = {"setup_complete": False}
            return False

def save_config():
    """Speichert die Konfiguration atomar, um Korruption zu verhindern."""
    global config
    temp_file = CONFIG_FILE + '.tmp'
    try:
        # 1. Schreibe in temporäre Datei
        with open(temp_file, 'w') as f:
            json.dump(config, f, indent=2)
        
        # 2. Benenne alte Datei als Backup um
        if os.path.exists(CONFIG_FILE):
            os.rename(CONFIG_FILE, CONFIG_BAK_FILE)
        
        # 3. Benenne temporäre Datei um
        os.rename(temp_file, CONFIG_FILE)
        
        print("Konfiguration erfolgreich gespeichert.")
        return True
    except Exception as e:
        print(f"Fehler beim Speichern der Konfiguration: {e}. Versuche, das Original wiederherzustellen.")
        if os.path.exists(CONFIG_BAK_FILE):
            os.rename(CONFIG_BAK_FILE, CONFIG_FILE)
        return False

# --- Flask-App Initialisierung ---
app = Flask(__name__)

# --- Routen ---
@app.route('/')
def index():
    if not config.get("setup_complete", True):
        return redirect(url_for('setup_wizard'))
    
    # Hier kommt später die Logik für Netzwerk-Scans und die Anzeige.
    return render_template('index.html', config=config)

@app.route('/setup_wizard', methods=['GET', 'POST'])
def setup_wizard():
    if request.method == 'POST':
        # Verarbeite Formular und speichere erste Konfiguration
        ap_iface = request.form.get('ap_interface')
        client_iface = request.form.get('client_interface')
        
        new_config = {
            "setup_complete": True,
            "ap_interface": ap_iface,
            "client_interface": client_iface,
            "ap_ssid": "TravelWifi",
            "ap_password": "meinpasswort",
            "power_saving_timeout": 1800,
            "wigle_api": {
                "api_name": "",
                "api_token": ""
            },
            "networks": []
        }
        
        global config
        config = new_config
        
        save_config()
        return redirect(url_for('index'))
    
    # Hier kommt die Logik für den initialen Check hin
    return render_template('setup_wizard.html')

@app.route('/settings', methods=['GET', 'POST'])
def settings():
    if not config.get("setup_complete", True):
        return redirect(url_for('setup_wizard'))

    if request.method == 'POST':
        # Hier kommt die Logik zum Speichern der Einstellungen hin.
        return redirect(url_for('settings'))
    
    return render_template('settings.html', config=config)

@app.route('/diagnose')
def diagnose():
    if not config.get("setup_complete", True):
        return redirect(url_for('setup_wizard'))
    # Hier kommt die Logik für die Diagnose-Seite hin.
    return render_template('diagnose.html', config=config)

@app.route('/static_networks')
def static_networks():
    if not config.get("setup_complete", True):
        return redirect(url_for('setup_wizard'))
    # Hier kommt die Logik zur Verwaltung der statischen Netze hin.
    return render_template('static_networks.html', config=config)

@app.route('/help')
def help_page():
    return render_template('help.html')

# --- Haupt-Ausführung ---
if __name__ == '__main__':
    load_config()
    app.run(host='0.0.0.0', port=80, debug=True)