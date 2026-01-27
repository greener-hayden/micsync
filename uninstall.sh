#!/usr/bin/env bash
set -euo pipefail

# Stop and disable service
systemctl --user disable --now micmute-led-sync.service || true

rm -f "$HOME/.local/bin/micmute-led-sync"
rm -f "$HOME/.config/systemd/user/micmute-led-sync.service"

if command -v sudo >/dev/null 2>&1; then
  sudo rm -f /etc/udev/rules.d/90-micmute-led.rules
  sudo rm -f /etc/tmpfiles.d/micmute-led.conf
  sudo udevadm control --reload-rules
  sudo udevadm trigger -s leds
else
  echo "sudo not available; skipping /etc cleanup." >&2
fi

systemctl --user daemon-reload

cat <<'MSG'

Uninstall complete.
MSG
