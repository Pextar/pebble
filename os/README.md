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

1. Fork https://github.com/coredevices/PebbleOS on GitHub (once).
   The fork does not exist yet — until it does, `clone.sh` falls back to
   cloning upstream directly.
2. Run:

   ```bash
   ./os/clone.sh
   ```

   This clones the fork into `os/PebbleOS/` and wires up an `upstream`
   remote pointing at coredevices/PebbleOS.

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
