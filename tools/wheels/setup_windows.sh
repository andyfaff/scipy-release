set -euo pipefail

{
    echo "CC=clang-cl"
    echo "CXX=clang-cl"
    echo "TARGET_ARCH=$TARGET_ARCH"
} >> "$GITHUB_ENV"

# Workaround for https://github.com/scipy/scipy/issues/25067.
rm -f C:/Strawberry/c/lib/pkgconfig/*.pc

# Use absolute paths with forward slashes for cibuildwheel's build environment.
project_dir=${GITHUB_WORKSPACE//\\//}
echo "CIBW_ENVIRONMENT_WINDOWS=PKG_CONFIG_PATH='$project_dir/.openblas' SCIPY_CYTHON_SOURCE='$project_dir/cython-src'" >> "$GITHUB_ENV"

bash tools/wheels/setup_clang_prefix_map.sh "$project_dir"

clang-cl --version
