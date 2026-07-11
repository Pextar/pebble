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
- Selecting a row on the watch sends `TOGGLE_TYPE`/`TOGGLE_ID`; the phone
  calls `POST /api/sockets/{id}/toggle` or `POST /api/groups/{id}/toggle`
  and then re-syncs.
- A one-line status banner above the menu shows sync/connection state
  (`Syncing...`, `Connected`, `Error: ...`).

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

## Known limitations (v1)

- Scenes, schedules, and timers from HomeHub aren't exposed — only sockets
  and groups (on/off/toggle).
- No per-group on/off indicator on the watch: HomeHub's `Group` has no
  aggregate state (it's just a named list of socket IDs), so group rows
  show only a name, not On/Off.
- No offline caching — reopening the app with no phone/HomeHub connection
  shows an error status and an empty menu until sync succeeds.
