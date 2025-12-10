#!/usr/bin/env bash
set -euo pipefail

# --- Run as normal user, not via sudo ---
if [[ $EUID -eq 0 ]]; then
  echo "This script must be run as a regular user (without sudo)." >&2
  echo "Usage: ./install.sh [--no-reboot|--reboot]" >&2
  exit 1
fi

# --- Argument parsing ---
WANT_REBOOT="ask"

for arg in "$@"; do
  case "$arg" in
    --no-reboot)
      WANT_REBOOT="no"
      ;;
    --reboot)
      WANT_REBOOT="yes"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: ./install.sh [--no-reboot|--reboot]" >&2
      exit 1
      ;;
  esac
done

echo "== Installing required packages =="
if ! command -v dnf >/dev/null 2>&1; then
  echo "This installer expects Fedora (dnf). Aborting." >&2
  exit 1
fi
sudo dnf -y install ydotool wl-clipboard

echo "== Creating groups and service account =="
sudo groupadd -r uinput  2>/dev/null || true
sudo groupadd -r ydotool 2>/dev/null || true
if ! id -u ydotoold >/dev/null 2>&1; then
  sudo useradd -r -s /sbin/nologin -g ydotool -M ydotoold
fi
sudo usermod -aG uinput ydotoold
sudo usermod -aG ydotool "$USER" || true

echo "== Ensuring /dev/uinput permissions via udev =="
sudo tee /etc/udev/rules.d/60-uinput-perms.rules >/dev/null <<'RULE'
KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"
RULE
sudo udevadm control --reload
sudo modprobe uinput || true
sudo udevadm trigger --subsystem-match=misc --sysname-match=uinput || true
ls -l /dev/uinput || true

echo "== Installing user script =="
install -d -m 0755 "$HOME/.local/bin"
install -m 0755 ./type-clipboard "$HOME/.local/bin/type-clipboard"

echo "== Installing and starting systemd service =="
sudo install -m 0644 ./ydotoold.service /etc/systemd/system/ydotoold.service
sudo systemctl daemon-reload
sudo systemctl enable --now ydotoold.service

echo "== Waiting for socket =="
for i in {1..20}; do
  if sudo test -S /run/ydotoold/socket; then
    break
  fi
  sleep 0.2
done
sudo ls -l /run/ydotoold/socket || true

echo
echo "✅ Install complete."
echo "• Script: $HOME/.local/bin/type-clipboard"
echo "• Service: ydotoold.service  (socket: /run/ydotoold/socket)"
echo "• You may need a reboot to pick up new group membership and udev rules."

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

if [[ "$WANT_REBOOT" == "ask" ]]; then
  if ! read -r -p "To complete the installation a reboot is required. Reboot now? [Y/n]: " ans; then
    ans="Y"
  fi
  ans="${ans:-Y}"
  case "$ans" in
    [Yy]*)
      reboot_now
      ;;
    *)
      echo "Okay. Please reboot later to finalize the installation."
      ;;
  esac
elif [[ "$WANT_REBOOT" == "yes" ]]; then
  reboot_now
else
  echo "Skipping reboot (per --no-reboot). Reboot later to finalize."
fi
