set -xe

PROJECT_DIR="${1:-$PWD}"
SCIPY_SRC_DIR="${1:-$PWD}/scipy-src"


# Update license
echo "" >> $SCIPY_SRC_DIR/LICENSE.txt
echo "----" >> $SCIPY_SRC_DIR/LICENSE.txt
echo "" >> $SCIPY_SRC_DIR/LICENSE.txt
if [[ $RUNNER_OS == "Linux" ]] ; then
    cat $PROJECT_DIR/tools/wheels/LICENSE_linux.txt >> $SCIPY_SRC_DIR/LICENSE.txt
elif [[ $RUNNER_OS == "macOS" ]]; then
    cat $PROJECT_DIR/tools/wheels/LICENSE_osx.txt >> $SCIPY_SRC_DIR/LICENSE.txt
elif [[ $RUNNER_OS == "Windows" ]]; then
    cat $PROJECT_DIR/tools/wheels/LICENSE_win32.txt >> $SCIPY_SRC_DIR/LICENSE.txt
fi


# Every wheel links against scipy-openblas32, except the macOS ones built against
# Accelerate - wheels.yml sets INSTALL_OPENBLAS=false for those, and leaves it unset
# everywhere else. scipy-openblas64 is not used for wheels at all.
INSTALL_OPENBLAS=${INSTALL_OPENBLAS:-true}
OPENBLAS_GRP=""
if [[ "$INSTALL_OPENBLAS" = "true" ]] ; then
    OPENBLAS_GRP="--group openblas32"
fi


# install build dependencies via uv
# log which uv this is: on Linux it comes from the manylinux image, not from setup-uv
uv --version
# the lock file lives in this repo, not in the scipy checkout; the check_lock job in
# wheels.yml verifies it still matches scipy's dependency groups
PYTHON_EXE="$(python -c 'import sys; print(sys.executable)')"
# The reproducibility job sets this to exercise a different build-dependency prefix.
if [[ -n "${SCIPY_BUILD_VENV:-}" ]]; then
    # Inherit cibuildwheel's pinned `build` frontend from its Python installation;
    # the locked build dependencies installed below remain local to this environment.
    uv venv --system-site-packages --python "$PYTHON_EXE" "$SCIPY_BUILD_VENV"
    PYTHON_EXE="$SCIPY_BUILD_VENV/bin/python"
fi
uv export --project "$PROJECT_DIR" --no-default-groups --group build --no-emit-project $OPENBLAS_GRP --frozen | \
    uv pip install --python "$PYTHON_EXE" --no-deps --require-hashes -r -

# Temporarily test reproducibility fixes from a Cython source checkout. The pinned
# Cython wheel above is installed first so the rest of the locked environment stays
# unchanged; only Cython itself is replaced here.
if [[ -n "${SCIPY_CYTHON_SOURCE:-}" ]]; then
    uv pip install --python "$PYTHON_EXE" --reinstall --no-deps --no-build-isolation \
        "$SCIPY_CYTHON_SOURCE"
    "$PYTHON_EXE" -c "import Cython; print(f'Using Cython {Cython.__version__} from {Cython.__file__}')"
fi


# Configure the pkg-config file for OpenBLAS
if [[ "$INSTALL_OPENBLAS" = "true" ]] ; then
    # The PKG_CONFIG_PATH environment variable will be pointed to this path in
    # cibuildwheel.toml and .github/workflows/wheels.yml. Note that
    # `pkgconf_path` here is only a bash variable local to this file.
    pkgconf_path=$PROJECT_DIR/.openblas
    rm -rf $pkgconf_path
    mkdir -p $pkgconf_path
    "$PYTHON_EXE" -c "import scipy_openblas32; print(scipy_openblas32.get_pkg_config())" > $pkgconf_path/scipy-openblas.pc

    if [[ "$RUNNER_OS" == "Linux" ]]; then
        # Avoid making Meson add scipy-openblas's absolute path to the build RPATH.
        # FIXME: Support this directly in scipy-openblas's get_pkg_config().
        OPENBLAS_DIR=$("$PYTHON_EXE" -c "import scipy_openblas32; print(scipy_openblas32.get_lib_dir())")
        OPENBLAS_LIBRARY=$("$PYTHON_EXE" -c "import scipy_openblas32; print(scipy_openblas32.get_library())")
        ln -s "$OPENBLAS_DIR" "$pkgconf_path/lib"
        sed -i "s|^Libs: .*|Libs: -l$OPENBLAS_LIBRARY|" "$pkgconf_path/scipy-openblas.pc"
        if ! grep -Fqx "Libs: -l$OPENBLAS_LIBRARY" "$pkgconf_path/scipy-openblas.pc"; then
            echo "Failed to remove the OpenBLAS library path from Libs" >&2
            exit 1
        fi
    fi
fi
