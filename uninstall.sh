#!/usr/bin/env bash
set -euo pipefail

# --- Run as normal user, not via sudo ---
if [[ $EUID -eq 0 ]]; then
  echo "This script must be run as a regular user (without sudo)." >&2
  echo "Usage: ./uninstall.sh [--purge] [--no-reboot|--reboot]" >&2
  exit 1
fi

# --- Argument parsing ---
PURGE=false
WANT_REBOOT="ask"

for arg in "$@"; do
  case "$arg" in
    --purge)
      PURGE=true
      ;;
    --no-reboot)
      WANT_REBOOT="no"
      ;;
    --reboot)
      WANT_REBOOT="yes"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: ./uninstall.sh [--purge] [--no-reboot|--reboot]" >&2
      exit 1
      ;;
  esac
done

# "Real" user is the one running the script
USER_NAME="$USER"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

echo "== Stopping and removing systemd services =="
sudo systemctl disable --now ydotoold.service 2>/dev/null || true
sudo systemctl disable --now ydotoold-basic.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/ydotoold.service /etc/systemd/system/ydotoold-basic.service
sudo systemctl daemon-reload
sudo systemctl reset-failed ydotoold.service 2>/dev/null || true
sudo systemctl reset-failed ydotoold-basic.service 2>/dev/null || true

# User unit cleanup (if it ever existed)
if [[ -n "${USER_HOME:-}" && -d "$USER_HOME" ]]; then
  sudo runuser -l "$USER_NAME" -c 'systemctl --user disable --now ydotoold.service' 2>/dev/null || true
  sudo rm -f "$USER_HOME/.config/systemd/user/ydotoold.service" 2>/dev/null || true
  sudo runuser -l "$USER_NAME" -c 'systemctl --user daemon-reload' 2>/dev/null || true
fi

echo "== Removing runtime sockets/dirs and script =="
sudo pkill ydotoold 2>/dev/null || true
sudo rm -rf /run/ydotoold /tmp/.ydotool_socket

if [[ -n "${USER_HOME:-}" && -d "$USER_HOME" ]]; then
  rm -f "$USER_HOME/.local/bin/type-clipboard" 2>/dev/null || true
fi

if "$PURGE"; then
  echo "== Purge mode: removing udev rule, users, and groups (if possible) =="
  sudo rm -f /etc/udev/rules.d/60-uinput-perms.rules 2>/dev/null || true
  sudo udevadm control --reload 2>/dev/null || true
  sudo udevadm trigger --subsystem-match=misc --sysname-match=uinput 2>/dev/null || true

  if id -u ydotoold >/dev/null 2>&1; then
    sudo userdel ydotoold 2>/dev/null || true
  fi
  sudo groupdel ydotool  2>/dev/null || true
  sudo groupdel uinput   2>/dev/null || true

  echo "== (Optional) remove 'ydotool' package =="
  if ! command -v dnf >/dev/null 2>&1; then
    echo "dnf not found; if you wish, remove 'ydotool' manually."
  else
    if rpm -q ydotool >/dev/null 2>&1; then
      if ! read -r -p "Remove 'ydotool' package via dnf? [y/N]: " ans; then
        ans="N"
      fi
      ans="${ans:-N}"
      case "$ans" in
        [Yy]*)
          sudo dnf -y remove ydotool
          ;;
        *)
          echo "Keeping 'ydotool' package installed."
          ;;
      esac
    else
      echo "'ydotool' package is not installed (nothing to remove)."
    fi
  fi
else
  echo "== Kept groups and udev rule. Use '--purge' to remove them as well."
fi

echo "✅ Uninstall complete."

# ---------- Reboot prompt ----------
reboot_now() {
  if command -v gnome-session-quit >/dev/null 2>&1 && [[ -n "${XDG_SESSION_TYPE:-}" ]]; then
    echo "Rebooting via GNOME…"
    gnome-session-quit --reboot --no-prompt
  else
    echo "Rebooting via systemd…"
    sudo systemctl reboot
  fi
}

read_reboot() {
  if ! read -r -p "A reboot is recommended to fully unload drivers and clear inhibitors. Reboot now? [Y/n]: " ans; then
    ans="Y"
  fi
  ans="${ans:-Y}"
  case "$ans" in
    [Yy]*)
      reboot_now
      ;;
    *)
      echo "Okay. Reboot later to finish cleanup."
      ;;
  esac
}

case "$WANT_REBOOT" in
  ask) read_reboot ;;
  yes) reboot_now ;;
  no)  echo "Skipping reboot (per --no-reboot).";;
esac
