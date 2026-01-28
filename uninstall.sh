#!/usr/bin/env bash
#
# Uninstall micmute-led-sync

set -euo pipefail

echo "=== Uninstalling micmute-led-sync ==="
echo ""

# Stop and disable service
echo "Stopping user service..."
systemctl --user disable --now micmute-led-sync.service 2>/dev/null || true

# Remove user files
echo "Removing user files..."
rm -f "$HOME/.local/bin/micmute-led-sync"
rm -f "$HOME/.config/systemd/user/micmute-led-sync.service"
rm -f "$HOME/.config/micmute-led/config"
rmdir "$HOME/.config/micmute-led" 2>/dev/null || true

# Remove system files (requires sudo)
if command -v sudo >/dev/null 2>&1; then
    echo "Removing system files..."
    sudo rm -f /etc/udev/rules.d/90-micmute-led.rules
    sudo rm -f /etc/tmpfiles.d/micmute-led.conf
    
    # Remove UCM configuration
    sudo rm -rf /usr/share/alsa/ucm2/conf.d/thinkpad-micmute
    
    # Remove AppArmor profile if it exists
    if [[ -f /etc/apparmor.d/usr.bin.micmute-led-sync ]]; then
        echo "Removing AppArmor profile..."
        sudo apparmor_parser -R /etc/apparmor.d/usr.bin.micmute-led-sync 2>/dev/null || true
        sudo rm -f /etc/apparmor.d/usr.bin.micmute-led-sync
    fi
    
    sudo udevadm control --reload-rules
    sudo udevadm trigger -s leds
else
    echo "sudo not available; skipping /etc cleanup." >&2
fi

systemctl --user daemon-reload

echo ""
echo "Uninstall complete."
echo ""
echo "Note: You may want to manually:"
echo "  - Remove yourself from 'video' and 'input' groups if desired"
echo "  - Unload snd_ctl_led module: sudo modprobe -r snd_ctl_led"
