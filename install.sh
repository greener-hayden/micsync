#!/usr/bin/env bash
#
# Install micmute-led-sync with UCM best practices support
#
# This script installs:
#   - Userspace sync script (fallback for USB mics)
#   - UCM configuration (for internal mic per best practices)
#   - udev rules and tmpfiles configuration
#
# Best Practice Note:
# ALSA UCM recommends LEDs respond only to internal (built-in) resources.
# This installer sets up both UCM (recommended) and userspace fallback.

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

echo "=== micmute-led-sync Installer ==="
echo ""

# Check for libinput
if ! command -v libinput >/dev/null 2>&1; then
    echo "Warning: libinput not found. Install 'libinput' or 'libinput-tools' package." >&2
    echo "The key listener will not work without it." >&2
    echo ""
fi

# Check for ALSA UCM utilities
if ! command -v alsaucm >/dev/null 2>&1; then
    echo "Note: alsaucm not found. Install 'alsa-utils' for UCM support." >&2
    echo "The UCM configuration will be installed but may not work without alsaucm." >&2
    echo ""
fi

echo "Installing userspace components..."

# Create user directories
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.config/micmute-led"

# Install user script
install -m 755 "$SCRIPT_DIR/micmute-led-sync" "$HOME/.local/bin/micmute-led-sync"

# Install default user config (if not exists)
if [[ ! -f "$HOME/.config/micmute-led/config" ]]; then
    install -m 644 "$SCRIPT_DIR/micmute-led.conf" "$HOME/.config/micmute-led/config"
    echo "Created default config at ~/.config/micmute-led/config"
fi

# Install user service
install -m 644 "$SCRIPT_DIR/micmute-led-sync.service" "$HOME/.config/systemd/user/micmute-led-sync.service"

echo ""
echo "Installing system components (requires sudo)..."

# Install system files (requires sudo)
if command -v sudo >/dev/null 2>&1; then
    # Install udev rules
    sudo install -m 644 "$SCRIPT_DIR/90-micmute-led.rules" /etc/udev/rules.d/90-micmute-led.rules
    
    # Install tmpfiles configuration
    sudo install -m 644 "$SCRIPT_DIR/micmute-led.conf" /etc/tmpfiles.d/micmute-led.conf
    
    # Install UCM configuration (following ALSA best practices)
    UCM_DIR="/usr/share/alsa/ucm2/conf.d/thinkpad-micmute"
    sudo mkdir -p "$UCM_DIR"
    sudo install -m 644 "$SCRIPT_DIR/alsa-ucm-conf/ucm2/conf.d/thinkpad-micmute/thinkpad-micmute.conf" "$UCM_DIR/"
    sudo install -m 644 "$SCRIPT_DIR/alsa-ucm-conf/ucm2/conf.d/thinkpad-micmute/MicMute.conf" "$UCM_DIR/"
    
    echo "Installed UCM configuration to $UCM_DIR"
    
    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger -s leds
    sudo systemd-tmpfiles --create /etc/tmpfiles.d/micmute-led.conf
    
    # Add user to required groups
    sudo usermod -aG video,input "$USER" || true
    
    # Try to load snd_ctl_led module (for UCM support)
    if ! lsmod | grep -q "^snd_ctl_led"; then
        echo "Loading snd_ctl_led kernel module..."
        sudo modprobe snd_ctl_led 2>/dev/null || {
            echo "Note: Could not load snd_ctl_led module. UCM LED control may not work." >&2
            echo "      Ensure your kernel has CONFIG_SND_CTL_LED enabled." >&2
        }
    fi
else
    echo "sudo not available; skipping /etc changes and group updates." >&2
    echo "You may need to manually set up permissions for the LED sysfs node." >&2
fi

echo ""
echo "Enabling user service..."

# Enable service
systemctl --user daemon-reload
systemctl --user enable --now micmute-led-sync.service

echo ""
cat <<'MSG'
=== Installation Complete ===

Configuration:
  User config: ~/.config/micmute-led/config
  System config: /etc/micmute-led.conf

LED Modes (set in config):
  ucm        - LED follows only internal mic (ALSA best practice)
  hybrid     - UCM for internal, script for USB mics (default)
  userspace  - LED follows any mic (legacy behavior)

Important:
  - If you were just added to groups (video/input), log out and back in.
  - UCM configuration provides best-practice LED control for internal mics.
  - USB/Bluetooth mics use userspace fallback (if LED_MODE=hybrid).

Service status:
  systemctl --user status micmute-led-sync.service

To use UCM-only mode (most secure):
  echo 'LED_MODE="ucm"' >> ~/.config/micmute-led/config
  systemctl --user restart micmute-led-sync.service
MSG
