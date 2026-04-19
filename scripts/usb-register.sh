#!/bin/bash
# ==============================================================================
#  usb-register — assign persistent Windows-style drive letters to USB disks
#
#  How it works:
#    - Identifies each USB by its filesystem UUID (never changes)
#    - Keeps a registry file mapping UUID → letter (D:, E:, F: ...)
#    - Mounts to a fixed path like /mnt/usb/USB_D
#    - Creates a symlink in ~/.wine/dosdevices/ so Wine sees it as D:\
#
#  Usage:
#    sudo usb-register          (or run via the desktop launcher icon)
# ==============================================================================
set -u

REGISTRY="/etc/usb-drives/registry.conf"
MOUNT_BASE="/mnt/usb"
LETTERS=(D E F G H I J K L M N O P Q R S T U V W X Y Z)

# ── Resolve the desktop user ──────────────────────────────────────────────────
if   [[ -n "${PKEXEC_UID:-}" ]]; then WINE_USER=$(getent passwd "$PKEXEC_UID" | cut -d: -f1)
elif [[ -n "${SUDO_USER:-}"  ]]; then WINE_USER="$SUDO_USER"
else WINE_USER="$USER"; fi
WINE_HOME=$(getent passwd "$WINE_USER" | cut -d: -f6)
WINE_DOSDEVICES="$WINE_HOME/.wine/dosdevices"

# ── Helpers ───────────────────────────────────────────────────────────────────
need_root() {
    [[ $EUID -eq 0 ]] && return
    exec pkexec --disable-internal-agent \
        env DISPLAY="${DISPLAY:-}" XAUTHORITY="${XAUTHORITY:-}" "$0" "$@"
}

notify() {
    echo "$*"
    if command -v zenity >/dev/null && [[ -n "${DISPLAY:-}" ]]; then
        sudo -u "$WINE_USER" DISPLAY="${DISPLAY:-}" XAUTHORITY="${XAUTHORITY:-}" \
            zenity --info --no-wrap --title="USB Drive" --text="$*" 2>/dev/null || true
    fi
}

error_exit() {
    echo "ERROR: $*" >&2
    if command -v zenity >/dev/null && [[ -n "${DISPLAY:-}" ]]; then
        sudo -u "$WINE_USER" DISPLAY="${DISPLAY:-}" XAUTHORITY="${XAUTHORITY:-}" \
            zenity --error --no-wrap --title="USB Drive Error" --text="$*" 2>/dev/null || true
    fi
    exit 1
}

# ── Initialise registry ───────────────────────────────────────────────────────
need_root "$@"
mkdir -p "$(dirname "$REGISTRY")" "$MOUNT_BASE"
touch "$REGISTRY"

# ── Detect USB devices ────────────────────────────────────────────────────────
mapfile -t USB_DEVS < <(lsblk -rno NAME,TRAN | awk '$2=="usb"{print "/dev/"$1}')

if [[ ${#USB_DEVS[@]} -eq 0 ]]; then
    error_exit "No USB storage devices detected.\nPlug in a USB drive and try again."
fi

# ── Process each USB partition ────────────────────────────────────────────────
for DEV in "${USB_DEVS[@]}"; do
    # Skip devices without a filesystem
    UUID=$(blkid -s UUID -o value "$DEV" 2>/dev/null) || continue
    [[ -z "$UUID" ]] && continue

    # ── Already registered? ───────────────────────────────────────────────────
    if grep -q "^$UUID " "$REGISTRY" 2>/dev/null; then
        LETTER=$(grep "^$UUID " "$REGISTRY" | awk '{print $2}')
        MOUNT_POINT="$MOUNT_BASE/USB_${LETTER}"

        # Re-mount if not already mounted
        if ! mountpoint -q "$MOUNT_POINT"; then
            mkdir -p "$MOUNT_POINT"
            mount "$DEV" "$MOUNT_POINT"
        fi

        # Ensure Wine symlink still exists
        SYMLINK="$WINE_DOSDEVICES/${LETTER,,}:"
        if [[ ! -L "$SYMLINK" ]]; then
            ln -sf "$MOUNT_POINT" "$SYMLINK"
        fi

        notify "USB already registered as ${LETTER}: — mounted at $MOUNT_POINT"
        continue
    fi

    # ── Assign next free letter ───────────────────────────────────────────────
    USED_LETTERS=$(awk '{print $2}' "$REGISTRY" 2>/dev/null)
    NEW_LETTER=""
    for L in "${LETTERS[@]}"; do
        if ! echo "$USED_LETTERS" | grep -q "^${L}$"; then
            NEW_LETTER="$L"
            break
        fi
    done

    [[ -z "$NEW_LETTER" ]] && error_exit "All drive letters (D–Z) are in use!"

    # ── Mount and link ────────────────────────────────────────────────────────
    MOUNT_POINT="$MOUNT_BASE/USB_${NEW_LETTER}"
    mkdir -p "$MOUNT_POINT"
    mount "$DEV" "$MOUNT_POINT" || error_exit "Failed to mount $DEV"

    # Save to registry
    echo "$UUID $NEW_LETTER $DEV" >> "$REGISTRY"

    # Create Wine dosdevices symlink  (lowercase letter + colon = Wine drive)
    mkdir -p "$WINE_DOSDEVICES"
    ln -sf "$MOUNT_POINT" "$WINE_DOSDEVICES/${NEW_LETTER,,}:"

    notify "USB registered as ${NEW_LETTER}:\nMounted at: $MOUNT_POINT\nDevice: $DEV\n\nIn SAM Broadcaster use drive ${NEW_LETTER}:\\"
done
