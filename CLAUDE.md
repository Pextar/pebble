# Pebble Watchfaces & Apps

Personal repo for building watchfaces and apps for a **Pebble Time Round**.

## Target device — IMPORTANT

The owner's watch is a **Pebble Time Round**, platform **`chalk`**:
180x180, **round**, 64 colors, no microphone (unlike the rectangular Pebble
Time/`basalt`).

**Always target `chalk` first** — this overrides the `pebble-watchface`
skill's default of `emery`. Set `"targetPlatforms": ["chalk"]` in each
project's `package.json` (add other platforms only when asked).

Round-display layout notes:
- Use `PBL_IF_ROUND_ELSE(round_value, rect_value)` / `#if PBL_ROUND` for any
  layout that needs to differ from a rectangular face — text and shapes near
  the edges get clipped by the bezel unless inset from the true corners.
- Prefer centered, radially-symmetric layouts (centered text, circular dials)
  over corner-anchored UI elements.
- `GRect`/`layer_get_bounds()` still return a square bounding box (0,0 to
  180,180) on `chalk` — the round clipping happens at render time, so don't
  assume a non-square bounds struct.

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

`pebble install --emulator chalk` does NOT work in Claude Code web sessions:
the patched `qemu-pebble` binary can't be downloaded (network policy). Skip
the QEMU/screenshot steps of the `pebble-watchface` skill here — a successful
`pebble build` plus code review is the verification bar. The `.pbw` in
`build/` is the deliverable; the owner installs it via the Pebble phone app
(sideload) or `pebble install --phone <ip>` on their local network.

## SDK quirks (already handled by setup-sdk.sh)

- SDK core is 4.4 (a Python3-compatible SDK 4.3). No `gabbro`/`flint`
  platforms, but all classic platforms including `chalk` work.
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
