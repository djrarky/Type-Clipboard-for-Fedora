#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'Usage: ./uninstall.sh [--purge] [--remove-packages] [--no-reboot|--reboot]'
}

if [[ $EUID -eq 0 ]]; then
  echo 'Run this script as a regular user (without sudo).' >&2
  exit 1
fi

purge=false
remove_packages=false
reboot_requested=false
for arg in "$@"; do
  case "$arg" in
    --purge) purge=true ;;
    --remove-packages) remove_packages=true ;;
    --no-reboot) reboot_requested=false ;;
    --reboot) reboot_requested=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}"

if [[ -f "$unit_dir/dotoold.service" ]]; then
  systemctl --user disable --now dotoold.service
  rm -f -- "$unit_dir/dotoold.service"
  systemctl --user daemon-reload
fi
rm -f -- "$HOME/.local/bin/type-clipboard"
rm -f -- "$runtime_dir/type-clipboard.layout" "$runtime_dir/type-clipboard.layout.env"
rm -f -- "$runtime_dir/type-clipboard.cancel"
# dotoold removes its own FIFO. Leave the lock inode in place so an in-flight
# invocation cannot accidentally share its name with a newly created lock.

if "$purge"; then
  rule_name=70-type-clipboard-uinput.rules
  rule_path="/etc/udev/rules.d/$rule_name"
  if [[ -f "$rule_path" ]]; then
    if cmp -s -- "$script_dir/$rule_name" "$rule_path"; then
      sudo rm -f -- "$rule_path"
    else
      echo "Preserving customized rule: $rule_path" >&2
    fi
  fi
  legacy_rule=/etc/udev/rules.d/60-uinput-perms.rules
  legacy_contents='KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"'
  if [[ -f "$legacy_rule" && "$(<"$legacy_rule")" == "$legacy_contents" ]]; then
    sudo rm -f -- "$legacy_rule"
  fi
  sudo udevadm control --reload
  sudo udevadm trigger --action=change --subsystem-match=misc --sysname-match=uinput
  sudo udevadm settle
  echo 'Existing device groups and memberships were preserved.'
fi

if "$remove_packages"; then
  command -v dnf >/dev/null 2>&1 || { echo 'dnf is required to remove packages.' >&2; exit 1; }
  sudo dnf remove -y dotool wl-clipboard
else
  echo 'Dependencies were kept. Use --remove-packages to explicitly remove dotool and wl-clipboard.'
fi

echo 'Uninstall complete. Existing repository configuration was preserved.'
if "$reboot_requested"; then
  sudo systemctl reboot
fi
