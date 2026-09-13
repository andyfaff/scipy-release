set -euo pipefail

# Use the runner's selected Xcode and record its compiler and SDK versions.
export DEVELOPER_DIR SDKROOT
DEVELOPER_DIR=$(xcode-select -p)
SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
{
    echo "DEVELOPER_DIR=$DEVELOPER_DIR"
    echo "SDKROOT=$SDKROOT"
    echo "CC=$(xcrun --find clang)"
    echo "CXX=$(xcrun --find clang++)"
    echo "AR=$(xcrun --find ar)"
} >> "$GITHUB_ENV"
xcodebuild -version
xcrun clang --version
xcrun --sdk macosx --show-sdk-version

bash tools/wheels/setup_clang_prefix_map.sh "$PWD"

if [[ "$BLAS_VARIANT" == "accelerate" ]]; then
    echo "CIBW_CONFIG_SETTINGS=${CIBW_CONFIG_SETTINGS:-} setup-args=-Dblas=accelerate" >> "$GITHUB_ENV"
    cibw_env="MACOSX_DEPLOYMENT_TARGET=14.0 INSTALL_OPENBLAS=false"
else
    cibw_env="PKG_CONFIG_PATH='$PWD/.openblas' MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
fi
echo "CIBW_ENVIRONMENT_MACOS=$cibw_env SCIPY_CYTHON_SOURCE='$PWD/cython-src'" >> "$GITHUB_ENV"
