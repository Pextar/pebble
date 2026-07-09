#!/bin/bash
# Installs the Pebble SDK and ARM toolchain. Idempotent — safe to re-run.
#
# Designed for Claude Code web containers (Ubuntu, root), but works on any
# Debian/Ubuntu machine. In the web containers sdk.repebble.com is not
# reachable, so this script installs from sources that are:
#   - pebble-tool        -> PyPI (via uv or pip)
#   - SDK core 4.4       -> git clone of github.com/coredevices/sdk-core
#   - ARM cross-compiler -> apt (gcc-arm-none-eabi 13.x)
#
# Because the SDK core predates modern GCC/newlib, two small patches are
# applied after install (both no-ops when already applied):
#   1. pebble.h / pebble_worker.h: typedef `time_t` as `long` when newlib
#      hasn't declared it (the SDK compiles with -D_TIME_H_, which suppresses
#      newlib's time.h; the original Pebble toolchain declared time_t
#      elsewhere, modern newlib does not).
#   2. waf CFLAGS: add -fno-builtin and -Wno-builtin-macro-redefined so
#      GCC 13 accepts the SDK's own strftime() prototype and its per-file
#      -D__FILE_NAME__ defines under -Werror.
set -euo pipefail

SDK_VERSION="4.4"
PEBBLE_SDK_DIR="${HOME}/.local/share/pebble-sdk"
SDK_PATH="${PEBBLE_SDK_DIR}/SDKs/${SDK_VERSION}"
SDK_CORE_REPO="https://github.com/coredevices/sdk-core"

export PATH="${HOME}/.local/bin:${PATH}"

log() { echo "[setup-sdk] $*"; }

# --- 1. pebble-tool ---------------------------------------------------------
if ! command -v pebble >/dev/null 2>&1; then
  log "Installing pebble-tool..."
  if command -v uv >/dev/null 2>&1; then
    uv tool install pebble-tool
  else
    pip3 install --user pebble-tool
  fi
else
  log "pebble-tool already installed: $(pebble --version)"
fi

# --- 2. ARM cross-compiler ---------------------------------------------------
if ! command -v arm-none-eabi-gcc >/dev/null 2>&1; then
  log "Installing gcc-arm-none-eabi via apt..."
  SUDO=""
  [ "$(id -u)" -ne 0 ] && SUDO="sudo"
  $SUDO apt-get update -q
  $SUDO apt-get install -y -q gcc-arm-none-eabi libnewlib-arm-none-eabi
else
  log "ARM toolchain already installed: $(arm-none-eabi-gcc --version | head -1)"
fi

# --- 3. SDK core -------------------------------------------------------------
if [ ! -f "${SDK_PATH}/sdk-core/manifest.json" ]; then
  log "Installing SDK core ${SDK_VERSION} from ${SDK_CORE_REPO}..."
  TMP_CLONE="$(mktemp -d)"
  trap 'rm -rf "${TMP_CLONE}"' EXIT
  git clone --depth 1 "${SDK_CORE_REPO}" "${TMP_CLONE}/sdk-core-repo"
  mkdir -p "${SDK_PATH}"
  cp -r "${TMP_CLONE}/sdk-core-repo/sdk-core" "${SDK_PATH}/sdk-core"

  log "Creating SDK virtualenv..."
  python3 -m venv "${SDK_PATH}/.venv"
  "${SDK_PATH}/.venv/bin/python" -m pip install -q -r "${SDK_PATH}/sdk-core/requirements.txt"

  log "Installing SDK JS dependencies..."
  mkdir -p "${SDK_PATH}/node_modules"
  cp "${SDK_PATH}/sdk-core/package.json" "${SDK_PATH}/package.json"
  (cd "${SDK_PATH}" && npm install --silent)
else
  log "SDK core ${SDK_VERSION} already installed."
fi

# --- 4. Patch SDK headers for modern newlib (idempotent) ----------------------
for f in "${SDK_PATH}"/sdk-core/pebble/*/include/pebble.h \
         "${SDK_PATH}"/sdk-core/pebble/*/include/pebble_worker.h; do
  [ -f "$f" ] || continue
  if ! grep -q "_TIME_T_DECLARED" "$f"; then
    log "Patching time_t into $(basename "$(dirname "$(dirname "$f")")")/$(basename "$f")"
    sed -i 's|^#include <time.h>$|#include <time.h>\n\n#if !defined(__time_t_defined) \&\& !defined(_TIME_T_DECLARED)\ntypedef long time_t;\n#define __time_t_defined\n#define _TIME_T_DECLARED\n#endif|' "$f"
  fi
done

# --- 5. Patch waf CFLAGS for GCC 13 (idempotent) ------------------------------
for f in "${SDK_PATH}"/sdk-core/pebble/.waf3-*/waflib/extras/pebble_sdk_gcc.py; do
  [ -f "$f" ] || continue
  if ! grep -q "fno-builtin" "$f"; then
    log "Patching CFLAGS in $(basename "$f")"
    sed -i "s|'-ffunction-sections','-fdata-sections'|'-ffunction-sections','-fdata-sections','-fno-builtin','-Wno-builtin-macro-redefined'|" "$f"
    rm -rf "$(dirname "$f")/__pycache__" "${f%.py}"*.pyc
  fi
done

# --- 6. Activate -------------------------------------------------------------
pebble sdk activate "${SDK_VERSION}" >/dev/null 2>&1 || true
log "Active SDK: $(pebble sdk list 2>/dev/null | grep active || echo 'unknown')"
log "Done. Build a project with: pebble build"
