#!/bin/bash
# ==============================================================================
#  tirolia-pc-prep — verify-and-fix.sh
#  GitHub: SaintPaddy/tirolia-pc-prep
#
#  Run this on a machine where setup.sh v1 was already executed.
#  It checks every setting and only applies what is missing or wrong.
#
#  USAGE:
#    bash verify-and-fix.sh        ← run as your normal user (NOT sudo)
# ==============================================================================
set -e

GITHUB_USER="SaintPaddy"
GITHUB_REPO="tirolia-pc-prep"
GITHUB_BRANCH="main"
REPO_RAW="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# ── Guard against running as root ─────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
  echo ""
  echo "  ✋  Do not run this script with sudo or as root!"
  echo "  Run it as your normal user: bash verify-and-fix.sh"
  echo ""
  exit 1
fi

# ==============================================================================
# RESOLVE REAL USER — cross-checked three ways so case/typos can't cause issues
# ==============================================================================

ENV_USER="$USER"
WHO_USER=$(who am i 2>/dev/null | awk '{print $1}' || echo "")

if [ -n "$WHO_USER" ] && [ -d "/home/$WHO_USER" ]; then
    REAL_USER="$WHO_USER"
elif [ -n "$ENV_USER" ] && [ -d "/home/$ENV_USER" ]; then
    REAL_USER="$ENV_USER"
else
    REAL_USER=$(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1}' | head -n1)
fi

REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

if [ -z "$REAL_USER" ] || [ ! -d "$REAL_HOME" ]; then
    echo ""
    echo "  ❌  Could not reliably detect the current user!"
    echo "      ENV_USER = $ENV_USER"
    echo "      WHO_USER = $WHO_USER"
    echo "  Please run the script while logged in as your normal desktop user."
    exit 1
fi

if [ -n "$WHO_USER" ] && [ "$WHO_USER" != "$ENV_USER" ]; then
    echo ""
    echo "  ⚠  WARNING: Username mismatch detected!"
    echo "      \$USER says  : $ENV_USER"
    echo "      'who am i'  : $WHO_USER"
    echo "      Using       : $REAL_USER  (from login record)"
    echo ""
fi

if command -v xdg-user-dir >/dev/null 2>&1; then
    REAL_DESKTOP=$(xdg-user-dir DESKTOP)
else
    REAL_DESKTOP=$(grep '^XDG_DESKTOP_DIR' "$REAL_HOME/.config/user-dirs.dirs" \
        | cut -d'"' -f2 | sed "s|\$HOME|$REAL_HOME|")
fi

if [ -z "$REAL_DESKTOP" ] || [ ! -d "$REAL_DESKTOP" ]; then
    for CANDIDATE in "$REAL_HOME/Desktop" "$REAL_HOME/Bureaublad" "$REAL_HOME/Bureau" "$REAL_HOME/Schreibtisch"; do
        if [ -d "$CANDIDATE" ]; then
            REAL_DESKTOP="$CANDIDATE"
            break
        fi
    done
fi

# ── Counters ──────────────────────────────────────────────────────────────────
ALREADY=0
FIXED=0
FAILED=0

ok()    { echo "  ✅  OK      : $1"; ALREADY=$((ALREADY+1)); }
fixed() { echo "  🔧  FIXED   : $1"; FIXED=$((FIXED+1)); }
fail()  { echo "  ❌  FAILED  : $1"; FAILED=$((FAILED+1)); }
header(){ echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; echo " $1"; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }

echo ""
echo "=============================================="
echo "   tirolia-pc-prep — Verify & Fix"
echo "   User    : $REAL_USER"
echo "   Desktop : $REAL_DESKTOP"
echo "=============================================="

# Pre-cache sudo so we don't get prompted mid-check
sudo -v

# ==============================================================================
# 1. WINE
# ==============================================================================
header "Checking Wine"
if command -v wine >/dev/null 2>&1; then
    ok "Wine is installed: $(wine --version)"
