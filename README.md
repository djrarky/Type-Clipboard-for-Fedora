# Type Clipboard for Fedora

Type the text on your clipboard into the focused application as keystrokes. This
is useful for remote consoles and fields that do not accept ordinary paste.

Designed for **Fedora with GNOME on Wayland**, using an IBus XKB keyboard layout.
Images are rejected, and you can cancel typing at any time.

## Install

Open a terminal in this repository's directory and run:

```bash
./install.sh
```

Run it as your normal user. The installer uses `sudo` for the system changes.
It installs the required packages (`dotool`, `wl-clipboard`, and `ibus`), sets up
device access for your active desktop session, and installs the typing command
and its background service. A reboot is normally unnecessary.

## Set up your shortcuts

Create custom keyboard shortcuts in GNOME Settings for these commands. Replace
`<you>` with your Linux username, or use the full installation path printed by
the installer.

| Action | Command |
| --- | --- |
| Type clipboard text | `/home/<you>/.local/bin/type-clipboard` |
| Cancel typing | `/home/<you>/.local/bin/type-clipboard --cancel` |

Choose whichever key combinations suit you. For example, Ctrl+Shift+X could be
used for cancellation. The installer does not create or change shortcuts.

Ctrl+Shift+V is already used for ordinary paste in many terminals, so choose a
different combination for typing if you want to keep that shortcut available.

## Use it

1. Copy some text.
2. Focus the field or application where you want it typed.
3. Press your typing shortcut and release the keys promptly.
4. Keep the same application focused and keyboard layout selected until typing
   finishes. Use your cancel shortcut whenever you want to stop.

Cancellation discards the remaining queued text. Characters already entered stay
in the application. The next typing request starts the service again automatically;
cancelling while idle is also fine.

### What happens to line breaks?

Line breaks inside the text produce Enter keypresses. Tabs are sent as keystrokes
too, so they may move between fields depending on the application.

**Trailing newlines** are line breaks at the very end of the copied text. For
example, `hello` followed by two line breaks would type `hello` and press Enter
twice. By default, those final line breaks are removed to avoid an unintended
final Enter press. Line breaks between lines are kept.

To keep the ending line breaks as well, use this command for your typing shortcut:

```text
/home/<you>/.local/bin/type-clipboard --preserve-trailing-newlines
```

### Images and text limits

- **Images are rejected before their contents are read**, including images that
  also offer a text representation. The clipboard must offer plain text.
- **The size limit is 64 KiB (65,536 bytes)**—roughly 65,000 ordinary English
  characters, and fewer for text using more bytes per character. This limit keeps
  very large clipboard contents out of the typing queue.
- Spaces and internal blank lines are retained. Windows-style line endings are
  converted to ordinary line breaks. NUL bytes and standalone carriage returns
  are rejected.
- Character support depends on `dotool` and your active keyboard layout. Some
  Unicode characters and non-XKB input methods are not supported.

Errors are reported to the terminal and, when available, through a desktop
notification. Clipboard contents are not included in the script's error messages.

## Uninstall

From the repository directory, run:

```bash
./uninstall.sh
```

This stops and disables the service and removes the user command, service file,
and runtime state. Dependencies and device-access rules are kept by default.

| Optional flag | Effect |
| --- | --- |
| `--purge` | Also removes the project's unmodified device-access rule. |
| `--remove-packages` | Also removes `dotool` and `wl-clipboard`, which may be used by other applications. |

You can combine these flags. Customized rules and IBus are preserved.

Installation and removal only reboot if you explicitly pass `--reboot`.
`--no-reboot` is also accepted and matches the default behavior.

## Troubleshooting

Check the background service and device permissions:

```bash
systemctl --user status dotoold.service
getfacl /dev/uinput
```

An inactive service is expected after cancellation. It starts again when you next
request typing. For service error details:

```bash
journalctl --user -u dotoold.service -n 30 --no-pager
```

If you see **“Another clipboard submission is still in progress”**, wait for the
submission to finish or use your cancel shortcut. A clipboard read already in
progress may take up to five seconds to finish cancelling and allow a new request.

A failed submission may have entered some text already. The script reports the
failure without retrying the text, so check the destination before trying again.

<details>
<summary>How it works and installed files</summary>

The command reads plain text with `wl-paste`, checks the active keyboard layout
with IBus, and sends commands through `dotoolc` to the persistent `dotoold` service.
A successful submission means the daemon received the commands; typing may still
be in progress after the submitting command exits.

| Location | Purpose |
| --- | --- |
| `~/.local/bin/type-clipboard` | The typing and cancellation command. |
| `~/.config/systemd/user/dotoold.service` | Background service, enabled for graphical sessions. Uses `$XDG_CONFIG_HOME/systemd/user/` when set. |
| `/etc/udev/rules.d/70-type-clipboard-uinput.rules` | Grants the active local session access to `/dev/uinput` through `uaccess`. |
| `$XDG_RUNTIME_DIR/type-clipboard.layout.env` | Keyboard layout and variant used by the service. |

Layout changes restart the service. Its layout settings are separate from the
user manager's global environment. Cancellation stops the service and marks
pending submissions as cancelled so they cannot resume afterward.

Concurrent submissions are rejected while a writer is running. Clipboard reads
and daemon readiness checks each have a five-second timeout; sending has a
fifteen-minute timeout. Failed payloads are never automatically resent.

Temporary clipboard data is stored in a file readable only by your user, in your
user-owned runtime directory. Reads are capped at 64 KiB plus one byte to detect
oversized content, and the temporary file is removed after reading or normal
error/signal cleanup. The FIFO uses that same runtime directory, with no shared
`/tmp` fallback.

</details>
