#!/usr/bin/env bash
set -euo pipefail

# rebuild_gos_final.sh
# Rebuild complet et optimisé du package gospot_pkg (GoSpot)
# - crée package, modules, sdk
# - crée requirements.txt
# - installe deps (optionnel)
# - reinstalle le package via pip
# - crée wrapper gos (Termux & POSIX)
#
# Usage:
#   chmod +x rebuild_gos_final.sh
#   ./rebuild_gos_final.sh

ROOT="$(pwd)"
PKG_DIR="${ROOT}/gospot_pkg"
MODULES_DIR="${PKG_DIR}/modules"
SDK_DIR="${PKG_DIR}/sdk"
REQUIREMENTS="${ROOT}/requirements.txt"
PYTHON="$(command -v python3 || command -v python)"
PIP="${PYTHON} -m pip"
WRAPPER_TERMUX="/data/data/com.termux/files/usr/bin/gos"
WRAPPER_LOCAL="${HOME}/.local/bin/gos"

echo
echo "=== Rebuild GoSpot (final & amélioré) — racine: ${ROOT} ==="
echo

# 0) sanity
if [ ! -f "${ROOT}/setup.py" ] && [ ! -f "${ROOT}/pyproject.toml" ]; then
  echo "[NOTICE] setup.py not found — a file will be created by the script."
fi

# create directories
echo "[1/12] Création des dossiers..."
mkdir -p "${MODULES_DIR}" "${SDK_DIR}" "${HOME}/.local/bin"

# __init__ files
echo "[2/12] Création __init__.py..."
cat > "${PKG_DIR}/__init__.py" <<'PYII'
# gospot_pkg package
__all__ = ["cli", "modules", "sdk"]
PYII

cat > "${MODULES_DIR}/__init__.py" <<'MODII'
# gospot_pkg.modules package
MODII

# modules: system.py
echo "[3/12] Écriture modules/system.py..."
cat > "${MODULES_DIR}/system.py" <<'PYSYS'
import shutil
import subprocess

def check_command(cmd):
    """Return True if command found."""
    return shutil.which(cmd) is not None

def run(cmd, capture=False, check=False):
    """Run a shell command (list or string)."""
    import subprocess
    if capture:
        return subprocess.check_output(cmd, shell=isinstance(cmd, str), text=True)
    return subprocess.run(cmd, shell=isinstance(cmd, str), check=check)
PYSYS

# modules: ui.py (rich-friendly)
echo "[4/12] Écriture modules/ui.py (couleurs via rich fallback)..."
cat > "${MODULES_DIR}/ui.py" <<'PYUI'
try:
    from rich.console import Console
    from rich.table import Table
    console = Console()
    RICH_AVAILABLE = True
except Exception:
    console = None
    RICH_AVAILABLE = False

def banner():
    art = r"""
  ____       _____             _
 / ___| ___ | ____|_ __   ___ | |_
 \___ \/ _ \|  _| | '_ \ / _ \| __|
  ___) | (_) | |___| | | | (_) | |_
 |____/ \___/|_____|_| |_|\___/ \__|
    Hybrid Python + Shell CLI
   by Mauricio-100 (GoSpot)
"""
    if RICH_AVAILABLE:
        console.rule("[bold cyan]GoSpot[/]")
        console.print(art, style="bold green")
    else:
        print(art)

def info(msg):
    if RICH_AVAILABLE:
        console.print("[green][INFO][/green]", msg)
    else:
        print("[INFO]", msg)

def warn(msg):
    if RICH_AVAILABLE:
        console.print("[yellow][WARN][/yellow]", msg)
    else:
        print("[WARN]", msg)

def error(msg):
    if RICH_AVAILABLE:
        console.print("[red][ERROR][/red]", msg)
    else:
        print("[ERROR]", msg)
PYUI

# modules: network.py (robuste)
echo "[5/12] Écriture modules/network.py..."
cat > "${MODULES_DIR}/network.py" <<'PYNET'
import subprocess

def detect_local_prefix():
    try:
        out = subprocess.check_output(
            "ip -4 addr show | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}' | grep -v '^127\\.' | head -n1",
            shell=True, text=True
        ).strip()
        if out:
            return ".".join(out.split(".")[:3]) + ".0/24"
    except Exception:
        pass
    # fallback common ranges
    return "192.168.1.0/24"

