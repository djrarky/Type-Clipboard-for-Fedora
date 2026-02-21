#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "This script must be run as a regular user (without sudo)." >&2
  echo "Usage: ./uninstall.sh [--purge] [--no-reboot|--reboot]" >&2
  exit 1
fi

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

USER_NAME="$USER"

remove_user_files() {
  echo "== Removing user files =="
  if [[ -d "$HOME" ]]; then
    systemctl --user disable --now dotoold.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/dotoold.service" 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    rm -f "$HOME/.local/bin/type-clipboard" 2>/dev/null || true
    rm -f "${XDG_RUNTIME_DIR:-/run/user/$UID}/dotool-pipe" 2>/dev/null || true
    rm -f "${XDG_RUNTIME_DIR:-/run/user/$UID}/type-clipboard.layout" 2>/dev/null || true
  fi
}

remove_packages() {
  echo "== Removing packages and COPR repo =="
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf remove -y dotool wl-clipboard || true
    sudo dnf copr disable -y smallcms/dotool || true
    sudo rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:smallcms:dotool.repo 2>/dev/null || true
  else
    echo "dnf not found; remove packages and COPR repo manually."
  fi
}

purge_uinput_if_requested() {
  if "$PURGE"; then
    echo "== Purge mode: removing udev rule and uinput group =="
    sudo rm -f /etc/udev/rules.d/60-uinput-perms.rules 2>/dev/null || true
    sudo udevadm control --reload 2>/dev/null || true
    sudo udevadm trigger --subsystem-match=misc --sysname-match=uinput 2>/dev/null || true
    if getent group uinput >/dev/null 2>&1; then
      sudo gpasswd -d "$USER_NAME" uinput 2>/dev/null || true
    fi
    sudo groupdel uinput 2>/dev/null || true
  else
    echo "== Kept uinput group + udev rule (use --purge to remove)."
  fi
}

remove_user_files
remove_packages
purge_uinput_if_requested

echo "Uninstall complete."

reboot_now() {
  echo "Rebooting via systemd…"
  sudo systemctl reboot
}

read_reboot() {
  if ! read -r -p "Reboot now? [Y/n]: " ans; then
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
