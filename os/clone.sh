#!/usr/bin/env bash
# Clone the PebbleOS fork into os/PebbleOS/ (gitignored) and set up the
# upstream remote. Falls back to cloning upstream directly if the fork
# doesn't exist yet.
set -euo pipefail

FORK_URL="https://github.com/Pextar/PebbleOS.git"
UPSTREAM_URL="https://github.com/coredevices/PebbleOS.git"
DEST="$(cd "$(dirname "$0")" && pwd)/PebbleOS"

if [ -d "$DEST/.git" ]; then
  echo "Already cloned at $DEST"
  exit 0
fi

if git ls-remote --exit-code "$FORK_URL" >/dev/null 2>&1; then
  echo "Cloning fork: $FORK_URL"
  git clone "$FORK_URL" "$DEST"
  git -C "$DEST" remote add upstream "$UPSTREAM_URL"
else
  echo "Fork not found ($FORK_URL) — cloning upstream instead."
  echo "Fork https://github.com/coredevices/PebbleOS on GitHub, then re-point 'origin'."
  git clone "$UPSTREAM_URL" "$DEST"
fi

echo "Done. Source is at $DEST"
