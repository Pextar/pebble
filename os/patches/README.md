# Pending fork patches — sync to upstream v4.29.0

These patches carry our custom PebbleOS fork commits on top of upstream
release **v4.29.0** (`coredevices/PebbleOS`). They were rebased and
build-verified in a Claude Code web session on 2026-07-20, but **could not be
pushed to the fork from there** — the web container's egress policy only
allows GitHub writes to `pextar/pebble`, not to `Pextar/PebbleOS`. Apply them
from a machine that has push rights to the fork.

## What's here

| Patch | Effect | Size |
|---|---|---|
| `0001-apps-tictoc-...` | tictoc gabbro round face: yellow minute hand, cerulean bob | `watch_model.h`, 4 lines |
| `0002-third_party-hal_sifli-...` | SiFli HAL: `-Wno-error=maybe-uninitialized` for GCC 13 | `wscript_build`, 1 line |

Both are the former `round2-custom` branch commits, replayed onto v4.29.0.
The rebase was **conflict-free** and both patches still produce non-empty
diffs against v4.29.0 (neither became obsolete upstream).

## Verified

- `./waf configure --board getafix@dvt2 && ./waf build` → **succeeds**
  (`pebbleos.elf` links, all memory regions in bounds).
- `./waf bundle` → `normal_getafix_dvt2_v4.29.0-2-g<sha>_slot0.pbz`.

## How to apply (from a machine with fork push access)

Because upstream v4.24.0 → v4.29.0 is linear, advancing the fork's `main`
from its current v4.24.0 is a **fast-forward + 2 patches** — no force-push
needed against the remote's current `main`:

```bash
cd os/PebbleOS
git fetch upstream --tags
git checkout main
git reset --hard v4.29.0          # main was pinned at v4.24.0; discard any
                                  # local throwaway merge first if present
git am ../patches/0001-*.patch ../patches/0002-*.patch
git push origin main              # fast-forward from remote's v4.24.0
git push origin --delete round2-custom   # commits now live on main
```

If your local `main` already carries an unpushed throwaway merge of
`round2-custom`, the `git reset --hard v4.29.0` above discards it — that's
intended; these patches are the clean replacement.

## Note on the SiFli flag (patch 0002)

`-Wno-error=maybe-uninitialized` only downgrades a warning to non-fatal, so
it's harmless even if GCC no longer flags that path. It's worth trying a
build *without* it on a future sync; if the warning is gone, drop the patch.
As of v4.29.0 the build is green with it applied.
