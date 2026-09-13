set -euo pipefail

# Clang does not resolve relative paths before prefix mapping. Cover both build
# directory depths from wheels.yml, as well as absolute source and build paths.
prefix_flags=""
for mapping in \
    "..=." \
    "../../..=." \
    "$1/scipy-src=." \
    "$1/scipy-src/build-reference=./build" \
    "$1/scipy-src/build-rebuilt/nested/builddir=./build"
do
    if [[ "$RUNNER_OS" == "Windows" ]]; then
        # clang-cl needs /clang: forwarding; filenames can use either separator.
        prefix_flags+=" \"/clang:-fmacro-prefix-map=$mapping\""
        prefix_flags+=" \"/clang:-fmacro-prefix-map=${mapping//\//\\}\""
    else
        prefix_flags+=" \"-fmacro-prefix-map=$mapping\""
    fi
done

{
    echo "CFLAGS=${CFLAGS:-}$prefix_flags"
    echo "CXXFLAGS=${CXXFLAGS:-}$prefix_flags"
} >> "$GITHUB_ENV"