def scan_network():
    """Return list of hosts (uses nmap -sn). Non-fatal on permission errors."""
    if subprocess.run(["which", "nmap"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
        return []
    prefix = detect_local_prefix()
    try:
        res = subprocess.check_output(["nmap", "-sn", prefix], text=True, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError as e:
        # some nmap operations require privileges; try non-root flags or return empty
        try:
            res = subprocess.check_output(["nmap", "-sn", prefix], text=True)
        except Exception:
            return []
    hosts = []
    for line in res.splitlines():
        if "Nmap scan report for" in line:
            ip = line.split()[-1]
            hosts.append(ip)
    return hosts
PYNET

# modules: ssh_utils.py
echo "[6/12] Écriture modules/ssh_utils.py..."
cat > "${MODULES_DIR}/ssh_utils.py" <<'PYSSH'
from pathlib import Path
import subprocess, os

def ensure_ssh_key():
    home = Path.home()
    ssh_dir = home / ".ssh"
    ssh_dir.mkdir(mode=0o700, exist_ok=True)
    key_path = ssh_dir / "id_rsa"
    if key_path.exists():
        return str(key_path)
    subprocess.run(['ssh-keygen', '-t', 'rsa', '-b', '4096', '-f', str(key_path), '-N', ''], check=False)
    return str(key_path)

def manage_ssh_keys():
    print("[SSH] ensure or generate SSH key")
    p = ensure_ssh_key()
    print(f"Key path: {p}")
PYSSH

# modules: sysinfo.py
echo "[7/12] Écriture modules/sysinfo.py..."
cat > "${MODULES_DIR}/sysinfo.py" <<'PYSI'
import platform, psutil, os

def basic_info():
    return {
        "platform": platform.platform(),
        "hostname": platform.node(),
        "cpu_count": psutil.cpu_count(logical=True) if hasattr(psutil, "cpu_count") else None,
        "memory_total": psutil.virtual_memory().total if hasattr(psutil, "virtual_memory") else None,
        "cwd": os.getcwd()
    }

def print_info():
    info = basic_info()
    for k,v in info.items():
        print(f"{k}: {v}")
PYSI

# CLI: gospot_pkg/cli.py (amélioré)
echo "[8/12] Écriture gospot_pkg/cli.py..."
cat > "${PKG_DIR}/cli.py" <<'PYCLI'
#!/usr/bin/env python3
# GoSpot CLI - gospot_pkg.cli
import os, sys, subprocess
from gospot_pkg.modules import system, network, ssh_utils, sysinfo, ui

def detect_os():
    prefix = os.getenv("PREFIX", "")
    try:
        uname_sys = os.uname().sysname.upper()
    except Exception:
        uname_sys = ""
    if "com.termux" in prefix:
        return "TERMUX"
    if "DARWIN" in uname_sys:
        return "MAC"
    if "LINUX" in uname_sys:
        return "LINUX"
    return "UNKNOWN"

def setup_env():
    os_type = detect_os()
    ui.info(f"OS detected: {os_type}")
    pkgs = ["nmap", "curl", "git", "openssh"]
    if os_type == "TERMUX":
        for p in pkgs:
            if not system.check_command(p):
                ui.info(f"Installing {p} via pkg...")
                os.system(f"pkg install -y {p}")
    elif os_type == "MAC":
        for p in pkgs:
            if not system.check_command(p):
                ui.info(f"Installing {p} via brew...")
                os.system(f"brew install {p} || true")
    elif os_type == "LINUX":
        for p in pkgs:
            if not system.check_command(p):
                ui.info(f"Installing {p} via apt/pacman...")
                os.system(f"sudo apt install -y {p} || sudo pacman -S --noconfirm {p} || true")
    else:
        ui.warn("Unknown OS: skipping auto-install")
    ui.info("Setup env done.")

def scan_network_ui():
    ui.info("Starting network scan (may require nmap)...")
    hosts = network.scan_network()
    if not hosts:
        ui.warn("No hosts found or nmap not available.")
        return
    print("\nHosts found:")
    for h in hosts:
        print(" -", h)

def show_sysinfo():
    ui.info("System info:")
    sysinfo.print_info()

def main_menu():
    while True:
        os.system("clear")
        ui.banner()
        print("""
[1] 🌐 Scan réseau local
[2] 🔐 Gérer clés SSH
[3] 🧰 Installer/Mettre à jour les outils SDK
[4] ⚙️ Vérifier le système et l'environnement
[5] 📈 Speedtest (si disponible)
[6] 🚪 Quitter
""")
        choice = input("Choisis une option ➤ ").strip()
        if choice == "1":
            scan_network_ui()
            input("\nPress Enter to continue...")
        elif choice == "2":
            ssh_utils.manage_ssh_keys()
            input("\nPress Enter to continue...")
        elif choice == "3":
            setup_env()
            input("\nPress Enter to continue...")
        elif choice == "4":
            show_sysinfo()
            input("\nPress Enter to continue...")
        elif choice == "5":
            try:
                subprocess.run(["speedtest-cli","--simple"])
            except Exception:
                ui.warn("speedtest-cli not available. Install 'speedtest-cli' via pip or package manager.")
            input("\nPress Enter to continue...")
        elif choice == "6":
            ui.info("Bye!")
            sys.exit(0)
        else:
            ui.warn("Invalid option")
            input("\nPress Enter to continue...")

if __name__ == "__main__":
    main_menu()
PYCLI

# sdk stubs
echo "[9/12] Création sdk stubs..."
for f in admin.sh detect_os.sh monitor.sh nettools.sh speedtest.sh ssh.sh sysinfo.sh tools.sh; do
  cat > "${SDK_DIR}/${f}" <<'SHF'
#!/usr/bin/env bash
echo "[SDK stub] $0"
SHF
  chmod +x "${SDK_DIR}/${f}"
done

# requirements.txt
echo "[10/12] Création requirements.txt..."
cat > "${REQUIREMENTS}" <<'REQ'
rich
psutil
requests
speedtest-cli
REQ

# permissions
echo "[11/12] Permissions..."
chmod +x "${PKG_DIR}/cli.py" || true
chmod +x "${SDK_DIR}"/* || true

# reinstall pip package
echo "[12/12] (Re)installation pip package..."
"${PYTHON}" -m pip uninstall -y gospot-cli || true
"${PYTHON}" -m pip uninstall -y gospot_cli || true

# create a minimal setup.py if missing
if [ ! -f "${ROOT}/setup.py" ]; then
  echo "[INFO] setup.py absent: creating minimal setup.py..."
  cat > "${ROOT}/setup.py" <<'SETUPPY'
from setuptools import setup, find_packages

setup(
    name="gospot-cli",
    version="1.0.0",
    packages=find_packages(),
    include_package_data=True,
    install_requires=[],
    entry_points={
        "console_scripts": [
            "gos=gospot_pkg.cli:main_menu",
        ],
    },
)
SETUPPY
fi

# install python deps (ask user)
echo
read -p "Installer les dépendances Python (requirements.txt) maintenant ? [Y/n]: " REPLY_INSTALL
REPLY_INSTALL="${REPLY_INSTALL:-Y}"
if [[ "$REPLY_INSTALL" =~ ^[Yy] ]]; then
  echo "[pip] Installing requirements..."
if [ -d "/data/data/com.termux/files/usr" ]; then
  echo "[INFO] Termux détecté : pas de mise à jour pip"
  "${PYTHON}" -m pip install -r "${REQUIREMENTS}" --no-cache-dir
else
  "${PYTHON}" -m pip install --upgrade pip
  "${PYTHON}" -m pip install -r "${REQUIREMENTS}"
fi

# install package
"${PYTHON}" -m pip install --no-cache-dir .

# create wrapper: try system path(s)
echo "[+] Création wrapper(s)..."
# Termux wrapper
if [ -d "/data/data/com.termux/files/usr/bin" ]; then
  mkdir -p "$(dirname "${WRAPPER_TERMUX}")"
  cat > "${WRAPPER_TERMUX}" <<'WRAPTERM'
#!/data/data/com.termux/files/usr/bin/env bash
exec /data/data/com.termux/files/usr/bin/env python3 -m gospot_pkg.cli "$@"
WRAPTERM
  chmod +x "${WRAPPER_TERMUX}"
  echo "Termux wrapper created: ${WRAPPER_TERMUX}"
fi

# Local user bin wrapper
mkdir -p "${HOME}/.local/bin"
cat > "${WRAPPER_LOCAL}" <<'WRAPLOC'
#!/usr/bin/env bash
exec python3 -m gospot_pkg.cli "$@"
WRAPLOC
chmod +x "${WRAPPER_LOCAL}"
echo "Local wrapper created: ${WRAPPER_LOCAL}"

echo
echo "=== REBUILD COMPLETE ==="
echo "Run 'gos' (if wrapper in PATH) or '${PYTHON} -m gospot_pkg.cli'"
echo "If 'gos' not found, add '${HOME}/.local/bin' to your PATH:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo
