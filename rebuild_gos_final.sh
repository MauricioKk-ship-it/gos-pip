#!/bin/bash
# build_gos_final.sh — Rebuild complet GoSpot CLI

ROOT_DIR=$(pwd)
echo "=== Build GoSpot (final & amélioré) — racine: $ROOT_DIR ==="

# 1️⃣ Création des dossiers
echo "[1/12] Création des dossiers..."
mkdir -p gospot_pkg/modules
mkdir -p sdk

# 2️⃣ Création __init__.py
echo "[2/12] Création __init__.py..."
touch gospot_pkg/__init__.py
touch gospot_pkg/modules/__init__.py

# 3️⃣ Écriture modules/system.py
echo "[3/12] Écriture modules/system.py..."
cat > gospot_pkg/modules/system.py << 'PYMOD'
import os, platform, subprocess

def detect_os():
    if "com.termux" in os.getenv("PREFIX",""):
        return "TERMUX"
    return platform.system().upper()

def check_package(pkg):
    try:
        res = subprocess.run(f"which {pkg}", shell=True, stdout=subprocess.PIPE)
        return res.returncode == 0
    except:
        return False
PYMOD

# 4️⃣ Écriture modules/ui.py
echo "[4/12] Écriture modules/ui.py..."
cat > gospot_pkg/modules/ui.py << 'PYUI'
try:
    from rich.console import Console
    console = Console()
    def printc(msg, style="bold green"):
        console.print(msg, style=style)
except ImportError:
    def printc(msg, style=None):
        print(msg)
PYUI

# 5️⃣ Écriture modules/network.py
echo "[5/12] Écriture modules/network.py..."
cat > gospot_pkg/modules/network.py << 'PYNET'
import subprocess
from .ui import printc

def scan_network():
    printc("[🌐] Scan réseau local...")
    try:
        result = subprocess.getoutput("nmap -sn 192.168.1.0/24")
        print(result)
    except KeyboardInterrupt:
        printc("[❌] Scan interrompu.")
PYNET

# 6️⃣ Écriture modules/ssh_utils.py
echo "[6/12] Écriture modules/ssh_utils.py..."
cat > gospot_pkg/modules/ssh_utils.py << 'PYSSH'
from .ui import printc
def list_keys():
    printc("[🔐] Liste des clés SSH...")
    # TODO: Ajouter la logique SSH
PYSSH

# 7️⃣ Écriture modules/sysinfo.py
echo "[7/12] Écriture modules/sysinfo.py..."
cat > gospot_pkg/modules/sysinfo.py << 'PYSYS'
import platform
from .ui import printc
def system_info():
    printc("[⚙️] Infos système:")
    printc(f"OS: {platform.system()} {platform.release()}")
    printc(f"Arch: {platform.machine()}")
PYSYS

# 8️⃣ Écriture gospot_pkg/cli.py
echo "[8/12] Écriture gospot_pkg/cli.py..."
cat > gospot_pkg/cli.py << 'PYCLI'
import sys, os
from gospot_pkg.modules import system, network, ssh_utils, sysinfo, ui
from gospot_pkg.modules.ui import printc

def setup_env():
    real_os = system.detect_os()
    printc("\n[⚙️] Vérification des outils essentiels...")
    pkgs = ["openssh","nmap","curl","git"]

    for p in pkgs:
        if real_os=="TERMUX":
            if not system.check_package(p):
                os.system(f"pkg install -y {p}")
        elif real_os=="DARWIN":
            if not system.check_package(p):
                os.system(f"brew install {p}")
        elif real_os=="LINUX":
            if not system.check_package(p):
                os.system(f"sudo apt install -y {p} || sudo pacman -S --noconfirm {p}")
    printc("\n[✅] Configuration terminée.\n")

def main_menu():
    while True:
        printc("""
  ____       _____             _
 / ___| ___ | ____|_ __   ___ | |_
 \___ \/ _ \|  _| | '_ \ / _ \| __|
  ___) | (_) | |___| | | | (_) | |_
 |____/ \___/|_____|_| |_|\___/|__|
    Hybrid Python + Shell CLI
   by Mauricio-100 (GoSpot)
        """)
        printc("[1] 🌐 Scanner le réseau local\n[2] 🔐 Gérer les clés SSH\n[3] 🧰 Installer/Mettre à jour les outils SDK\n[4] ⚙️ Vérifier le système\n[5] 🚪 Quitter")
        choice = input("Choisis une option ➤ ").strip()
        if choice=="1":
            network.scan_network()
        elif choice=="2":
            ssh_utils.list_keys()
        elif choice=="3":
            setup_env()
        elif choice=="4":
            sysinfo.system_info()
        elif choice=="5":
            printc("[🚪] Bye!")
            sys.exit(0)
        else:
            printc("[❌] Option invalide.")
PYCLI

# 9️⃣ Création sdk stubs
echo "[9/12] Création sdk stubs..."
touch sdk/admin.sh
touch sdk/tools.sh
touch sdk/monitor.sh

# 10️⃣ Création requirements.txt
echo "[10/12] Création requirements.txt..."
cat > requirements.txt << 'REQ'
rich
nmap
paramiko
requests
REQ

# 11️⃣ Permissions
echo "[11/12] Permissions..."
chmod +x gospot_pkg/cli.py
chmod +x gospot_pkg/modules/*.py
chmod +x sdk/*

# 12️⃣ setup.py
echo "[12/12] Création setup.py..."
cat > setup.py << 'PYSETUP'
from setuptools import setup, find_packages

setup(
    name="gospot-cli",
    version="1.0.0",
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        "rich",
        "nmap",
        "paramiko",
        "requests"
    ],
    entry_points={
        "console_scripts": [
            "gos=gospot_pkg.cli:main_menu"
        ]
    },
    python_requires='>=3.8',
)
PYSETUP

echo "[✅] Build terminé. Tu peux maintenant faire :"
echo "pip install . --upgrade"
echo "puis exécuter : gos"
