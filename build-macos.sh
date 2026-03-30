#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="$PROJECT_ROOT/vendor"
MPV_DIR="$VENDOR_DIR/mpv"
BUILD_DIR="$MPV_DIR/buildout"

if [ ! -d "$MPV_DIR" ]; then
    echo "Missing mpv source: $MPV_DIR"
    echo "Run: ./download.sh"
    exit 1
fi
BREW_PREFIX="$(brew --prefix)"
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-15}"
MIN_OS_FLAG="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
BUILD_ARCH="$(uname -m)"
case "$BUILD_ARCH" in
    arm64|x86_64) ;;
    *)
        echo "Unsupported macOS arch: $BUILD_ARCH" >&2
        exit 1
        ;;
esac
SWIFT_TARGET_TRIPLE="${BUILD_ARCH}-apple-macos${MACOSX_DEPLOYMENT_TARGET}"
SWIFT_FLAGS="-target ${SWIFT_TARGET_TRIPLE}"
export PKG_CONFIG_PATH="$BREW_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export CFLAGS="$MIN_OS_FLAG ${CFLAGS:-}"
export CXXFLAGS="$MIN_OS_FLAG ${CXXFLAGS:-}"
export OBJCFLAGS="$MIN_OS_FLAG ${OBJCFLAGS:-}"
export OBJCXXFLAGS="$MIN_OS_FLAG ${OBJCXXFLAGS:-}"
export LDFLAGS="-L$BREW_PREFIX/lib $MIN_OS_FLAG ${LDFLAGS:-}"
export CPPFLAGS="-I$BREW_PREFIX/include ${CPPFLAGS:-}"
export XDG_CACHE_HOME="$PROJECT_ROOT/.cache"
export CLANG_MODULE_CACHE_PATH="$XDG_CACHE_HOME/clang-module-cache"
export SWIFT_MODULECACHE_PATH="$XDG_CACHE_HOME/swift-module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH"

cd "$MPV_DIR"
echo "$PKG_CONFIG_PATH"
echo "Building with MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
echo "Building with Swift target=$SWIFT_TARGET_TRIPLE"

MESON_ARGS=(
    --buildtype=release
    -Dlibmpv=true
    -Dcplayer=false
    -Dmacos-media-player=enabled
    -Dcoreaudio=enabled
    -Dvulkan=enabled
    -Dlua=enabled
    -Dswift-build=enabled
    "-Dswift-flags=${SWIFT_FLAGS}"
)
if [ ! -d "$BUILD_DIR" ]; then
    echo "Configuring Meson..."
    meson setup buildout "${MESON_ARGS[@]}"
else
    echo "Reconfiguring Meson (wipe old options)..."
    meson setup buildout --reconfigure "${MESON_ARGS[@]}"
fi

echo "Building..."
meson compile -C buildout

LIBMPV_DYLIB="$BUILD_DIR/libmpv.2.dylib"
if [ -f "$LIBMPV_DYLIB" ] && nm -u "$LIBMPV_DYLIB" | grep -q '_\$ss20__StaticArrayStorageCN'; then
    echo "Detected Swift runtime symbol unsupported on macOS 13: _\\$ss20__StaticArrayStorageCN" >&2
    echo "Check swift target/deployment settings before packaging." >&2
    exit 1
fi
