#!/bin/bash
# ==============================================================================
#  install-usb-launcher.sh
#  Creates a desktop icon that launches usb-register with one click.
#  Auto-detects the system language for Dutch / English label.
# ==============================================================================

# ── Find the desktop folder (handles Dutch "Bureaublad", etc.) ───────────────
if command -v xdg-user-dir >/dev/null 2>&1; then
    DESKTOP_DIR=$(xdg-user-dir DESKTOP)
else
    # Fallback: parse ~/.config/user-dirs.dirs
    DESKTOP_DIR=$(grep '^XDG_DESKTOP_DIR' "$HOME/.config/user-dirs.dirs" 2>/dev/null \
        | cut -d'"' -f2 | sed "s|\$HOME|$HOME|")
fi

if [ -z "$DESKTOP_DIR" ] || [ ! -d "$DESKTOP_DIR" ]; then
    echo "ERROR: Desktop folder not found at: $DESKTOP_DIR"
    echo "Please create it first, or edit this script."
    exit 1
fi

echo "Desktop folder: $DESKTOP_DIR"

# ── Language detection ────────────────────────────────────────────────────────
LANG_CODE="${LANG:0:2}"
case "$LANG_CODE" in
    nl)
        ICON_NAME="USB-Schijf Registreren"
        ICON_COMMENT="Sluit de USB aan en klik hier om er een schijfletter aan toe te kennen"
        ICON_FILE="USB-Registreren.desktop"
        ;;
    *)
        ICON_NAME="Register USB Drive"
        ICON_COMMENT="Plug in your USB, then click this to assign it a drive letter"
        ICON_FILE="Register-USB.desktop"
        ;;
esac

LAUNCHER="$DESKTOP_DIR/$ICON_FILE"

# ── Write .desktop file ───────────────────────────────────────────────────────
cat > "$LAUNCHER" <<EOF
[Desktop Entry]
Type=Application
Name=$ICON_NAME
Comment=$ICON_COMMENT
Exec=/usr/local/bin/usb-register
Icon=drive-removable-media-usb
Terminal=false
Categories=Utility;
EOF

chmod +x "$LAUNCHER"

# Mark as trusted (Cinnamon / Nemo)
if command -v gio >/dev/null 2>&1; then
    gio set "$LAUNCHER" metadata::trusted true 2>/dev/null || true
fi

echo "Installed: $LAUNCHER"
echo "Done. The icon should appear on your desktop."
