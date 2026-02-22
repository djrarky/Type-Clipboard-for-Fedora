Info: this was made with the assistance of AI (codex),
but I do think this is a solid implementation. 
# Type Clipboard for Fedora (Wayland)

Type your Wayland clipboard into the focused app using `dotoolc`.
This project is Fedora-specific and assumes `dnf`, `systemd --user`, and IBus.

## What This Repo Contains

- `type-clipboard` (user command)
- `dotoold.service` (`systemd --user` service)
- `install.sh` / `uninstall.sh`

## Install

```bash
chmod u+x install.sh uninstall.sh
./install.sh
```

`install.sh` does this:

1. `sudo dnf -y install dnf-plugins-core`
2. `sudo dnf copr enable -y smallcms/dotool`
3. `sudo dnf install -y dotool wl-clipboard`
4. Adds your user to `uinput`
5. Installs `/etc/udev/rules.d/60-uinput-perms.rules`
6. Installs and enables `~/.config/systemd/user/dotoold.service`
7. Installs `~/.local/bin/type-clipboard`
8. Keeps `dotoold` layout in sync with your active `ibus engine` and restarts the
   user service only when layout/variant changes

Bind a desktop/keyboard shortcut to:

```text
/home/<you>/.local/bin/type-clipboard
```

## Uninstall

```bash
./uninstall.sh
./uninstall.sh --purge
```

`uninstall.sh` always:

1. Stops/disables user service `dotoold.service`
2. Removes `~/.config/systemd/user/dotoold.service`
3. Removes `~/.local/bin/type-clipboard`
4. Runs `sudo dnf remove -y dotool wl-clipboard`
5. Runs `sudo dnf copr disable -y smallcms/dotool`
6. Removes COPR repo file if present

`--purge` also removes:

- udev rule for `/dev/uinput`
- your `uinput` group membership
- `uinput` group (if removable)

## Verify

```bash
systemctl --user status dotoold.service
id
ls -l /dev/uinput
```

## Notes

- If you edit scripts in this repo, run `./install.sh --no-reboot` to copy the
  latest `type-clipboard` and service files into your home directory.
- `type-clipboard` stores the last applied keyboard layout in
  `${XDG_RUNTIME_DIR}/type-clipboard.layout` to avoid unnecessary service restarts.
