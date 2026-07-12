# Pebble Round 2 — day-one checklist

What to do when the Round 2 (platform `gabbro`, 260x260 round color e-paper,
touch + 4 buttons) arrives. Prep status as of 2026-07-12 is at the bottom —
the watchfaces themselves are already written gabbro-ready, so most of this
is SDK plumbing.

## 0. Stock setup first

1. Pair the watch with the Pebble mobile app and let it install the latest
   stock firmware.
2. Record the **board revision**: watch Settings → System → Information.
   Docs and upstream CI use `getafix@evt/dvt/dvt2`; retail may be a new
   revision (`pvt`?). This gates any custom-OS sideloading — see step 3.

## 1. Get a gabbro-capable SDK

```bash
./scripts/check-gabbro-sdk.sh
```

It reports which of the two install paths is open:

- **sdk-core mirror gained gabbro** → re-run `./scripts/setup-sdk.sh`
  (delete `~/.pebble-sdk/SDKs` first to force a fresh install).
- **sdk.repebble.com reachable** → `pebble sdk install latest`. This is
  the expected path on the owner's local machine, where no network policy
  applies — if web sessions stay blocked, do the gabbro builds locally.

If neither is open yet, everything below waits; keep building for `chalk`.

## 2. Port the watchfaces

For each project in `watchfaces/`:

1. Add `"gabbro"` to `targetPlatforms` in `package.json` (keep `"chalk"`).
2. `pebble build` — fix any new-SDK warnings; the SDK version may also have
   moved past 4.4, so watch for API deprecations.
3. Review layout at 260x260. The code derives everything from
   `layer_get_bounds()`, so geometry scales, but two things don't:
   - **System fonts are fixed-size** — LECO 42 that fills a 180px face
     looks small on 260px. Check what larger system fonts (or a
     `PBL_PLATFORM_TYPE_GABBRO`-style define for per-platform font picks)
     the new SDK ships.
   - **Color e-paper** has different contrast characteristics than the
     Time Round's LCD — verify light-on-dark colors on the real watch and
     favor high-contrast pairs.
4. Touch: buttons already drive everything (required — keep it that way).
   Once the SDK's touch API is known, add tap targets as an enhancement,
   never a requirement.
5. Sideload the `.pbw` from `build/` via the phone app and verify on the
   watch.

## 3. Custom OS (optional, later)

Full build + sideload instructions: `os/README.md`. Short version:

1. `./os/clone.sh`, then sync the fork:
   `git fetch upstream && git merge upstream/main && git push origin main`.
2. Confirm upstream has a board target matching the retail revision from
   step 0 (`ls os/PebbleOS/src/fw/board` / `./waf configure --board
   getafix@<rev>`). **Do not sideload a build for a different board
   revision.**
3. Rebase `round2-custom` onto the synced `main`, build, `./waf bundle`,
   sideload the `.pbz` per `os/README.md`.

## Prep status (verified 2026-07-12)

- ✅ `hello-time` and `homehub-watch` build clean for `chalk` and use only
  bounds-derived layouts, system fonts, and `PBL_IF_ROUND_ELSE` — no
  hardcoded 180/90 anywhere. Porting should be a `targetPlatforms` edit.
- ✅ OS fork `Pextar/PebbleOS` `main` is in sync with upstream
  (`0b8bb70e`), and the `round2-custom` branch (GCC 13 build fix) exists.
- ✅ `scripts/check-gabbro-sdk.sh` watches both SDK install paths; the
  SessionStart hook runs it so web sessions announce when gabbro lands.
- ❌ No gabbro SDK installable in web sessions yet (mirror has no gabbro
  platform; sdk.repebble.com blocked) — step 1 is the open gate.
