#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'Usage: ./install.sh [--user-only] [--no-reboot|--reboot]'
}

if [[ $EUID -eq 0 ]]; then
  echo 'Run this script as a regular user (without sudo).' >&2
  exit 1
fi

reboot_requested=false
user_only=false
for arg in "$@"; do
  case "$arg" in
    --user-only) user_only=true ;;
    --no-reboot) reboot_requested=false ;;
    --reboot) reboot_requested=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
rule_name=70-type-clipboard-uinput.rules

install_packages() {
  command -v dnf >/dev/null 2>&1 || { echo 'This installer requires Fedora (dnf).' >&2; exit 1; }
  echo 'Installing dependencies from the configured Fedora repositories.'
  sudo dnf install -y dotool wl-clipboard ibus
}

configure_uinput_access() {
  echo 'Granting the active local desktop session access to /dev/uinput.'
  sudo install -m 0644 "$script_dir/$rule_name" "/etc/udev/rules.d/$rule_name"

  # Migrate only the exact rule shipped by older versions. Preserve customized
  # rules, existing groups and memberships, and other applications' permissions.
  local legacy_rule=/etc/udev/rules.d/60-uinput-perms.rules
  local legacy_contents='KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"'
  if [[ -f "$legacy_rule" && "$(<"$legacy_rule")" == "$legacy_contents" ]]; then
    sudo rm -f -- "$legacy_rule"
  fi

  sudo modprobe uinput
  sudo udevadm control --reload
  sudo udevadm trigger --action=change --subsystem-match=misc --sysname-match=uinput
  sudo udevadm settle
  if [[ ! -w /dev/uinput ]]; then
    echo 'Your session cannot write /dev/uinput. Log into a local graphical session and rerun the installer.' >&2
    exit 1
  fi
}

install_files() {
  install -d -m 0755 "$HOME/.local/bin" "$unit_dir"
  install -m 0755 "$script_dir/type-clipboard" "$HOME/.local/bin/type-clipboard"
  install -m 0644 "$script_dir/dotoold.service" "$unit_dir/dotoold.service"
  systemctl --user daemon-reload
  # Remove the old default.target link when upgrading, without stopping the unit.
  systemctl --user disable dotoold.service
  systemctl --user enable dotoold.service
  systemctl --user restart dotoold.service
  systemctl --user is-active --quiet dotoold.service
}

if ! "$user_only"; then
  install_packages
  configure_uinput_access
fi
install_files

printf 'Installed %s/.local/bin/type-clipboard\n' "$HOME"
echo 'dotoold.service is enabled for graphical sessions. No reboot is normally needed.'
if "$reboot_requested"; then
  sudo systemctl reboot
fi
