# hello-time

Minimal starter watchface for the Pebble Time (`basalt`): big time in the
center (LECO 42), date underneath, black background. Updates once per minute.

## Building & installing

```sh
pebble build                    # -> build/hello-time.pbw
pebble install --phone <ip>     # install via the Pebble phone app's developer connection
```

Or sideload `build/hello-time.pbw` directly with the Pebble phone app.

## Project layout

```
src/c/hello-time.c   Watchface source
package.json         Project metadata (UUID, platforms: basalt)
wscript              Build rules — usually no need to edit
```
