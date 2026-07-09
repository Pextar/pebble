# Pebble Watchfaces & Apps

Personal repo for building watchfaces and apps for a **Pebble Time** (Bluetooth
name "Pebble Time LE 05A9").

## Target device — IMPORTANT

The owner's watch is a **Pebble Time**, platform **`basalt`**:
144x168, rectangular, 64 colors, microphone.

**Always target `basalt` first** — this overrides the `pebble-watchface`
skill's default of `emery`. Set `"targetPlatforms": ["basalt"]` in each
project's `package.json` (add other platforms only when asked).

## Environment setup

A SessionStart hook (`.claude/hooks/session-start.sh`) runs
`scripts/setup-sdk.sh` automatically in Claude Code web sessions. It installs
pebble-tool (PyPI), SDK core 4.4 (git mirror `coredevices/sdk-core`), and
`gcc-arm-none-eabi` (apt), then patches the SDK headers for modern GCC/newlib.
Run it manually if `pebble build` complains about a missing SDK:

```bash
./scripts/setup-sdk.sh
export PATH="$HOME/.local/bin:$PATH"   # pebble lives in ~/.local/bin
```

Why not `pebble sdk install latest`? The web container's network policy blocks
`sdk.repebble.com`; the script installs equivalent pieces from PyPI, GitHub
(git protocol), and apt instead.

## Building

```bash
cd <project-dir>
pebble build          # produces build/<project>.pbw
```

Each watchface/app lives in its own top-level directory (see `hello-time/`).

## Emulator limitation in this environment

`pebble install --emulator basalt` does NOT work in Claude Code web sessions:
the patched `qemu-pebble` binary can't be downloaded (network policy). Skip
the QEMU/screenshot steps of the `pebble-watchface` skill here — a successful
`pebble build` plus code review is the verification bar. The `.pbw` in
`build/` is the deliverable; the owner installs it via the Pebble phone app
(sideload) or `pebble install --phone <ip>` on their local network.

## SDK quirks (already handled by setup-sdk.sh)

- SDK core is 4.4 (a Python3-compatible SDK 4.3). No `gabbro`/`flint`
  platforms, but all classic platforms including `basalt` work.
- Headers are patched to typedef `time_t` as `long` (32-bit, matching the
  watch ABI) because the SDK compiles with `-D_TIME_H_` and modern newlib
  doesn't pre-declare `time_t`.
- CFLAGS include `-fno-builtin -Wno-builtin-macro-redefined` for GCC 13
  compatibility. Don't remove them.

## Watchface conventions

- `MINUTE_UNIT` tick subscriptions (battery); `SECOND_UNIT` only on request.
- No floating point — use `sin_lookup()`/`cos_lookup()`.
- Use `layer_get_bounds()` instead of hardcoded sizes.
- Destroy everything created in `window_load` in `window_unload`.
