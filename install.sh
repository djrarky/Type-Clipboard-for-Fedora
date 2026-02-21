#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "This script must be run as a regular user (without sudo)." >&2
  echo "Usage: ./install.sh [--no-reboot|--reboot]" >&2
  exit 1
fi

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

install_packages() {
  echo "== Installing required packages =="
  if ! command -v dnf >/dev/null 2>&1; then
    echo "This installer expects Fedora (dnf). Aborting." >&2
    exit 1
  fi
  sudo dnf -y install dnf-plugins-core
  sudo dnf copr enable -y smallcms/dotool
  sudo dnf install -y dotool wl-clipboard
}

configure_uinput_access() {
  echo "== Configuring group access for /dev/uinput =="
  sudo groupadd -r uinput 2>/dev/null || true
  sudo usermod -aG uinput "$USER" || true

  echo "== Ensuring /dev/uinput permissions via udev =="
  sudo tee /etc/udev/rules.d/60-uinput-perms.rules >/dev/null <<'RULE'
KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"
RULE
  sudo udevadm control --reload
  sudo modprobe uinput || true
  sudo udevadm trigger --subsystem-match=misc --sysname-match=uinput || true
  ls -l /dev/uinput || true
}

install_files() {
  echo "== Installing user script =="
  install -d -m 0755 "$HOME/.local/bin"
  install -m 0755 ./type-clipboard "$HOME/.local/bin/type-clipboard"

  echo "== Installing and starting user service =="
  install -d -m 0755 "$HOME/.config/systemd/user"
  install -m 0644 ./dotoold.service "$HOME/.config/systemd/user/dotoold.service"
  systemctl --user daemon-reload
  systemctl --user enable --now dotoold.service
}

install_packages
configure_uinput_access
install_files

echo
echo "Install complete."
echo "- Script: $HOME/.local/bin/type-clipboard"
echo "- Service: dotoold.service (systemd --user)"
echo "- Client: type-clipboard -> dotoolc"
echo "- Device access: your user was added to group 'uinput'"
echo "- Reboot or re-login may be needed for group changes."

reboot_now() {
  echo "Rebooting via systemd…"
  sudo systemctl reboot
}

if [[ "$WANT_REBOOT" == "ask" ]]; then
  if ! read -r -p "Reboot now? [Y/n]: " ans; then
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
