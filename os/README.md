# PebbleOS fork

This directory is the home for OS-level work, but the firmware source itself
is **not** vendored into this repo. PebbleOS is a large, actively developed
upstream ([coredevices/PebbleOS](https://github.com/coredevices/PebbleOS)),
and keeping our copy as a real GitHub fork preserves upstream syncing
(`git merge upstream/main`) and the ability to send PRs upstream — gabbro
(Pebble Round 2) support lands there. Vendoring it here would also bloat this
repo, which gets cloned fresh in every Claude Code web session.

## Layout

```
os/
├── README.md    # this file
├── clone.sh     # clones the fork into os/PebbleOS/ (gitignored)
├── patches/     # small patches worth tracking here before they land in the fork
└── PebbleOS/    # the actual source, cloned on demand — never committed
```

## Getting the source

The fork exists: https://github.com/Pextar/PebbleOS. Run:

```bash
./os/clone.sh
```

This clones the fork into `os/PebbleOS/` and wires up an `upstream`
remote pointing at coredevices/PebbleOS.

## Which watches current PebbleOS supports — IMPORTANT

Upstream `main` only builds for the 2025/2026 Core Devices watches:

| Board | Watch | Platform |
|---|---|---|
| `asterix` | Pebble 2 Duo | — |
| `obelix@bb2/dvt/pvt` | Pebble Time 2 | — |
| `getafix@evt/dvt/dvt2` | **Pebble Round 2** | `gabbro` |
| `qemu_emery/flint/gabbro` | QEMU only | — |

The original **Pebble Time Round (`spalding`) is NOT supported** on
current `main`: legacy boards were removed after tag `v4.9.171` (the
last spalding-capable release). We target the Round 2 only — custom OS
work happens on the fork's `round2-custom` branch, based on `main`.

## Building for Pebble Round 2 (getafix) in a Claude Code web session

The official PebbleOS-SDK toolchain installer (GitHub release download)
is blocked by the network policy, but the apt `gcc-arm-none-eabi` (13.2)
that `scripts/setup-sdk.sh` installs works, with one caveat handled on
the `round2-custom` branch (a `-Wno-error=maybe-uninitialized` for the
SiFli vendor HAL, which GCC 14 doesn't flag but GCC 13 does).

```bash
sudo apt-get install -y gettext bison flex gperf librsvg2-bin \
    libglib2.0-dev libgtk-3-dev libncurses-dev libfreetype6-dev
cd os/PebbleOS
git submodule update --init --depth 1 --jobs 2
python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt
source .venv/bin/activate
./waf configure --board getafix@dvt2
./waf build          # ~1.5 min
./waf bundle         # → build/normal_getafix_dvt2_<version>_slot0.pbz
```

## Installing a custom build on the watch

No dev kit needed — sideload the `.pbz` over Bluetooth:

1. `./waf bundle` produces `build/normal_getafix_*_slot0.pbz`.
2. Get that file onto the phone paired with the watch.
3. In the Pebble mobile app: **Settings → Show debug options** (enable).
4. Devices tab → tap the watch → **Firmware Update Debug → Sideload FW**
   → pick the `.pbz`.

Recovery: the PRF (recovery firmware) partition is untouched by a
sideload, so a bad build can be recovered by entering recovery mode and
letting the app reinstall stock firmware. Still, wait for the actual
retail Round 2 before sideloading — the retail board revision may differ
from `dvt2`, and stock firmware for it will tell us the right revision
(watch Settings → System → Information, or the upstream board list).

## Keeping the fork in sync

```bash
cd os/PebbleOS
git fetch upstream
git merge upstream/main
git push origin main
```

## Notes

- `os/PebbleOS/` is in `.gitignore` — OS work is committed and pushed in the
  fork's own repo, not here.
- Firmware builds use PebbleOS's own toolchain/build system, not the
  pebble-tool SDK that `scripts/setup-sdk.sh` installs for watchfaces. See
  the PebbleOS README for its build instructions.
