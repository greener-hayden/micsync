# micmute-led-sync

Syncs ThinkPad mic-mute LED with microphone mute state on Arch/Linux.

## What it does
- Listens for mic-mute key events via libinput.
- Syncs LED state to the actual mute state (PipeWire/WirePlumber or PulseAudio).
- Applies correct permissions for the LED sysfs node at boot.

## Install
```
./install.sh
```

## Uninstall
```
./uninstall.sh
```

## Notes
- Requires `libinput` (or `libinput-tools` depending on your distro).
- If the installer adds you to `video` or `input`, log out and back in.
- Service status:
```
systemctl --user status micmute-led-sync.service
```
