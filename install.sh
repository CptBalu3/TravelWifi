#!/bin/bash
# TravelWiFi Installer - Final Version mit allen Features
set -e

echo "[TravelWiFi] Installation gestartet..."

# Pakete installieren
sudo apt update
sudo apt install -y hostapd dnsmasq iw net-tools python3 python3-pip wireless-tools curl

# Pip-Module
sudo pip3 install --upgrade pip
sudo pip3 install flask requests psutil ifaddr

# Verzeichnisse
mkdir -p ~/TravelWiFi/web/templates
mkdir -p ~/TravelWiFi/web/static/img
mkdir -p ~/TravelWiFi/config

# networks.json anlegen, falls nicht vorhanden
if [ ! -f ~/TravelWiFi/config/networks.json ]; then
cat > ~/TravelWiFi/config/networks.json <<EOL
[]
EOL
fi

# wigle.conf anlegen, falls nicht vorhanden
if [ ! -f ~/TravelWiFi/config/wigle.conf ]; then
cat > ~/TravelWiFi/config/wigle.conf <<EOL
[wigle]
username = ""
password = ""
EOL
fi

# index.html
cat > ~/TravelWiFi/web/templates/index.html <<'EOL'
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
<tr>
  <td>{{ n.ssid }}</td>
  <td>{{ n.signal or '-' }}</td>
  <td>
    <input type="checkbox" class="permanent-toggle" data-ssid="{{ n.ssid }}" {% if n.permanent %}checked{% endif %}>
  </td>
</tr>
{% endfor %}
</table>
<script>
document.querySelectorAll('.permanent-toggle').forEach(el => {
  el.addEventListener('change', function() {
    fetch('/toggle_permanent/' + encodeURIComponent(this.dataset.ssid), {
      method: 'POST'
    }).then(resp => resp.json())
      .then(data => console.log('Updated permanent:', data))
      .catch(err => console.error(err));
  });
});
</script>
</body>
</html>
EOL

# Ente aus öffentlicher Quelle
curl -o ~/TravelWiFi/web/static/img/ente.png https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Cartoon_duck.svg/64px-Cartoon_duck.svg.png

# travelwifi_final.py
cat > ~/TravelWiFi/travelwifi_final.py <<'EOL'
#!/usr/bin/env python3
import os, json, subprocess, time, threading
from flask import Flask, render_template, jsonify
import psutil

app = Flask(__name__)

CONFIG_DIR = os.path.expanduser("~/TravelWiFi/config")
NETWORK_FILE = os.path.join(CONFIG_DIR, "networks.json")
WIGLE_CONF = os.path.join(CONFIG_DIR, "wigle.conf")

LITE_MODE = False

def load_networks():
    if os.path.exists(NETWORK_FILE):
        return json.load(open(NETWORK_FILE))
    return []

def save_networks(data):
    with open(NETWORK_FILE, "w") as f:
        json.dump(data, f, indent=2)

def scan_networks():
    try:
        result = subprocess.run(["sudo", "iwlist", "wlan0", "scan"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output = result.stdout.decode()
        networks = []
        for line in output.split("\n"):
            if "ESSID" in line:
                ssid = line.split('"')[1]
                networks.append({"ssid": ssid, "signal": 0})
        return networks
    except:
        return []

@app.route("/")
def index():
    db = load_networks()
    available = scan_networks()
    permanent_nets = [n for n in db if n.get("permanent", False)]
    non_permanent_nets = [n for n in available if not any(d["ssid"]==n["ssid"] and d.get("permanent",False) for d in db)]
    non_permanent_nets.sort(key=lambda x: x.get("signal",0), reverse=True)
    display_nets = non_permanent_nets + permanent_nets
    return render_template("index.html", networks=display_nets)

@app.route("/toggle_permanent/<ssid>", methods=["POST"])
def toggle_permanent(ssid):
    db = load_networks()
    for n in db:
        if n["ssid"] == ssid:
            n["permanent"] = not n.get("permanent", False)
            break
    save_networks(db)
    return jsonify({"success": True, "ssid": ssid, "permanent": n["permanent"]})

@app.route("/status")
def status():
    cpu = psutil.cpu_percent()
    mem = psutil.virtual_memory().percent
    temp = 0.0
    try:
        temp = float(subprocess.check_output(["vcgencmd","measure_temp"]).decode().split("=")[1].split("'")[0])
    except:
        pass
    net = psutil.net_io_counters(pernic=True)
    wlan_stats = net.get("wlan0", {"bytes_sent":0,"bytes_recv":0})
    return jsonify({"cpu":cpu,"memory":mem,"temp":temp,"wlan_bytes_sent":wlan_stats.bytes_sent,"wlan_bytes_recv":wlan_stats.bytes_recv})

def get_client_channel(interface="wlan0"):
    """Ermittelt den Kanal des verbundenen Client-WLANs"""
    try:
        output = subprocess.check_output(["iwlist", interface, "channel"]).decode()
        for line in output.splitlines():
            if "Current Frequency" in line and "Channel" in line:
                return int(line.split("Channel")[1].strip().split(" ")[0])
    except:
        pass
    return 6  # Fallback

def setup_ap(lite_mode=False):
    channel = get_client_channel("wlan0")
    ap_conf = f"""
interface=wlan1
driver=nl80211
ssid=TravelWiFi
hw_mode=g
channel={channel}
wmm_enabled=0
"""
    if not lite_mode:
        ap_conf += "wpa=2\nwpa_passphrase=Wuschel2021\n"
    os.makedirs("/tmp/travelwifi", exist_ok=True)
    with open("/tmp/travelwifi/hostapd.conf", "w") as f:
        f.write(ap_conf)
    subprocess.run(["sudo","systemctl","restart","hostapd"])

def detect_adapters():
    global LITE_MODE
    output = subprocess.run(["lsusb"], stdout=subprocess.PIPE).stdout.decode()
    if "RTL8188" not in output:
        LITE_MODE = True

def wigle_upload(ssid_list):
    if not os.path.exists(WIGLE_CONF): return
    cfg = {}
    with open(WIGLE_CONF) as f:
        for line in f:
            if "=" in line:
                k,v = line.strip().split("=",1)
                cfg[k]=v
    if not cfg.get("username") or not cfg.get("password"): return
    with open(os.path.join(CONFIG_DIR,"wigle_last.json"),"w") as f:
        json.dump(ssid_list,f,indent=2)

def ntp_sync():
    try:
        subprocess.run(["sudo","timedatectl","set-ntp","true"])
    except:
        pass

def background_loop():
    while True:
        detect_adapters()
        setup_ap(lite_mode=LITE_MODE)
        nets = scan_networks()
        wigle_upload(nets)
        ntp_sync()
        time.sleep(30)

if __name__ == "__main__":
    threading.Thread(target=background_loop, daemon=True).start()
    app.run(host="0.0.0.0", port=5000)
EOL

# systemd Service
cat > ~/TravelWiFi/travelwifi.service <<EOL
[Unit]
Description=TravelWiFi Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/$USER/TravelWiFi/travelwifi_final.py
Restart=always
User=$USER
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOL

sudo cp ~/TravelWiFi/travelwifi.service /etc/systemd/system/travelwifi.service
sudo systemctl daemon-reload
sudo systemctl enable travelwifi.service
sudo systemctl start travelwifi.service

echo "[TravelWiFi] Installation abgeschlossen. WebUI läuft auf http://<IP>:5000/"
