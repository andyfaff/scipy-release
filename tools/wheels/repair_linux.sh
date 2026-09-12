set -xe

WHEEL="$1"
DEST_DIR="$2"
PROJECT_DIR="${3:-$PWD}"

# Let auditwheel locate OpenBLAS while vendoring it.
OPENBLAS_DIR="$PROJECT_DIR/.openblas/lib"
if [[ ! -d "$OPENBLAS_DIR" ]]; then
    echo "OpenBLAS library directory does not exist: $OPENBLAS_DIR" >&2
    exit 1
fi

LD_LIBRARY_PATH="$OPENBLAS_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    auditwheel repair -w "$DEST_DIR" "$WHEEL"
