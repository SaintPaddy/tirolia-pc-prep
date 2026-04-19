# tirolia-pc-prep

One-command setup script for a fresh **Linux Mint** installation.

## What it installs & configures

| # | Task | Details |
|---|------|---------|
| 1 | **Wine** (stable) | From official WineHQ repo, auto-detects Mint version |
| 2 | **Teams for Linux** | Community Flatpak by [IsmaelMartinez](https://github.com/IsmaelMartinez/teams-for-linux) |
| 3 | **TeamViewer** | Latest `.deb` from TeamViewer directly |
| 4 | **Cinnamon settings** | Start button label, filled-badge icon, ungrouped taskbar with app names |
| 5 | **USB drive-letter tool** | Assigns persistent `D:`, `E:` etc. to USB disks for Wine/SAM Broadcaster |

---

## Usage

Run this single command on your fresh Linux Mint machine:

```bash
curl -fsSL https://raw.githubusercontent.com/SaintPaddy/tirolia-pc-prep/main/setup.sh | bash
```

Or if you prefer to inspect first:

```bash
curl -fsSL https://raw.githubusercontent.com/SaintPaddy/tirolia-pc-prep/main/setup.sh -o setup.sh
cat setup.sh        # read it first
bash setup.sh       # then run it
```

---

## USB Drive Letter Tool

After setup, a desktop icon will appear: **"Register USB Drive"** (or *"USB-Schijf Registreren"* on Dutch systems).

- Plug in a USB drive full of MP3s
- Click the desktop icon
- The drive is assigned a persistent letter (`D:`, `E:`, etc.)
- SAM Broadcaster will always find it at the same path

The mapping is saved in `/etc/usb-drives/registry.conf`. Plugging in the same USB again will always get the same letter.

---

## Repo structure

```
tirolia-pc-prep/
├── setup.sh                        ← run this on a new machine
├── README.md
└── scripts/
    ├── usb-register.sh             ← USB drive-letter tool (copied to /usr/local/bin)
    └── install-usb-launcher.sh     ← creates the desktop icon
```

---

## Cinnamon settings applied

| Setting | Value |
|---------|-------|
| Menu icon | `linuxmint-logo-filled-badge` |
| Menu label | `   Start      ` |
| Group windows | Off |
| Taskbar button label | Application name |

---

## Notes

- Tested on **Linux Mint 21.x** (Ubuntu Jammy base) and **22.x** (Ubuntu Noble base)
- Teams for Linux is an **unofficial** community client — works well for personal/small business use
- The USB tool assigns letters starting at `D:` (Wine reserves `A:`, `B:`, `C:`)
