# micmute-led-sync

Syncs ThinkPad mic-mute LED with microphone mute state on Linux.

This implementation follows **ALSA UCM best practices** (Case 1) while providing flexible fallback modes for USB/Bluetooth microphone support.

## Overview

The ALSA UCM documentation recommends that microphone LEDs respond **only to internal (built-in) resources** for security and predictable behavior. USB/Bluetooth microphones are considered external devices.

This project implements a **hybrid approach**:
- **UCM** handles internal microphone LED (best practice)
- **Userspace script** provides fallback for USB/Bluetooth mics

## LED Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| `ucm` | LED only follows internal mic | Maximum security, best practice compliance |
| `hybrid` | UCM for internal, script for USB | Balance of security and functionality (default) |
| `userspace` | LED follows any default source | Legacy behavior, maximum compatibility |

## Install

```bash
./install.sh
```

The installer will:
1. Install the userspace sync script
2. Install UCM configuration for internal microphone support
3. Set up udev rules for LED permissions
4. Enable the user systemd service
5. Add you to required groups (`video`, `input`)

**Note:** If you were added to groups, log out and back in for changes to take effect.

## Configuration

Edit `~/.config/micmute-led/config` (created on first install):

```bash
# LED behavior mode
LED_MODE="hybrid"  # Options: ucm, hybrid, userspace

# Path to micmute LED
LED_PATH="/sys/class/leds/platform::micmute/brightness"

# Input device for micmute key
INPUT_DEVICE="/dev/input/by-path/platform-thinkpad_acpi-event"
```

### Mode Selection

**UCM Mode (Recommended)**
```bash
LED_MODE="ucm"
```
- LED follows only the internal microphone mute state
- USB/Bluetooth mics do not affect the LED
- Most secure, follows ALSA best practices
- Requires `snd_ctl_led` kernel module

**Hybrid Mode (Default)**
```bash
LED_MODE="hybrid"
```
- UCM handles internal microphone
- Script provides fallback for USB/Bluetooth mics
- Good balance of security and functionality

**Userspace Mode**
```bash
LED_MODE="userspace"
```
- Legacy behavior from v1.x
- LED follows PipeWire/PulseAudio default source
- Works with any microphone
- Less secure (userspace controls LED directly)

## Uninstall

```bash
./uninstall.sh
```

## Service Status

```bash
systemctl --user status micmute-led-sync.service
```

## Requirements

- `libinput` or `libinput-tools` (for key event listening)
- `alsa-utils` (for UCM support, optional but recommended)
- Kernel with `CONFIG_SND_CTL_LED` enabled (for UCM mode)
- PipeWire or PulseAudio

## ALSA UCM Best Practices

This project implements the recommendations from the ALSA UCM documentation:

> **Result:** For safety, simplicity and understable behaviour, only Case 1 should be followed - LEDs should respond only to the internal (build-in) speaker output and internal (build-in) microphone input in UCM.

### Why Case 1?

1. **Security**: Userspace sound servers should not directly control LEDs
2. **Predictability**: LED behavior is consistent regardless of audio routing
3. **Simplicity**: Kernel module handles LED, no polling or event handling needed

### Trade-offs

| Approach | Security | USB Mic Support | Implementation |
|----------|----------|-----------------|----------------|
| Case 1 (UCM only) | ⭐⭐⭐ | ❌ | Kernel module |
| Hybrid (this project) | ⭐⭐☆ | ✅ | UCM + userspace fallback |
| Case 2 (userspace only) | ⭐☆☆ | ✅ | Userspace script |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│           Microphone Source                             │
└─────────────┬───────────────────────────────────────────┘
              │
    ┌─────────┴──────────┐
    │                    │
Internal Mic?         USB/External Mic?
    │                    │
    ▼                    ▼
┌──────────┐      ┌──────────────────┐
│   UCM    │      │  Userspace       │
│(snd_ctl  │      │  Script Fallback │
│  _led)   │      │                  │
└────┬─────┘      └────────┬─────────┘
     │                      │
     └──────────┬───────────┘
                ▼
          ┌──────────┐
          │   LED    │
          └──────────┘
```

## Troubleshooting

### LED doesn't work with USB microphone in hybrid mode

This is expected behavior per ALSA best practices. To enable USB mic support:

```bash
# Option 1: Switch to userspace mode
LED_MODE="userspace"

# Option 2: Use UCM mode and rely on your conferencing app
# The LED will show internal mic state, but your USB mic mute works independently
```

### UCM mode not working

1. Check if `snd_ctl_led` module is loaded:
   ```bash
   lsmod | grep snd_ctl_led
   ```

2. If not loaded, load it manually:
   ```bash
   sudo modprobe snd_ctl_led
   ```

3. Verify UCM files are installed:
   ```bash
   ls /usr/share/alsa/ucm2/conf.d/thinkpad-micmute/
   ```

### Permission denied on LED

Ensure the udev rules are applied:
```bash
sudo udevadm trigger -s leds
```

## License

MIT
