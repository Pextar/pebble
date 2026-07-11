# homehub-watch

Pebble watchapp (`chalk` / Pebble Time Round) that controls RF sockets and
groups from [HomeHub](https://github.com/pextar/rf-socket-controller)
directly from the watch.

## Architecture

Pebble watches have no Wi-Fi, so the watch app can't talk to HomeHub
directly:

```
Watch (C, MenuLayer) <--AppMessage/BT--> Phone (PebbleKit JS) <--HTTPS--> HomeHub API (Pi)
```

- The watch shows a two-section menu: **Sockets** and **Groups**.
- `src/pkjs/index.js` runs in the Pebble mobile app on the phone. On launch
  (and whenever the watch asks) it fetches `GET /api/sockets` and
  `GET /api/groups` from HomeHub and streams the results to the watch as a
  series of `ITEM_*` AppMessages bracketed by `SYNC_START`/`SYNC_DONE`.
- Selecting a row on the watch sends `TOGGLE_TYPE`/`TOGGLE_ID`. For a
  socket, the phone POSTs the toggle and patches just that row from the
  response; for a group (which changes many sockets) it runs a full
  re-sync.
- A one-line status banner above the menu shows sync/connection state
  (`Syncing...`, `Connected`, `Timeout`, `HTTP 401`, ...). Statuses are
  kept short so they fit the narrow chord at the top of the round display.
- Read-only HomeHub devices (sensors) are filtered out on the phone side —
  the watch only lists things it can actually switch.

## Configuration

Host URL and HTTP Basic Auth credentials are set from the watch app's
settings screen in the Pebble mobile app (gear icon next to the app in the
Pebble app's "My Pebble" list). That opens a small local settings page
(`showConfiguration` → an in-memory `data:` URL, no external hosting
needed) asking for:

- **Host URL** — wherever HomeHub is reachable from your phone. If you're
  using Tailscale for remote access (see the HomeHub repo's `INSTALL.md`),
  this is the Pi's Tailscale address, e.g. `http://100.x.x.x:8080`.
- **Username** / **Password** — an admin profile on HomeHub (HTTP Basic
  Auth; HomeHub's login-code auth is for the SPA session flow, not
  scripted clients).

Settings are stored in PebbleKit JS `localStorage` on the phone, not on the
watch.

## Building & installing

```sh
pebble build                    # -> build/homehub-watch.pbw
pebble install --phone <ip>     # install via the Pebble phone app's developer connection
```

Or sideload `build/homehub-watch.pbw` directly with the Pebble phone app,
then configure it from the app's settings screen as described above.

## Project layout

```
src/c/homehub.c      Watch app: MenuLayer UI, AppMessage handling
src/pkjs/index.js     Phone-side: HomeHub API calls, settings page, sync protocol
package.json          Project metadata (UUID, platform: chalk, messageKeys)
wscript               Build rules — usually no need to edit
```

## Pebble Round 2 (`gabbro`)

The layout is fully bounds-driven (MenuLayer + a status banner sized from
`layer_get_bounds()`), so when a gabbro-capable SDK becomes installable in
this environment, supporting the Round 2 should be just adding `"gabbro"`
to `targetPlatforms` in `package.json` and rebuilding. See the repo
`CLAUDE.md` for why gabbro can't be built here yet.

## Known limitations (v1)

- Scenes, schedules, and timers from HomeHub aren't exposed — only sockets
  and groups (on/off/toggle).
- No per-group on/off indicator on the watch: HomeHub's `Group` has no
  aggregate state (it's just a named list of socket IDs), so group rows
  show only a name, not On/Off.
- The watch list is capped at 32 items (groups win over sockets when over
  the cap) and names at 31 chars; the status banner says `List cut at 32`
  when truncation happens.
- Sync streams one item per AppMessage (~34 BLE round trips for a full
  list). Fine at household scale; batching several items per message is
  the obvious optimization if it ever feels slow.
- No offline caching — reopening the app with no phone/HomeHub connection
  shows an error status and an empty menu until sync succeeds.
