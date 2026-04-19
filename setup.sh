#!/bin/bash
# ==============================================================================
#  tirolia-pc-prep — setup.sh
#  GitHub: SaintPaddy/tirolia-pc-prep
#
#  USAGE:
#    bash setup.sh          ← correct: run as your normal user
#    sudo bash setup.sh     ← WRONG: breaks home/desktop path detection
#
#  What this does:
#    1. Installs Wine (stable, from WineHQ)
#    2. Installs Teams for Linux (IsmaelMartinez community build via Flatpak)
#    3. Installs TeamViewer
#    4. Applies Cinnamon applet settings (Start button, ungrouped taskbar)
#    5. Installs the USB drive-letter registration tool (usb-register)
#    6. Downloads install-temp/ folder from this repo to the desktop
#    7. Sets number of Cinnamon virtual desktops to 1
#    8. Enables autologin for the current user
#    9. Disables unnecessary default services
# ==============================================================================
set -e

GITHUB_USER="SaintPaddy"
GITHUB_REPO="tirolia-pc-prep"
GITHUB_BRANCH="main"
REPO_RAW="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# ==============================================================================
# GUARD: must NOT be run as root directly
# ==============================================================================
if [ "$EUID" -eq 0 ]; then
  echo ""
  echo "  ✋  Do not run this script with sudo or as root!"
  echo ""
  echo "  Run it as your normal user:"
  echo "    bash setup.sh"
  echo ""
  echo "  The script will ask for your sudo password when it needs it."
  exit 1
fi

# Capture the real user and their home/desktop now, before any sudo calls
REAL_USER="$USER"
REAL_HOME="$HOME"

# Find the desktop folder the right way (handles Dutch "Bureaublad" etc.)
if command -v xdg-user-dir >/dev/null 2>&1; then
    REAL_DESKTOP=$(xdg-user-dir DESKTOP)
else
    REAL_DESKTOP=$(grep '^XDG_DESKTOP_DIR' "$HOME/.config/user-dirs.dirs" \
        | cut -d'"' -f2 | sed "s|\$HOME|$HOME|")
fi

echo ""
echo "=============================================="
echo "   tirolia-pc-prep — Linux Mint Setup"
echo "=============================================="
echo ""
echo "  Running as  : $REAL_USER"
echo "  Home folder : $REAL_HOME"
echo "  Desktop     : $REAL_DESKTOP"
echo ""

# ── DETECT UBUNTU BASE ────────────────────────────────────────────────────────
UBUNTU_CODENAME=$(grep "UBUNTU_CODENAME" /etc/os-release | cut -d'=' -f2)
if [ -z "$UBUNTU_CODENAME" ]; then
  echo "ERROR: Could not detect Ubuntu base codename. Are you on Linux Mint?"
  exit 1
fi
echo "==> Detected Ubuntu base: $UBUNTU_CODENAME"

# Pre-cache sudo credentials so we don't get prompted mid-script
echo ""
echo "==> You may be asked for your password once for sudo access..."
sudo -v

# ── UPDATE SYSTEM ─────────────────────────────────────────────────────────────
echo ""
echo "==> Updating system packages..."
sudo apt update && sudo apt upgrade -y

# ── PREREQUISITES ─────────────────────────────────────────────────────────────
echo ""
echo "==> Installing prerequisites..."
sudo apt install -y \
  dirmngr ca-certificates software-properties-common \
  curl wget apt-transport-https flatpak python3

# ==============================================================================
# 1. WINE
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [1/6] Installing Wine (stable)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings

wget -O - https://dl.winehq.org/wine-builds/winehq.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key

sudo wget -NP /etc/apt/sources.list.d/ \
  "https://dl.winehq.org/wine-builds/ubuntu/dists/${UBUNTU_CODENAME}/winehq-${UBUNTU_CODENAME}.sources"

sudo apt update
sudo apt install --install-recommends winehq-stable -y

echo "==> Wine installed: $(wine --version)"

# ==============================================================================
# 2. TEAMS FOR LINUX (IsmaelMartinez — community Flatpak build)
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [2/6] Installing Teams for Linux (Flatpak)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Flatpak remote-add needs sudo; install runs as the real user
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.github.IsmaelMartinez.teams_for_linux

echo "==> Teams for Linux installed."

# ==============================================================================
# 3. TEAMVIEWER
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [3/6] Installing TeamViewer..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

