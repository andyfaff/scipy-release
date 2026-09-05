#!/usr/bin/env bash
# Regenerate pyproject.toml and uv.lock from a scipy checkout ($SCIPY_SRC, default
# ../scipy). The cooldown has to match the one in check_lock in wheels.yml.
#   tools/update_lock.sh            # re-sync to scipy's dependency groups
#   tools/update_lock.sh --upgrade  # ... and bump every pin to the latest release
set -euo pipefail

# everything below is relative to the repo root, including the ../scipy default above
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# via a temporary file: a redirect truncates its target before the generator runs, and
# `set -e` does not fire for the left-hand side of an `&&`
uv run --no-project --quiet python tools/sync_dependency_groups.py "${SCIPY_SRC:-../scipy}" \
    > pyproject.toml.tmp
mv pyproject.toml.tmp pyproject.toml
uv lock --exclude-newer "7 days" "$@"
uv lock --check --exclude-newer "7 days"
