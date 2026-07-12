# Pebble Watchfaces & Apps

Personal repo for building watchfaces and apps for the owner's round
Pebbles: a **Pebble Time Round** today, a **Pebble Round 2** on order.

## Target devices — IMPORTANT

| Device | Platform | Display | Status |
|---|---|---|---|
| Pebble Time Round | `chalk` | 180x180 round, 64-color, buttons only, **no microphone** | owned — primary target |
| Pebble Round 2 (2026) | `gabbro` | 260x260 round, color e-paper, touch + 4 buttons | on order (ships mid-2026) |

**Always target `chalk` first** — this overrides the `pebble-watchface`
skill's default of `emery`. Set `"targetPlatforms": ["chalk"]` in each
project's `package.json` (add other platforms only when asked).

**`gabbro` cannot be built in this environment yet**: the SDK core 4.4
mirror we install from (`coredevices/sdk-core`, see below) has no `gabbro`
platform, and the official Round 2 SDK is only distributed via
`sdk.repebble.com`, which the web container's network policy blocks. Do NOT
add `"gabbro"` to `targetPlatforms` until a gabbro-capable SDK is
installable here — `scripts/check-gabbro-sdk.sh` checks both install paths
(the SessionStart hook runs it, so watch its output at session start). When
it reports gabbro available, follow `ROUND2.md` (the day-one porting
checklist). Until then, **write gabbro-ready code**:

- Derive every position from `layer_get_bounds()` — never hardcode 180/90.
  Both devices are round, so `PBL_IF_ROUND_ELSE`/`#if PBL_ROUND` picks the
  same branch on both; the only difference that matters is resolution.
- Express sizes as fractions/offsets of `bounds.size`, and prefer system
  fonts + `graphics_*` drawing (scale naturally) over pixel-tuned bitmaps.
- Gabbro adds a touchscreen; don't design UI that *requires* touch — buttons
  must remain sufficient (that also keeps chalk fully usable).

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

## Repo layout

- `watchfaces/` — one directory per watchface/app (see `watchfaces/hello-time/`).
  New projects go here.
- `os/` — pointer to the PebbleOS fork. The firmware source is NOT vendored
  in this repo: it lives in its own GitHub fork (of `coredevices/PebbleOS`)
  and is cloned on demand into `os/PebbleOS/` (gitignored) via `os/clone.sh`.
  Commit OS work in the fork's repo, never here; small not-yet-landed patches
  can be tracked in `os/patches/`. See `os/README.md`.
- `samples/`, `tutorials/` — upstream reference material from the
  pebble-watchface skill; don't put new projects there.

## Building

```bash
cd watchfaces/<project-dir>
pebble build          # produces build/<project>.pbw
```

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