wget -O /tmp/teamviewer.deb https://download.teamviewer.com/download/linux/teamviewer_amd64.deb
sudo apt install -y /tmp/teamviewer.deb
rm /tmp/teamviewer.deb

echo "==> TeamViewer installed."

# ==============================================================================
# 4. CINNAMON APPLET SETTINGS
#    Runs entirely as the real user — no sudo needed
#    Changes from exported JSON:
#      - Menu icon     : linuxmint-logo-filled-badge
#      - Menu label    : "   Start      "
#      - group-apps    : false  (ungrouped taskbar)
#      - title-display : 2      (show app name on buttons)
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [4/6] Applying Cinnamon applet settings..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Mint Menu ─────────────────────────────────────────────────────────────────
MINTMENU_DIR="$REAL_HOME/.config/cinnamon/spices/menu@cinnamon.org"
mkdir -p "$MINTMENU_DIR"
MINTMENU_CONFIG=$(ls "$MINTMENU_DIR"/*.json 2>/dev/null | head -n1)
if [ -z "$MINTMENU_CONFIG" ]; then
  MINTMENU_CONFIG="$MINTMENU_DIR/0.json"
  echo "{}" > "$MINTMENU_CONFIG"
fi

echo "==> Patching Mint Menu: $MINTMENU_CONFIG"
python3 - <<EOF
import json
path = "$MINTMENU_CONFIG"
with open(path) as f:
    data = json.load(f)
for key, val in [("menu-custom", True), ("menu-icon", "linuxmint-logo-filled-badge"), ("menu-label", "   Start      ")]:
    if key in data:
        data[key]["value"] = val
with open(path, "w") as f:
    json.dump(data, f, indent=4)
print("   Mint Menu settings applied.")
EOF

# ── Grouped Window List ───────────────────────────────────────────────────────
GWL_DIR="$REAL_HOME/.config/cinnamon/spices/grouped-window-list@cinnamon.org"
mkdir -p "$GWL_DIR"
GWL_CONFIG=$(ls "$GWL_DIR"/*.json 2>/dev/null | head -n1)
if [ -z "$GWL_CONFIG" ]; then
  GWL_CONFIG="$GWL_DIR/0.json"
  echo "{}" > "$GWL_CONFIG"
fi

echo "==> Patching Grouped Window List: $GWL_CONFIG"
python3 - <<EOF
import json
path = "$GWL_CONFIG"
with open(path) as f:
    data = json.load(f)
for key, val in [("group-apps", False), ("title-display", 2)]:
    if key in data:
        data[key]["value"] = val
with open(path, "w") as f:
    json.dump(data, f, indent=4)
print("   Grouped Window List settings applied.")
EOF

# ── Reload Cinnamon (as the real user) ───────────────────────────────────────
if [ -n "${DISPLAY:-}" ]; then
  echo "==> Reloading Cinnamon..."
  cinnamon --replace &>/dev/null &
  sleep 2
  echo "==> Cinnamon reloaded."
else
  echo "==> (No display detected — log out and back in to apply Cinnamon changes.)"
fi

# ==============================================================================
# 5. USB DRIVE LETTER REGISTRATION TOOL
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [5/6] Installing USB drive-letter tool..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Copy to system bin (needs sudo), then install desktop launcher as real user
curl -fsSL "$REPO_RAW/scripts/usb-register.sh" \
  | sudo tee /usr/local/bin/usb-register > /dev/null
sudo chmod +x /usr/local/bin/usb-register

curl -fsSL "$REPO_RAW/scripts/install-usb-launcher.sh" -o /tmp/install-usb-launcher.sh
chmod +x /tmp/install-usb-launcher.sh
bash /tmp/install-usb-launcher.sh   # runs as real user — desktop path resolves correctly
rm /tmp/install-usb-launcher.sh

echo "==> USB tool installed."

# ==============================================================================
# 6. DOWNLOAD install-temp/ FROM REPO TO DESKTOP
#    Reads the repo contents dynamically via GitHub API —
#    just add/remove files in the install-temp/ folder on GitHub
#    and they will automatically appear here on the next run.
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [6/6] Downloading install-temp files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DEST="$REAL_DESKTOP/install-temp"
mkdir -p "$DEST"
echo "==> Destination: $DEST"

# ── Recursive downloader using GitHub Contents API ───────────────────────────
github_download_folder() {
    local REPO_PATH="$1"
    local LOCAL_PATH="$2"

    local API_URL="https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/${REPO_PATH}?ref=${GITHUB_BRANCH}"

    curl -fsSL "$API_URL" | python3 -c "
import sys, json, os, urllib.request

items = json.load(sys.stdin)

if not isinstance(items, list):
    print('ERROR: Unexpected API response — folder may not exist in the repo.', file=sys.stderr)
    sys.exit(1)

local_base = '$LOCAL_PATH'
os.makedirs(local_base, exist_ok=True)

def download(url, dest):
    print(f'  -> {os.path.basename(dest)}')
    urllib.request.urlretrieve(url, dest)

def process(items, local_path):
    for item in items:
        name    = item['name']
        typ     = item['type']
        dl_url  = item.get('download_url')
        subpath = item['path']
        dest    = os.path.join(local_path, name)

        if typ == 'file':
            download(dl_url, dest)
        elif typ == 'dir':
            os.makedirs(dest, exist_ok=True)
            import urllib.request as ur
            sub_url = f'https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/{subpath}?ref=${GITHUB_BRANCH}'
            with ur.urlopen(sub_url) as r:
                sub_items = json.load(r)
            process(sub_items, dest)

process(items, local_base)
print('Done.')
"
}

echo "==> Fetching file list from GitHub..."
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" \
  "https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/install-temp?ref=${GITHUB_BRANCH}")

if [ "$HTTP_STATUS" = "200" ]; then
    github_download_folder "install-temp" "$DEST"
    echo "==> Files downloaded to: $DEST"
else
    echo "==> WARNING: No 'install-temp' folder found in the repo (HTTP $HTTP_STATUS)."
    echo "    Create a folder called 'install-temp' in your GitHub repo and add files to it."
fi

# ==============================================================================
# 7. SET CINNAMON VIRTUAL DESKTOPS TO 1
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [7/9] Setting virtual desktops to 1..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cinnamon stores workspace count in dconf
# We set num-workspaces to 1 and also disable the workspace switcher OSD
gsettings set org.cinnamon.desktop.wm.preferences num-workspaces 1
gsettings set org.cinnamon number-workspaces 1

echo "==> Virtual desktops set to 1."

# ==============================================================================
# 8. ENABLE AUTOLOGIN FOR CURRENT USER
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [8/9] Enabling autologin for $REAL_USER..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Linux Mint uses LightDM as display manager
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

# Backup the original config
sudo cp "$LIGHTDM_CONF" "${LIGHTDM_CONF}.bak"

# Use Python to safely patch only the autologin lines under [Seat:*]
sudo python3 - <<EOF
import re

path = "$LIGHTDM_CONF"
with open(path, "r") as f:
    content = f.read()

# If autologin-user line exists, update it; otherwise add it under [Seat:*]
if re.search(r'^#?autologin-user\s*=', content, re.MULTILINE):
    content = re.sub(r'^#?autologin-user\s*=.*$',
                     'autologin-user=$REAL_USER',
                     content, flags=re.MULTILINE)
else:
    content = content.replace('[Seat:*]',
                               '[Seat:*]\nautologin-user=$REAL_USER')

# Also set autologin-user-timeout to 0 (no delay)
if re.search(r'^#?autologin-user-timeout\s*=', content, re.MULTILINE):
    content = re.sub(r'^#?autologin-user-timeout\s*=.*$',
                     'autologin-user-timeout=0',
                     content, flags=re.MULTILINE)
else:
    content = content.replace('autologin-user=$REAL_USER',
                               'autologin-user=$REAL_USER\nautologin-user-timeout=0')

with open(path, "w") as f:
    f.write(content)

print("   LightDM autologin configured.")
EOF

echo "==> Autologin enabled for: $REAL_USER"
echo "    (Original config backed up to ${LIGHTDM_CONF}.bak)"

# ==============================================================================
# 9. DISABLE UNNECESSARY DEFAULT SERVICES
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [9/9] Disabling unnecessary services..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

disable_service_if_exists() {
    local SVC="$1"
    local REASON="$2"
    if systemctl list-unit-files "$SVC" 2>/dev/null | grep -q "$SVC"; then
        sudo systemctl stop "$SVC" 2>/dev/null || true
        sudo systemctl disable "$SVC" 2>/dev/null || true
        echo "  ✓ Disabled: $SVC  ($REASON)"
    else
        echo "  – Skipped:  $SVC  (not installed)"
    fi
}

# ── Safe to disable for a desktop PC used by non-technical users ──────────────

# Avahi: mDNS/zeroconf — useful for multi-device networks but unnecessary here
disable_service_if_exists avahi-daemon.service        "mDNS/zeroconf, not needed on single PC"

# ModemManager: manages mobile broadband (3G/4G) modems — no modem on this PC
disable_service_if_exists ModemManager.service        "mobile broadband manager, no modem present"

# cups-browsed: auto-discovers network printers — only needed if using network printers
disable_service_if_exists cups-browsed.service        "network printer discovery, not needed"

# whoopsie: Ubuntu crash reporter — sends crash data to Canonical
disable_service_if_exists whoopsie.service            "crash reporter / telemetry to Canonical"

# apport: Ubuntu crash handler — generates crash reports
disable_service_if_exists apport.service              "crash report generator"

# kerneloops: sends kernel oops reports online
disable_service_if_exists kerneloops.service          "kernel oops reporter / telemetry"

# wpa_supplicant: WiFi manager — disable only if using wired ethernet only
# (commented out — kept enabled in case WiFi is used)
# disable_service_if_exists wpa_supplicant.service    "WiFi - only disable if wired-only"

# bluetooth: disable if no bluetooth devices are used
# (commented out — uncomment if you don't use bluetooth)
# disable_service_if_exists bluetooth.service         "Bluetooth - uncomment to disable"

echo ""
echo "==> Services cleanup done."

# ==============================================================================
# 10. DISABLE SCREENSAVER LOCK (no password on wake)
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [10/11] Disabling screensaver lock..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Disable the lock screen entirely — no password needed after screensaver/idle
gsettings set org.cinnamon.desktop.screensaver lock-enabled false

# Also disable the screensaver itself (optional — comment out to keep screensaver
# but just remove the password requirement)
#gsettings set org.cinnamon.desktop.screensaver idle-activation-enabled false

# Prevent screen from locking when lid is closed or after idle (power settings)
gsettings set org.cinnamon.settings-daemon.plugins.power idle-dim-time 0
gsettings set org.cinnamon.settings-daemon.plugins.power lock-on-suspend false

echo "==> Screensaver lock disabled — no password needed on wake."

# ==============================================================================
# 11. ENABLE NUMLOCK ON BOOT
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [11/11] Enabling NumLock on boot..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Tell LightDM to enable NumLock before login
sudo apt install -y numlockx

LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

# Add numlockx call to lightdm greeter setup script if not already there
if ! grep -q "numlockx" "$LIGHTDM_CONF"; then
    sudo python3 - <<EOF
import re

path = "$LIGHTDM_CONF"
with open(path, "r") as f:
    content = f.read()

# Add greeter-setup-script under [Seat:*] if not already present
if "greeter-setup-script" not in content:
    content = content.replace(
        "autologin-user=$REAL_USER",
        "autologin-user=$REAL_USER\ngreeter-setup-script=/usr/bin/numlockx on"
    )
else:
    content = re.sub(
        r'^#?greeter-setup-script\s*=.*$',
        'greeter-setup-script=/usr/bin/numlockx on',
        content, flags=re.MULTILINE
    )

with open(path, "w") as f:
    f.write(content)

print("   LightDM NumLock configured.")
EOF
fi

# 2. Also set it in Cinnamon so NumLock stays on after login
gsettings set org.cinnamon.settings-daemon.peripherals.keyboard numlock-state "on"

echo "==> NumLock will be on from boot."

# ==============================================================================
echo ""
echo "=============================================="
echo "   ✅  Setup complete!"
echo ""
echo "   User          : $REAL_USER"
echo "   Wine          : $(wine --version)"
echo "   Teams         : Installed (Flatpak)"
echo "   TeamViewer    : Installed"
echo "   Cinnamon      : Settings + 1 desktop applied"
echo "   Autologin     : Enabled for $REAL_USER"
echo "   Lock screen   : Disabled (no password on wake)"
echo "   NumLock       : Enabled on boot"
echo "   USB tool      : /usr/local/bin/usb-register"
echo "   install-temp  : $DEST"
echo "   Services      : Unnecessary ones disabled"
echo "=============================================="
echo ""
echo "  ⚠  Please REBOOT for all changes to take"
echo "     full effect."
echo ""
