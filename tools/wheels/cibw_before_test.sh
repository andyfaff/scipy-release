set -xe

PROJECT_DIR="${1:-$PWD}"
SCIPY_SRC_DIR="${1:-$PWD}/scipy-src"

# install test dependencies via uv
# uv.lock file needs to be in the same location as pyproject.toml
cp uv.lock $SCIPY_SRC_DIR
PYTHON_EXE="$(python -c 'import sys; print(sys.executable)')"
uv export --project "$SCIPY_SRC_DIR" --only-group test-core --frozen | \
    uv pip install --python "$PYTHON_EXE" --no-deps --require-hashes -r -
