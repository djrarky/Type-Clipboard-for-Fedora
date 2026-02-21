# Type Clipboard for Fedora (Wayland)

Type your Wayland clipboard into the focused app using `dotoolc`.

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

Bind a desktop shortcut to:

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
