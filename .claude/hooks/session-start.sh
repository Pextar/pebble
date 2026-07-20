#!/bin/bash
set -euo pipefail

# Only needed in remote (Claude Code on the web) containers; local machines
# are expected to have the Pebble SDK installed already.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

"${CLAUDE_PROJECT_DIR}/scripts/setup-sdk.sh"

# Surface when a gabbro (Pebble Round 2) SDK becomes installable; never
# block the session on it.
"${CLAUDE_PROJECT_DIR}/scripts/check-gabbro-sdk.sh" || true

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${CLAUDE_ENV_FILE}"
fi
