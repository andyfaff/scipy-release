#!/usr/bin/env bash
#
# Regenerate the `uv.lock` file in this repository.
#
# The lock file pins every build and test dependency used by the wheel and sdist builds.
# It is generated from scipy's `pyproject.toml`, so it has to be regenerated whenever that
# changes - including when scipy's version string is bumped, since `uv.lock` records it.
# The `check_lock` CI job fails when the two drift apart.
#
# Expects a scipy checkout at ../scipy, at the commit this branch builds
# (`SOURCE_REF_TO_BUILD` in .github/workflows/wheels.yml). Override with $SCIPY_SRC.
#
# Usage:
#
#   tools/update_lock.sh                            # sync the lock to pyproject.toml
#   tools/update_lock.sh --upgrade                  # ... and bump every pin to latest
#   SCIPY_SRC=/path/to/scipy tools/update_lock.sh
#
# Review the resulting diff before committing it. `uv.lock` covers all of scipy's
# dependency groups, so most of the diff has no bearing on the wheels; the pins that do
# get installed are printed at the end.
set -euo pipefail

# Keep in sync with the --exclude-newer in the check_lock job in wheels.yml. uv records
# this window in the lock file, and `uv lock --check` fails unless given the same value.
EXCLUDE_NEWER="7 days"

# Older versions of uv write a different lock file format and don't accept a relative
# --exclude-newer. There's no upper bound: CI pins an exact UV_VERSION, all that matters
# here is producing a lock file CI accepts.
MIN_UV_VERSION="0.12.5"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCIPY_SRC="${SCIPY_SRC:-$REPO_DIR/../scipy}"

UPGRADE=()
case "${1:-}" in
    "") ;;
    --upgrade) UPGRADE=(--upgrade) ;;
    *) echo "usage: $0 [--upgrade]" >&2; exit 2 ;;
esac

if ! command -v uv > /dev/null; then
    echo "error: uv is not installed - see https://docs.astral.sh/uv/getting-started/" >&2
    exit 1
fi

version_number() { printf '%03d%03d%03d' $(echo "${1%%[-+]*}" | tr '.' ' '); }
uv_version=$(uv --version | awk '{print $2}')
if (( 10#$(version_number "$uv_version") < 10#$(version_number "$MIN_UV_VERSION") )); then
    echo "error: uv $uv_version is too old, need $MIN_UV_VERSION or newer" >&2
    exit 1
fi

if [[ ! -f "$SCIPY_SRC/pyproject.toml" ]]; then
    echo "error: no scipy checkout at $SCIPY_SRC" >&2
    echo "       clone scipy/scipy there, or point \$SCIPY_SRC at an existing checkout" >&2
    exit 1
fi
SCIPY_SRC="$(cd "$SCIPY_SRC" && pwd)"

# Start from the existing lock file, so that only what has to change, changes.
cp "$REPO_DIR/uv.lock" "$SCIPY_SRC/uv.lock"

cd "$SCIPY_SRC"
uv lock --exclude-newer "$EXCLUDE_NEWER" ${UPGRADE[@]+"${UPGRADE[@]}"}
uv lock --check --exclude-newer "$EXCLUDE_NEWER"
cp "$SCIPY_SRC/uv.lock" "$REPO_DIR/uv.lock"

echo
echo "Updated $REPO_DIR/uv.lock. Effective build and test pins:"
uv export --frozen --no-hashes --no-emit-project --no-default-groups \
    --group build --group openblas32 --group test-core
