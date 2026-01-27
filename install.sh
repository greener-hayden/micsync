#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need_cmd install
need_cmd systemctl
need_cmd udevadm
need_cmd systemd-tmpfiles

if ! command -v libinput >/dev/null 2>&1; then
  echo "Warning: libinput not found. Install 'libinput' or 'libinput-tools' package." >&2
  echo "The key listener will not work without it." >&2
fi

# Install user script
install -m 755 "$SCRIPT_DIR/micmute-led-sync" "$HOME/.local/bin/micmute-led-sync"

# Install user service
mkdir -p "$HOME/.config/systemd/user"
install -m 644 "$SCRIPT_DIR/micmute-led-sync.service" "$HOME/.config/systemd/user/micmute-led-sync.service"

# Install system rules (requires sudo)
if command -v sudo >/dev/null 2>&1; then
  sudo install -m 644 "$SCRIPT_DIR/90-micmute-led.rules" /etc/udev/rules.d/90-micmute-led.rules
  sudo install -m 644 "$SCRIPT_DIR/micmute-led.conf" /etc/tmpfiles.d/micmute-led.conf

  sudo udevadm control --reload-rules
  sudo udevadm trigger -s leds
  sudo systemd-tmpfiles --create /etc/tmpfiles.d/micmute-led.conf

  sudo usermod -aG video,input "$USER" || true
else
  echo "sudo not available; skipping /etc changes and group updates." >&2
fi

# Enable service
systemctl --user daemon-reload
systemctl --user enable --now micmute-led-sync.service

cat <<'MSG'

Install complete.
- If you were just added to groups (video/input), log out and back in.
- Check status: systemctl --user status micmute-led-sync.service
MSG