else
    echo "  ⚠  Wine not found — installing..."
    UBUNTU_CODENAME=$(grep "UBUNTU_CODENAME" /etc/os-release | cut -d'=' -f2)
    sudo apt install -y dirmngr ca-certificates software-properties-common curl wget
    sudo dpkg --add-architecture i386
    sudo mkdir -pm755 /etc/apt/keyrings
    wget -O - https://dl.winehq.org/wine-builds/winehq.key \
      | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key
    sudo wget -NP /etc/apt/sources.list.d/ \
      "https://dl.winehq.org/wine-builds/ubuntu/dists/${UBUNTU_CODENAME}/winehq-${UBUNTU_CODENAME}.sources"
    sudo apt update
    sudo apt install --install-recommends winehq-stable -y \
      && fixed "Wine installed: $(wine --version)" \
      || fail "Wine install failed"
fi

# ==============================================================================
# 2. TEAMS FOR LINUX
# ==============================================================================
header "Checking Teams for Linux"
if flatpak list 2>/dev/null | grep -q "IsmaelMartinez.teams_for_linux"; then
    ok "Teams for Linux is installed (Flatpak)"
else
    echo "  ⚠  Teams not found — installing..."
    sudo apt install -y flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.github.IsmaelMartinez.teams_for_linux \
      && fixed "Teams for Linux installed" \
      || fail "Teams install failed"
fi

# ==============================================================================
# 3. TEAMVIEWER
# ==============================================================================
header "Checking TeamViewer"
if command -v teamviewer >/dev/null 2>&1 || dpkg -l teamviewer &>/dev/null; then
    ok "TeamViewer is installed"
else
    echo "  ⚠  TeamViewer not found — installing..."
    wget -O /tmp/teamviewer.deb https://download.teamviewer.com/download/linux/teamviewer_amd64.deb
    sudo apt install -y /tmp/teamviewer.deb \
      && fixed "TeamViewer installed" \
      || fail "TeamViewer install failed"
    rm -f /tmp/teamviewer.deb
fi

# ==============================================================================
# 4. CINNAMON APPLET SETTINGS
# ==============================================================================
header "Checking Cinnamon applet settings"

