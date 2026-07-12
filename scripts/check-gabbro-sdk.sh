#!/bin/bash
# Answers: "can we build for gabbro (Pebble Round 2) in this environment yet?"
#
# Two things gate that:
#   1. The sdk-core git mirror (coredevices/sdk-core) gaining a gabbro
#      platform directory — then scripts/setup-sdk.sh picks it up as-is.
#   2. The network policy unblocking sdk.repebble.com — then the official
#      SDK works via `pebble sdk install latest`.
#
# Exits 0 with "GABBRO AVAILABLE" if either path opens up; exits 0 with a
# "still unavailable" summary otherwise. Exits nonzero only on errors.
set -euo pipefail

MIRROR=https://github.com/coredevices/sdk-core
# Mirror HEAD the last time this check came back negative. When a check
# finds new commits but still no gabbro, update this hash to quiet the
# deep check until the mirror moves again.
KNOWN_NO_GABBRO_HEAD=db994155e288b34ae60323544b3fc40ba05e4bb9

available=false

head=$(git ls-remote "$MIRROR" HEAD | cut -f1)
if [ "$head" = "$KNOWN_NO_GABBRO_HEAD" ]; then
  echo "sdk-core mirror unchanged (${head:0:10}) — still no gabbro platform."
else
  echo "sdk-core mirror has new commits (${head:0:10}) — checking platforms..."
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  git clone --quiet --depth 1 "$MIRROR" "$tmp/sdk-core"
  if [ -d "$tmp/sdk-core/sdk-core/pebble/gabbro" ]; then
    echo "GABBRO AVAILABLE in sdk-core! Re-run scripts/setup-sdk.sh, then follow ROUND2.md."
    available=true
  else
    platforms=$(ls "$tmp/sdk-core/sdk-core/pebble" | grep -v -e '^common$' -e '^waf' | tr '\n' ' ')
    echo "Still no gabbro. Platforms: $platforms"
    echo "Update KNOWN_NO_GABBRO_HEAD in $0 to $head to skip this deep check next time."
  fi
fi

code=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' https://sdk.repebble.com/ || true)
case "$code" in
  2*|3*)
    echo "GABBRO AVAILABLE: sdk.repebble.com is reachable — try 'pebble sdk install latest' for the official Round 2 SDK."
    available=true
    ;;
  *)
    echo "sdk.repebble.com still blocked by network policy (HTTP ${code:-none})."
    ;;
esac

if ! $available; then
  echo "No gabbro-capable SDK installable here yet. Keep writing gabbro-ready chalk code (see CLAUDE.md)."
fi
