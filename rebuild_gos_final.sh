#!/bin/bash
# rebuild_gos_final.sh — Rebuild GoSpot (gospot-cli) final version
# Compatible Termux / iSH / macOS / Linux
# Author: Mauricio-100

ROOT_DIR="$(pwd)"
PYTHON=python3
PKG_NAME="gospot-cli"
REQUIREMENTS="${ROOT_DIR}/requirements.txt"

echo "=== Rebuild GoSpot (final & amélioré) — racine: ${ROOT_DIR} ==="

# 1/ Création des dossiers
echo "[1/12] Création des dossiers..."
mkdir -p gospot_pkg/modules
mkdir -p gospot_pkg/sdk

# 2/ Création __init__.py
echo "[2/12] Création __init__.py..."
touch gospot_pkg/__init__.py
touch gospot_pkg/modules/__init__.py

# 3/ Écriture modules/system.py
echo "[3/12] Écriture: modules/system.py..."
cat > gospot_pkg/modules/system.py << 'PYMOD'
import os, subprocess, platform

def check_package(pkg):
    """Check if package exists"""
    try:
        subprocess.check_output(["which", pkg])
        return True
    except:
        return False

def run_command(cmd):
    return subprocess.getoutput(cmd)

def detect_os():
    os_name = platform.system().upper()
    if "ANDROID" in os_name:
        return "TERMUX"
    return os_name
PYMOD

# 4/ Écriture modules/ui.py (couleurs via rich fallback)
echo "[4/12] Écriture: modules/ui.py..."
cat > gospot_pkg/modules/ui.py << 'PYMOD'
try:
    from rich import print
except ImportError:
    def print(*args, **kwargs):
        __builtins__.print(*args)
PYMOD

# 5/ Écriture modules/network.py
echo "[5/12] Écriture: modules/network.py..."
cat > gospot_pkg/modules/network.py << 'PYMOD'
import subprocess

def scan_network():
    print("[🌐] Scan réseau local...")
    try:
        result = subprocess.getoutput("nmap -sn 192.168.1.0/24")
        print(result)
    except Exception as e:
        print(f"[❌] Erreur scan: {e}")
PYMOD

# 6/ Écriture modules/ssh_utils.py
echo "[6/12] Écriture: modules/ssh_utils.py..."
cat > gospot_pkg/modules/ssh_utils.py << 'PYMOD'
import os

def list_keys():
    ssh_dir = os.path.expanduser("~/.ssh")
    if os.path.exists(ssh_dir):
        return os.listdir(ssh_dir)
    return []
PYMOD

# 7/ Écriture modules/sysinfo.py
echo "[7/12] Écriture: modules/sysinfo.py..."
cat > gospot_pkg/modules/sysinfo.py << 'PYMOD'
import platform
import os

def system_info():
    info = {
        "OS": platform.system(),
        "Release": platform.release(),
        "Version": platform.version(),
        "User": os.getenv("USER") or os.getenv("USERNAME")
    }
    return info
PYMOD

# 8/ Écriture gospot_pkg/cli.py
echo "[8/12] Écriture: gospot_pkg/cli.py..."
cat > gospot_pkg/cli.py << 'PYCLI'
import sys
from gospot_pkg.modules import system, network, ssh_utils, sysinfo
from gospot_pkg.modules import ui

def setup_env():
    real_os = system.detect_os()
    print("\n[⚙️] Vérification des outils essentiels...")
    is_termux = "TERMUX" in real_os
    pkgs = ["openssh", "nmap", "curl", "git"]

    for p in pkgs:
        if is_termux:
            if not system.check_package(p):
                os.system(f"pkg install -y {p}")
        elif "DARWIN" in real_os:
            if not system.check_package(p):
                os.system(f"brew install {p}")
        elif "LINUX" in real_os:
            if not system.check_package(p):
                os.system(f"sudo apt install -y {p} || sudo pacman -S --noconfirm {p}")

    print("\n[✅] Configuration terminée.\n")

def main_menu():
    ui.print("""
  ____       _____             _
 / ___| ___ | ____|_ __   ___ | |_
 \___ \/ _ \|  _| | '_ \ / _ \| __|
  ___) | (_) | |___| | | | (_) | |_
 |____/ \___/|_____|_| |_|\___/|__|
    Hybrid Python + Shell CLI
   by Mauricio-100 (GoSpot)
""")
    while True:
        ui.print("""
[1] 🌐 Scanner le réseau local
[2] 🔐 Gérer les clés SSH
[3] 🧰 Installer/Mettre à jour les outils SDK
[4] ⚙️ Vérifier le système et l’environnement
[5] 🚪 Quitter
""")
        choice = input("Choisis une option ➤ ").strip()
        if choice == "1":
            network.scan_network()
        elif choice == "2":
            ui.print(ssh_utils.list_keys())
        elif choice == "3":
            setup_env()
        elif choice == "4":
            info = sysinfo.system_info()
            ui.print(info)
        elif choice == "5":
            sys.exit(0)
        else:
            ui.print("[❌] Option invalide.")
PYCLI

# 9/ Création sdk stubs
echo "[9/12] Création sdk stubs..."
touch gospot_pkg/sdk/admin.sh
touch gospot_pkg/sdk/detect_os.sh
touch gospot_pkg/sdk/monitor.sh
touch gospot_pkg/sdk/nettools.sh
touch gospot_pkg/sdk/speedtest.sh
touch gospot_pkg/sdk/ssh.sh
touch gospot_pkg/sdk/sysinfo.sh
touch gospot_pkg/sdk/tools.sh

# 10/ Création requirements.txt
echo "[10/12] Création requirements.txt..."
cat > requirements.txt << 'REQ'
rich
psutil
requests
speedtest-cli
REQ

# 11/ Permissions
echo "[11/12] Permissions..."
chmod +x gospot_pkg/cli.py
chmod +x gospot_pkg/sdk/*
chmod +x rebuild_gos_final.sh

# 12/ Installation pip package
echo "[12/12] (Re)installation pip package..."
if [ -f setup.py ]; then
    rm -f setup.py
fi

cat > setup.py << 'SETUP'
from setuptools import setup, find_packages

setup(
    name="gospot-cli",
    version="1.0.0",
    packages=find_packages(),
    entry_points={
        "console_scripts": [
            "gos=gospot_pkg.cli:main_menu"
        ]
    },
    install_requires=open("requirements.txt").read().splitlines()
)
SETUP

echo "[INFO] Installation du package via pip..."
if [ -d "/data/data/com.termux/files/usr" ]; then
    echo "[INFO] Termux détecté : pas de mise à jour pip"
    python3 -m pip install . --no-cache-dir
else
    python3 -m pip install --upgrade pip
    python3 -m pip install .
fi

echo "[✅] GoSpot rebuild terminé !"