# ── Mint Menu ─────────────────────────────────────────────────────────────────
MINTMENU_DIR="$REAL_HOME/.config/cinnamon/spices/menu@cinnamon.org"
MINTMENU_CONFIG=$(ls "$MINTMENU_DIR"/*.json 2>/dev/null | head -n1)

if [ -z "$MINTMENU_CONFIG" ]; then
    echo "  ⚠  Mint Menu config not found — will be applied on next login"
else
    python3 - <<EOF
import json, sys

path = "$MINTMENU_CONFIG"
with open(path) as f:
    data = json.load(f)

needs_fix = False
checks = {
    "menu-custom": True,
    "menu-icon":   "linuxmint-logo-filled-badge",
    "menu-label":  "   Start      ",
}

for key, expected in checks.items():
    actual = data.get(key, {}).get("value")
    if actual != expected:
        needs_fix = True
        data[key]["value"] = expected

if needs_fix:
    with open(path, "w") as f:
        json.dump(data, f, indent=4)
    print("  🔧  FIXED   : Mint Menu settings updated")
else:
    print("  ✅  OK      : Mint Menu settings are correct")
EOF
fi

# ── Grouped Window List ───────────────────────────────────────────────────────
GWL_DIR="$REAL_HOME/.config/cinnamon/spices/grouped-window-list@cinnamon.org"
GWL_CONFIG=$(ls "$GWL_DIR"/*.json 2>/dev/null | head -n1)

if [ -z "$GWL_CONFIG" ]; then
    echo "  ⚠  Grouped Window List config not found — will be applied on next login"
else
    python3 - <<EOF
import json, sys

path = "$GWL_CONFIG"
with open(path) as f:
    data = json.load(f)

needs_fix = False
checks = {
    "group-apps":    False,
    "title-display": 2,
}

for key, expected in checks.items():
    actual = data.get(key, {}).get("value")
    if actual != expected:
        needs_fix = True
        data[key]["value"] = expected

if needs_fix:
    with open(path, "w") as f:
        json.dump(data, f, indent=4)
    print("  🔧  FIXED   : Grouped Window List settings updated")
else:
    print("  ✅  OK      : Grouped Window List settings are correct")
EOF
fi

# ==============================================================================
# 5. USB DRIVE LETTER TOOL
# ==============================================================================
header "Checking USB drive-letter tool"
if [ -x /usr/local/bin/usb-register ]; then
    ok "usb-register is installed"
else
    echo "  ⚠  usb-register not found — installing..."
    curl -fsSL "$REPO_RAW/scripts/usb-register.sh" \
      | sudo tee /usr/local/bin/usb-register > /dev/null
    sudo chmod +x /usr/local/bin/usb-register \
      && fixed "usb-register installed" \
      || fail "usb-register install failed"
fi

# ── Desktop launcher ──────────────────────────────────────────────────────────
LAUNCHER_NL="$REAL_DESKTOP/USB-Registreren.desktop"
LAUNCHER_EN="$REAL_DESKTOP/Register-USB.desktop"
if [ -f "$LAUNCHER_NL" ] || [ -f "$LAUNCHER_EN" ]; then
    ok "USB desktop launcher exists"
else
    echo "  ⚠  USB desktop launcher missing — installing..."
    curl -fsSL "$REPO_RAW/scripts/install-usb-launcher.sh" -o /tmp/install-usb-launcher.sh
    chmod +x /tmp/install-usb-launcher.sh
    bash /tmp/install-usb-launcher.sh \
      && fixed "USB desktop launcher created" \
      || fail "USB launcher install failed"
    rm -f /tmp/install-usb-launcher.sh
fi

# ==============================================================================
# 6. INSTALL-TEMP ON DESKTOP
# ==============================================================================
header "Checking install-temp folder"
DEST="$REAL_DESKTOP/install-temp"
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" \
  "https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/install-temp?ref=${GITHUB_BRANCH}")

if [ "$HTTP_STATUS" != "200" ]; then
    ok "No install-temp folder in repo yet — nothing to download"
else
    echo "  install-temp destination: $DEST"
    read -r -p "  Sync install-temp from GitHub now? [y/N] " SYNC_INSTALL_TEMP || SYNC_INSTALL_TEMP="N"

    if [[ "$SYNC_INSTALL_TEMP" =~ ^[Yy]$ ]]; then
        echo "  Syncing install-temp from GitHub..."
        mkdir -p "$DEST"
        curl -fsSL "https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/install-temp?ref=${GITHUB_BRANCH}" \
          | python3 -c "
import sys, json, os, urllib.request
items = json.load(sys.stdin)
def dl(url, dest):
    print(f'     -> {os.path.basename(dest)}')
    urllib.request.urlretrieve(url, dest)
def process(items, lp):
    for item in items:
        dest = os.path.join(lp, item['name'])
        if item['type'] == 'file': dl(item['download_url'], dest)
        elif item['type'] == 'dir':
            os.makedirs(dest, exist_ok=True)
            with urllib.request.urlopen(item['url']) as r:
                process(json.load(r), dest)
process(items, '$DEST')
" && fixed "install-temp synced to $DEST" || fail "install-temp sync failed"
    elif [ -d "$DEST" ] && [ "$(ls -A "$DEST" 2>/dev/null)" ]; then
        ok "install-temp sync skipped; existing folder kept at $DEST"
    else
        echo "  - SKIPPED : install-temp sync skipped by user"
    fi
fi

# ==============================================================================
# 7. VIRTUAL DESKTOPS = 1
# ==============================================================================
header "Checking virtual desktops"
NUM=$(gsettings get org.cinnamon.desktop.wm.preferences num-workspaces 2>/dev/null || echo "?")
if [ "$NUM" = "1" ]; then
    ok "Virtual desktops = 1"
else
    gsettings set org.cinnamon.desktop.wm.preferences num-workspaces 1
    gsettings set org.cinnamon number-workspaces 1 2>/dev/null || true
    fixed "Virtual desktops set to 1 (was: $NUM)"
fi

# ==============================================================================
# 8. NEMO CONTEXT MENU SETTINGS
# ==============================================================================
header "Checking Nemo context menu settings"

if gsettings list-schemas | grep -qx "org.nemo.preferences.menu-config"; then
    NEMO_MENU_SCHEMA="org.nemo.preferences.menu-config"
    NEMO_CHANGED=0

    check_nemo_menu_setting() {
        local KEY="$1"
        local EXPECTED="$2"
        local LABEL="$3"
        local ACTUAL

        ACTUAL=$(gsettings get "$NEMO_MENU_SCHEMA" "$KEY" 2>/dev/null || echo "?")

        if [ "$ACTUAL" = "$EXPECTED" ]; then
            ok "$LABEL = $EXPECTED"
        else
            gsettings set "$NEMO_MENU_SCHEMA" "$KEY" "$EXPECTED" \
              && fixed "$LABEL set to $EXPECTED (was: $ACTUAL)" \
              || fail "Could not set $LABEL"
            NEMO_CHANGED=1
        fi
    }

    check_nemo_menu_setting selection-menu-open true "Open"
    check_nemo_menu_setting selection-menu-open-in-new-tab true "Open in new tab"
    check_nemo_menu_setting selection-menu-open-in-new-window true "Open in new window"
    check_nemo_menu_setting selection-menu-scripts false "Scripts"
    check_nemo_menu_setting selection-menu-cut true "Cut"
    check_nemo_menu_setting selection-menu-copy true "Copy"
    check_nemo_menu_setting selection-menu-paste true "Paste"
    check_nemo_menu_setting selection-menu-duplicate false "Duplicate"
    check_nemo_menu_setting selection-menu-pin false "Pin"
    check_nemo_menu_setting selection-menu-favorite false "Favorite"
    check_nemo_menu_setting selection-menu-make-link false "Create link"
    check_nemo_menu_setting selection-menu-rename true "Rename"
    check_nemo_menu_setting selection-menu-copy-to true "Copy to"
    check_nemo_menu_setting selection-menu-move-to true "Move to"
    check_nemo_menu_setting selection-menu-open-in-terminal false "Open in terminal"
    check_nemo_menu_setting selection-menu-open-as-root true "Open as administrator"
    check_nemo_menu_setting selection-menu-move-to-trash true "Move to trash"
    check_nemo_menu_setting selection-menu-properties true "Properties"

    if [ "$NEMO_CHANGED" -eq 1 ]; then
        nemo -q >/dev/null 2>&1 || true
    fi
else
    echo "  –  N/A      : Nemo context menu schema not found"
fi

# ==============================================================================
# 9. AUTOLOGIN
# ==============================================================================
header "Checking autologin"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
AUTOLOGIN_USER=$(grep -E "^autologin-user[[:space:]]*=" "$LIGHTDM_CONF" 2>/dev/null | tail -n1 | cut -d= -f2- | xargs || true)
AUTOLOGIN_TIMEOUT=$(grep -E "^autologin-user-timeout[[:space:]]*=" "$LIGHTDM_CONF" 2>/dev/null | tail -n1 | cut -d= -f2- | xargs || true)

if [ "$AUTOLOGIN_USER" = "$REAL_USER" ] && [ "$AUTOLOGIN_TIMEOUT" = "0" ]; then
    ok "Autologin is enabled for $REAL_USER with no delay"
else
    echo "  ⚠  Autologin not set — configuring..."
    sudo cp "$LIGHTDM_CONF" "${LIGHTDM_CONF}.bak"
    sudo python3 - <<EOF
import re
path = "$LIGHTDM_CONF"
with open(path) as f:
    content = f.read()
if re.search(r'^#?autologin-user\s*=', content, re.MULTILINE):
    content = re.sub(r'^#?autologin-user\s*=.*$', 'autologin-user=$REAL_USER', content, flags=re.MULTILINE)
else:
    content = content.replace('[Seat:*]', '[Seat:*]\nautologin-user=$REAL_USER')
if re.search(r'^#?autologin-user-timeout\s*=', content, re.MULTILINE):
    content = re.sub(r'^#?autologin-user-timeout\s*=.*$', 'autologin-user-timeout=0', content, flags=re.MULTILINE)
else:
    content = content.replace('autologin-user=$REAL_USER', 'autologin-user=$REAL_USER\nautologin-user-timeout=0')
with open(path, "w") as f:
    f.write(content)
EOF
    fixed "Autologin enabled for $REAL_USER"
fi

# ==============================================================================
# 10. SERVICES
# ==============================================================================
header "Checking services"

check_service_disabled() {
    local SVC="$1"
    local REASON="$2"
    if ! systemctl list-unit-files "$SVC" 2>/dev/null | grep -q "$SVC"; then
        echo "  –  N/A      : $SVC (not installed)"
        return
    fi
    STATE=$(systemctl is-enabled "$SVC" 2>/dev/null || echo "unknown")
    if [ "$STATE" = "disabled" ] || [ "$STATE" = "masked" ]; then
        ok "$SVC is disabled"
    else
        sudo systemctl stop "$SVC" 2>/dev/null || true
        sudo systemctl disable "$SVC" 2>/dev/null \
          && fixed "Disabled $SVC  ($REASON)" \
          || fail "Could not disable $SVC"
    fi
}

check_service_disabled avahi-daemon.service   "mDNS/zeroconf, not needed"
check_service_disabled ModemManager.service   "mobile broadband, no modem"
check_service_disabled cups-browsed.service   "network printer discovery"
check_service_disabled whoopsie.service       "crash telemetry to Canonical"
check_service_disabled apport.service         "crash report generator"
check_service_disabled kerneloops.service     "kernel oops telemetry"

# ==============================================================================
# 11. SCREENSAVER LOCK
# ==============================================================================
header "Checking screensaver lock"
LOCK=$(gsettings get org.cinnamon.desktop.screensaver lock-enabled 2>/dev/null || echo "?")
IDLE_DIM=$(gsettings get org.cinnamon.settings-daemon.plugins.power idle-dim-time 2>/dev/null || echo "?")
LOCK_ON_SUSPEND=$(gsettings get org.cinnamon.settings-daemon.plugins.power lock-on-suspend 2>/dev/null || echo "?")

if [ "$LOCK" = "false" ] && [ "$IDLE_DIM" = "0" ] && [ "$LOCK_ON_SUSPEND" = "false" ]; then
    ok "Screensaver lock settings match setup.sh"
else
    gsettings set org.cinnamon.desktop.screensaver lock-enabled false
    gsettings set org.cinnamon.settings-daemon.plugins.power idle-dim-time 0 2>/dev/null || true
    gsettings set org.cinnamon.settings-daemon.plugins.power lock-on-suspend false 2>/dev/null || true
    fixed "Screensaver lock settings matched to setup.sh"
fi

# ==============================================================================
# 12. NUMLOCK
# ==============================================================================
header "Checking NumLock"

# Check numlockx is installed
if ! command -v numlockx >/dev/null 2>&1; then
    sudo apt install -y numlockx \
      && fixed "numlockx installed" \
      || fail "numlockx install failed"
else
    ok "numlockx is installed"
fi

# Check LightDM config has the greeter-setup-script line
if grep -q "greeter-setup-script=/usr/bin/numlockx on" "$LIGHTDM_CONF" 2>/dev/null; then
    ok "LightDM NumLock is configured"
else
    sudo python3 - <<EOF
import re
path = "$LIGHTDM_CONF"
with open(path) as f:
    content = f.read()
if "greeter-setup-script" not in content:
    content = re.sub(r'(\[Seat:\*\])', r'\1\ngreeter-setup-script=/usr/bin/numlockx on', content)
else:
    content = re.sub(r'^#?greeter-setup-script\s*=.*$',
                     'greeter-setup-script=/usr/bin/numlockx on',
                     content, flags=re.MULTILINE)
with open(path, "w") as f:
    f.write(content)
EOF
    fixed "LightDM NumLock configured"
fi

# Check Cinnamon gsettings
NUMLOCK=$(gsettings get org.cinnamon.settings-daemon.peripherals.keyboard numlock-state 2>/dev/null || echo "?")
if [ "$NUMLOCK" = "'on'" ]; then
    ok "Cinnamon NumLock setting is 'on'"
else
    gsettings set org.cinnamon.settings-daemon.peripherals.keyboard numlock-state "on" \
      && fixed "Cinnamon NumLock set to on" \
      || fail "Could not set Cinnamon NumLock"
fi

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
echo "=============================================="
echo "   Verify & Fix complete"
echo ""
echo "   ✅  Already correct : $ALREADY"
echo "   🔧  Fixed           : $FIXED"
echo "   ❌  Failed          : $FAILED"
echo "=============================================="
if [ "$FIXED" -gt 0 ]; then
    echo ""
    echo "  ⚠  Changes were made — please REBOOT for"
    echo "     everything to take full effect."
fi
echo ""
