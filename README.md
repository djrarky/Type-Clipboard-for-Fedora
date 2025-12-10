# Type Clipboard for Fedora (Wayland/GNOME)

Type whatever’s in your **Wayland** clipboard into the focused app — even apps that block paste.
This repo provides:

- a tiny user script: `~/.local/bin/type-clipboard`
- a **hardened systemd service**: `ydotoold.service` (runs as `ydotoold` user)
- group-gated socket at **`/run/ydotoold/socket`** (only `root` + users in group `ydotool`)
- **install/uninstall** scripts (with `--purge` and an interactive reboot prompt)

Works on **Fedora + GNOME (Wayland)** using `ydotool` and `/dev/uinput`.

---

## Why not just paste?

Some apps deliberately disable paste. This uses a virtual keyboard at the kernel level to **type** the clipboard, key by key.

---

## Requirements

- Fedora (dnf-based)
- GNOME on Wayland
- Packages: `ydotool`, `wl-clipboard` (installer will install them)

---

## Quick start

```bash
git clone https://github.com/djrarky/Type-Clipboard-for-Fedora.git
cd Type-Clipboard-for-Fedora
chmod u+x install.sh uninstall.sh
./install.sh
# You'll be prompted to reboot (recommended to pick up groups/udev rules)
```

Bind a GNOME shortcut to:

```
/home/<you>/.local/bin/type-clipboard
```

---

## What gets installed

```
~/.local/bin/type-clipboard        # user command (types clipboard via ydotool)
./ydotoold.service                 # installed to /etc/systemd/system/
```

Service details:

- **User:** `ydotoold`
- **Groups:** `ydotool` (owns the socket), `uinput` (access to `/dev/uinput`)
- **Socket:** `/run/ydotoold/socket` (mode `0660`, owner `ydotoold:ydotool`)
- **Device:** `/dev/uinput` (mode `0660`, group `uinput` via udev rule)

---

## Install / Uninstall

### Install

```bash
./install.sh            # prompts to reboot (default Yes)
# or
./install.sh --no-reboot
```

What it does:

- Installs `ydotool`
- Creates **users/groups**: `ydotoold` (service account), `ydotool` (socket), `uinput` (device)
- Adds **udev rule** so `/dev/uinput` → `root:uinput 0660`
- Installs the **systemd unit** and **user script**
- Starts the service and offers to **reboot**

### Uninstall

```bash
./uninstall.sh                  # prompts to reboot
./uninstall.sh --purge          # also removes udev rule + service account/groups
./uninstall.sh --purge --no-reboot
```

The uninstaller removes the unit(s), runtime sockets, resets systemd’s failed state, and removes the user script.  
`--purge` additionally removes the udev rule and tries to delete `ydotoold`, `ydotool`, and `uinput` (if safe).

---

## How it works

- `ydotoold` opens `/dev/uinput` and exposes a Unix socket so clients can send keystrokes.
- The client script grabs the Wayland clipboard via `wl-paste --no-newline` and feeds it to `ydotool type`.
- The compositor sees events as if they came from a real keyboard.

---

## Security model

- Only **root** and members of **`ydotool`** can access `/run/ydotoold/socket`.
- The daemon runs as **non-login** user `ydotoold` with only `uinput` capability via group membership.

---

## Troubleshooting

**Shortcut does nothing**
- Command path must be absolute (no `~`): `/home/<you>/.local/bin/type-clipboard`

**`Permission denied` on the socket**
- Ensure your user is in `ydotool`:
  ```bash
  sudo usermod -aG ydotool "$USER"
  ```
  Confirm your shell session has picked up membership in the 'ydotool' group
  ```bash
  # are you actually in the ydotool group in THIS shell?
  id

  # check dir + socket ownership/mode (+ SELinux context just in case)
  ls -ld /run/ydotoold
  ls -lZ /run/ydotoold/socket
  ```
  Expect:
  ```
  drwxrwx--- ydotoold ydotool /run/ydotoold
  srw-rw---- ydotoold ydotool /run/ydotoold/socket
  ```
- Reboot


---

## FAQ

**Can I change typing speed?**  
Yes: edit the script → `ydotool type --key-delay 10 -- "$t"`.
