#!/usr/bin/env bash
set -euo pipefail

PURGE="${1:-}"
WANT_REBOOT="ask"
if [[ "${2:-}" == "--no-reboot" ]]; then WANT_REBOOT="no"; fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

echo "== Stopping and removing systemd services =="
sudo systemctl disable --now ydotoold.service 2>/dev/null || true
sudo systemctl disable --now ydotoold-basic.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/ydotoold.service /etc/systemd/system/ydotoold-basic.service
sudo systemctl daemon-reload
sudo systemctl reset-failed ydotoold.service 2>/dev/null || true
sudo systemctl reset-failed ydotoold-basic.service 2>/dev/null || true

# User unit cleanup (if it ever existed)
if [[ -n "$USER_HOME" && -d "$USER_HOME" ]]; then
  sudo runuser -l "$USER_NAME" -c 'systemctl --user disable --now ydotoold.service' 2>/dev/null || true
  sudo rm -f "$USER_HOME/.config/systemd/user/ydotoold.service" 2>/dev/null || true
  sudo runuser -l "$USER_NAME" -c 'systemctl --user daemon-reload' 2>/dev/null || true
fi

echo "== Removing runtime sockets/dirs and script =="
sudo pkill ydotoold 2>/dev/null || true
sudo rm -rf /run/ydotoold /tmp/.ydotool_socket
rm -f "$HOME/.local/bin/type-clipboard" 2>/dev/null || true

if [[ "$PURGE" == "--purge" ]]; then
  echo "== Purge mode: removing udev rule, users, and groups (if possible) =="
  sudo rm -f /etc/udev/rules.d/60-uinput-perms.rules 2>/dev/null || true
  sudo udevadm control --reload 2>/dev/null || true

  if id -u ydotoold >/dev/null 2>&1; then
    sudo userdel ydotoold 2>/dev/null || true
  fi
  sudo groupdel ydotool  2>/dev/null || true
  sudo groupdel uinput   2>/dev/null || true

  echo "== (Optional) remove packages =="
  echo "Run: sudo dnf remove ydotool wl-clipboard"
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
  read -r -p "A reboot is recommended to fully unload drivers and clear inhibitors. Reboot now? [Y/n]: " ans
  ans="${ans:-Y}"
  case "$ans" in
    [Yy]*) reboot_now ;;
    *) echo "Okay. Reboot later to finish cleanup."; ;;
  esac
}

case "$WANT_REBOOT" in
  ask) read_reboot ;;
  yes) reboot_now ;;
  no)  echo "Skipping reboot (per --no-reboot).";;
esac
