#!/bin/bash
# ==============================================================================
#  tirolia-pc-prep — setup.sh
#  GitHub: SaintPaddy/tirolia-pc-prep
#
#  What this does:
#    1. Installs Wine (stable, from WineHQ)
#    2. Installs Teams for Linux (IsmaelMartinez community build via Flatpak)
#    3. Installs TeamViewer
#    4. Applies Cinnamon applet settings (Start button, ungrouped taskbar)
#    5. Installs the USB drive-letter registration tool (usb-register)
#    6. Downloads install-temp/ folder from this repo to the desktop
# ==============================================================================
set -e

GITHUB_USER="SaintPaddy"
GITHUB_REPO="tirolia-pc-prep"
GITHUB_BRANCH="main"
REPO_RAW="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

echo ""
echo "=============================================="
echo "   tirolia-pc-prep — Linux Mint Setup"
echo "=============================================="
echo ""

# ── DETECT UBUNTU BASE ────────────────────────────────────────────────────────
UBUNTU_CODENAME=$(grep "UBUNTU_CODENAME" /etc/os-release | cut -d'=' -f2)
if [ -z "$UBUNTU_CODENAME" ]; then
  echo "ERROR: Could not detect Ubuntu base codename. Are you on Linux Mint?"
  exit 1
fi
echo "==> Detected Ubuntu base: $UBUNTU_CODENAME"

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

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
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
MINTMENU_DIR="$HOME/.config/cinnamon/spices/menu@cinnamon.org"
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
GWL_DIR="$HOME/.config/cinnamon/spices/grouped-window-list@cinnamon.org"
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

# ── Reload Cinnamon ───────────────────────────────────────────────────────────
if [ -n "${DISPLAY:-}" ]; then
  echo "==> Reloading Cinnamon..."
  cinnamon --replace &>/dev/null &
else
  echo "==> (No display — log out and back in to apply Cinnamon changes.)"
fi

# ==============================================================================
# 5. USB DRIVE LETTER REGISTRATION TOOL
# ==============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [5/6] Installing USB drive-letter tool..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

curl -fsSL "$REPO_RAW/scripts/usb-register.sh" \
  | sudo tee /usr/local/bin/usb-register > /dev/null
sudo chmod +x /usr/local/bin/usb-register

curl -fsSL "$REPO_RAW/scripts/install-usb-launcher.sh" -o /tmp/install-usb-launcher.sh
chmod +x /tmp/install-usb-launcher.sh
bash /tmp/install-usb-launcher.sh
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

# ── Find the desktop folder (handles Dutch "Bureaublad" etc.) ─────────────────
if command -v xdg-user-dir >/dev/null 2>&1; then
    DESKTOP_DIR=$(xdg-user-dir DESKTOP)
else
    DESKTOP_DIR=$(grep '^XDG_DESKTOP_DIR' "$HOME/.config/user-dirs.dirs" \
        | cut -d'"' -f2 | sed "s|\$HOME|$HOME|")
fi

DEST="$DESKTOP_DIR/install-temp"
mkdir -p "$DEST"
echo "==> Destination: $DEST"

# ── Recursive downloader using GitHub Contents API ───────────────────────────
github_download_folder() {
    local REPO_PATH="$1"   # path inside the repo, e.g. "install-temp"
    local LOCAL_PATH="$2"  # local destination folder

    local API_URL="https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/${REPO_PATH}?ref=${GITHUB_BRANCH}"

    # Fetch the directory listing and process it with Python
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
            # Recurse into subdirectory via API
            import urllib.request as ur
            sub_url = f'https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/{subpath}?ref=${GITHUB_BRANCH}'
            with ur.urlopen(sub_url) as r:
                sub_items = json.load(r)
            process(sub_items, dest)

process(items, local_base)
print('Done.')
"
}

# ── Check the install-temp folder exists in the repo ─────────────────────────
echo "==> Fetching file list from GitHub..."
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" \
  "https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/install-temp?ref=${GITHUB_BRANCH}")

if [ "$HTTP_STATUS" = "200" ]; then
    github_download_folder "install-temp" "$DEST"
    echo "==> Files downloaded to: $DEST"
else
    echo "==> WARNING: No 'install-temp' folder found in the repo (HTTP $HTTP_STATUS)."
    echo "    Create a folder called 'install-temp' in your GitHub repo and add files to it."
    echo "    They will be downloaded here on the next run."
fi

# ==============================================================================
echo ""
echo "=============================================="
echo "   ✅  Setup complete!"
echo ""
echo "   Wine        : $(wine --version)"
echo "   Teams       : Installed (Flatpak)"
echo "   TeamViewer  : Installed"
echo "   Cinnamon    : Settings applied"
echo "   USB tool    : /usr/local/bin/usb-register"
echo "   install-temp: $DEST"
echo "=============================================="
echo ""
echo "  ⚠  Log out and back in if Cinnamon didn't"
echo "     reload automatically."
echo ""
