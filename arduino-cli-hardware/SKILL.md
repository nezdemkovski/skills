---
name: arduino-cli-hardware
description: Build, inspect, refactor, compile, and flash Arduino/ESP32 firmware projects using arduino-cli or project Makefiles. Use when working on Arduino sketches, ESP32/ESP32-S2/ESP32-S3 hardware, USB HID mouse/keyboard firmware, embedded web dashboards/assets, serial ports, board FQBNs, compile/upload flows, or safe embedded iteration patterns.
---

# Arduino CLI Hardware

Use this skill for Arduino/ESP32 firmware projects that build or flash through `arduino-cli`, especially sketches with project-local `Makefile` wrappers.

## Core Workflow

1. Read the project files before changing anything: `README.md`, `Makefile`, `*.ino`, local `.h/.cpp` modules, and any board notes.
2. Prefer the project wrapper (`make compile`, `make upload PORT=...`) over inventing raw `arduino-cli` commands.
3. Compile before upload. Do not flash a build that has not compiled cleanly.
4. Discover the current port with `arduino-cli board list` and, on macOS, check `/dev/cu.*` devices when needed.
5. When flashing ESP32-S2/S3 USB HID firmware, distinguish the upload transport from the native USB HID port.
6. After upload, report the chip, port, and whether flash verification passed.

## Safety Rules

- Treat attached hardware as stateful: ports can disappear, re-enumerate, or wedge after reset.
- Never assume a stale port path. Re-check if upload fails or the user re-plugs the board.
- For HID devices, avoid unsafe clicks by default. Prefer movement-only or modifier-only activity pulses.
- Avoid `Shift`, `Alt`, and `Command/Win` activity pulses unless explicitly requested; they can trigger OS shortcuts. Prefer short `Left Ctrl` down/up for low-risk activity.
- Keep HID movement, keyboard activity, button handling, and display rendering separated into modules.
- Do not put display rendering inside high-frequency HID send loops.
- Prefer non-blocking `millis()` state machines over `delay()` in reusable modules.

## References

Read `references/hardware-patterns.md` when changing firmware architecture, USB HID behavior, button semantics, OLED UI, embedded dashboards, keyboard/mouse activity, or upload troubleshooting.
