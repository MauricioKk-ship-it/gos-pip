#!/bin/bash
# rebuild_gos_final.sh
# === Build GoSpot final & amélioré ===

ROOT_DIR=$(pwd)
echo "=== Build GoSpot (final & amélioré) — racine: $ROOT_DIR ==="

# 1. Création des dossiers
echo "[1/12] Création des dossiers..."
mkdir -p gospot_pkg/modules gospot_pkg/sdk

# 2. Création __init__.py
echo "[2/12] Création __init__.py..."
touch gospot_pkg/__init__.py
touch gospot_pkg/modules/__init__.py

# 3. Écriture modules/system.py
echo "[3/12] Écriture modules/system.py..."
cat > gospot_pkg/modules/system.py << 'PYTHON'
import os
import subprocess

def check_package(pkg):
    """Check if a system package is installed."""
    result = subprocess.getoutput(f"which {pkg}")
    return result != ""
PYTHON

# 4. Écriture modules/ui.py
echo "[4/12] Écriture modules/ui.py..."
cat > gospot_pkg/modules/ui.py << 'PYTHON'
try:
    from rich.console import Console
    console = Console()
except ImportError:
    class Console:
        def print(self, *args, **kwargs):
            print(*args)
    console = Console()
PYTHON

# 5. Écriture modules/network.py
echo "[5/12] Écriture modules/network.py..."
cat > gospot_pkg/modules/network.py << 'PYTHON'
import subprocess
from .ui import console

def scan_network():
    console.print("[🌐] Scan réseau local...")
    try:
        result = subprocess.getoutput("nmap -sn 192.168.1.0/24")
        console.print(result)
    except KeyboardInterrupt:
        console.print("[!] Scan interrompu.")
PYTHON

# 6. Écriture modules/ssh_utils.py
echo "[6/12] Écriture modules/ssh_utils.py..."
cat > gospot_pkg/modules/ssh_utils.py << 'PYTHON'
from .ui import console

def list_keys():
    console.print("[🔐] Gestion des clés SSH (stub)...")
PYTHON

# 7. Écriture modules/sysinfo.py
echo "[7/12] Écriture modules/sysinfo.py..."
cat > gospot_pkg/modules/sysinfo.py << 'PYTHON'
import platform
from .ui import console

def system_info():
    console.print(f"[⚙️] Système: {platform.system()} {platform.release()}")
PYTHON

# 8. Écriture gospot_pkg/cli.py
echo "[8/12] Écriture gospot_pkg/cli.py..."
cat > gospot_pkg/cli.py << 'PYTHON'
import sys
import os
from gospot_pkg.modules import system, network, ssh_utils, sysinfo, ui
console = ui.console

def setup_env():
    pkgs = ["openssh", "nmap", "curl", "git"]
    prefix = os.getenv("PREFIX", "")
    is_termux = "com.termux" in prefix
    real_os = sys.platform.upper()

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

    console.print("\n[✅] Configuration terminée.\n")

def main_menu():
    while True:
        console.print("""
  ____       _____             _
 / ___| ___ | ____|_ __   ___ | |_
 \___ \/ _ \|  _| | '_ \ / _ \| __|
  ___) | (_) | |___| | | | (_) | |_
 |____/ \___/|_____|_| |_|\___/|__|
    Hybrid Python + Shell CLI
   by Mauricio-100 (GoSpot)
""")
        console.print("[1] 🌐 Scanner le réseau local")
        console.print("[2] 🔐 Gérer les clés SSH")
        console.print("[3] 🧰 Installer/Mettre à jour les outils SDK")
        console.print("[4] ⚙️ Vérifier le système et l’environnement")
        console.print("[5] 🚪 Quitter")
        choice = input("Choisis une option ➤ ").strip()
        if choice == "1":
            network.scan_network()
        elif choice == "2":
            ssh_utils.list_keys()
        elif choice == "3":
            setup_env()
        elif choice == "4":
            sysinfo.system_info()
        elif choice == "5":
            console.print("Au revoir !")
            sys.exit(0)
        else:
            console.print("[!] Choix invalide.")
PYTHON

# 9. Création sdk stubs
echo "[9/12] Création sdk stubs..."
touch gospot_pkg/sdk/{admin.sh,monitor.sh,nettools.sh,speedtest.sh,ssh.sh,sysinfo.sh,tools.sh}

# 10. Création requirements.txt
echo "[10/12] Création requirements.txt..."
cat > requirements.txt << 'REQ'
rich
colorama
ora
chalk
paramiko
requests
REQ

# 11. Permissions
echo "[11/12] Permissions..."
chmod +x gospot_pkg/cli.py
chmod +x gospot_pkg/sdk/*

# 12. Création setup.py
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
        "colorama",
        "ora",
        "chalk",
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
