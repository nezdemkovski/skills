# Hardware Patterns

## Project Discovery

- Start with `README.md` and `Makefile`; they usually document FQBN, upload port, and hardware caveats.
- Use `rg --files` for project inventory.
- Use `arduino-cli board list` before upload. On macOS, likely upload ports are `/dev/cu.usbserial-*`, `/dev/cu.usbmodem*`, or board-specific names.
- If `stty -f /dev/cu... 115200` fails with `tcsetattr: Invalid argument`, the serial driver is wedged. Ask for a physical replug or reset; retry after the port re-enumerates.

## Compile and Upload

- Prefer `make compile` and `make upload PORT=/dev/cu...` when a Makefile exists.
- Compile first; upload only after a clean build.
- If the upload port changes after reset, use the new `New upload port:` value or re-run `arduino-cli board list`.
- Report flash verification, chip type, and port in the final response.

## ESP32-S2/S3 USB HID

- Native USB HID and USB-UART upload are different paths. A board may upload over CP210x/CH340 while HID only appears on native USB/OTG.
- For ESP32-S3 HID builds, preserve the project's FQBN USB settings. Do not switch USB modes casually.
- Composite HID devices can expose mouse and keyboard together: initialize both HID devices before `USB.begin()`.

## Firmware Architecture

Keep responsibilities separated:

- `MouseMover`: movement profiles, scheduling, random walk generation, HID mouse reports.
- `KeyboardActivity`: modifier-only keyboard pulses, scheduling, release guarantees.
- `Display`: consume status DTOs and render only. It should not know HID internals or button logic.
- `.ino`: wiring, setup, button semantics, and orchestration.

Prefer status/update DTOs over cross-module reads:

```cpp
MoveUpdate moveUpdate = mover.update(millis());
KeyboardActivityUpdate keyUpdate = keyboardActivity.update(millis());
screen.render(mover.status(now), keyboardActivity.status(now), now);
```

## Non-Blocking Embedded Style

- Avoid blocking module methods that contain long `delay()` loops.
- Use `update(now)` state machines that do a small amount of work per `loop()` pass.
- Use overflow-safe `millis()` checks:

```cpp
bool timeReached(unsigned long now, unsigned long deadline) {
  return (long)(now - deadline) >= 0;
}
```

- If a module presses a keyboard modifier, always implement release logic that runs even when the feature is disabled.

## Button Semantics

Do not fire single-click actions immediately on release if double-click exists.

Pattern:

- On first short release, store `pendingSingleClick` and timestamp.
- If a second short release arrives within the double-click window, cancel the pending single and run double-click action.
- If the window expires, run the single-click action.
- Long press should cancel any pending single-click.

## Safer Activity Signals

- Mouse movement is safer than clicking.
- Modifier-only keyboard pulses are safer than mouse clicks but still real input.
- Prefer short `KEY_LEFT_CTRL` down/up pulses with randomized intervals.
- Avoid repeated Shift due to Sticky Keys. Avoid Command/Win because it opens OS UI. Avoid Alt because it can focus menus.

## OLED/UI Patterns

- Keep OLED code in a display module that accepts plain status values.
- Do not let display code send HID events.
- Fast OLED refresh over I2C can slow the loop; use 400 kHz I2C when stable, and throttle active rendering.
- Keep small monochrome UI legible: remove redundant counters, avoid dense grids/lines, and prefer one clear animation.

## Web Dashboards and Embedded Assets

Use this pattern for projects like `esp32s3_recon_console`, where the Arduino sketch is also a small web appliance.

Typical stack:

- Firmware: Arduino ESP32-S3 sketch, `WebServer`, `WebSocketsServer`, `LittleFS`, mDNS, WiFi/AP+STA, and small C++ service modules.
- Frontend: `web/` app using React, TypeScript, Vite, Tailwind v4, and typed API helpers.
- Built assets: Vite writes directly to `data/` (`outDir: '../data'`, `assetsDir: 'assets'`), which becomes the LittleFS image.
- Build orchestration: project `Makefile` owns `web-build`, `typecheck`, host `test-unit`, `compile`, `upload`, `fs`, `fs-upload`, `flash`, and live `smoke`.

Work with this layout as two coordinated products:

- Edit dashboard source in `web/src/*`, not generated files in `data/`.
- Treat `data/` as build output unless the project has no `web/` source.
- Use `package.json` scripts through Makefile targets when present: `make web-build`, `make typecheck`, `make test`, `make compile`.
- For a complete device update, firmware upload is not enough. Use the project workflow that also builds and uploads LittleFS: usually `make flash` or `make fs-upload` after `make web-build`.
- Keep `web/vite.config.ts` aligned with ESP serving: `root: 'web'`, `base: '/'`, `outDir: '../data'`, and dev-server proxy from `/api` to the device hostname.
- Do not introduce a separate web framework/server unless the project already has one; the ESP serves static assets and JSON/WebSocket endpoints.

Firmware/API contracts:

- Treat `server.on("/api/...")` routes, response JSON shapes, and WebSocket payloads as contracts with `web/src/api.ts` and hooks.
- When changing firmware JSON, update TypeScript response types in the same change.
- Keep route mutations small and explicit: handlers should call service/core functions rather than burying business logic in lambdas.
- Preserve the LittleFS missing-UI fallback so a bad data upload is obvious in the browser.
- Keep WebSocket updates throttled; do not broadcast on every tight loop iteration.

Testing and validation order:

1. Run host C++ tests when core/service logic changes (`make test` or `make test-unit`).
2. Run frontend typecheck/build when `web/` or API types change (`make typecheck`, `make web-build`).
3. Run firmware compile (`make compile`).
4. Upload firmware and filesystem with the project target (`make flash`) when the user wants the device updated.
5. For live devices, use the project smoke target (`make smoke`) or inspect the dashboard/API in a browser after upload.

Dashboard design expectations:

- Build the actual operator console, not a marketing page.
- Prefer dense, readable, workbench-style UI: status panels, graphs, controls, logs, and live indicators.
- Keep dependencies intentional; flash size, bundle size, heap, and WiFi transfer time matter.
- Use typed API wrappers and domain-specific hooks rather than scattering raw `fetch()` calls through components.
