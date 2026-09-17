#!/usr/bin/env bash

set -euo pipefail

BUILD_OS="$(uname -s)"

if [ "$BUILD_OS" = "Darwin" ]; then
    export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="$PROJECT_ROOT/vendor"
SOURCE_DIR="$VENDOR_DIR/libplacebo"
INSTALL_PREFIX="${LIBPLACEBO_PREFIX:-${LOCAL_INSTALL_PREFIX:-$PROJECT_ROOT/install}}"
VCPKG_TARGET_TRIPLET="${VCPKG_TARGET_TRIPLET:-arm64-osx-mp}"
VCPKG_INSTALL_PREFIX="$PROJECT_ROOT/vcpkg_installed/$VCPKG_TARGET_TRIPLET"
JOBS="${LIBPLACEBO_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"

if [[ "$BUILD_OS" == MINGW* || "$BUILD_OS" == MSYS* || "$BUILD_OS" == CYGWIN* ]]; then
    MINGW_PREFIX="${MINGW_PREFIX:-/mingw64}"
    if [ ! -d "$MINGW_PREFIX" ]; then
        echo "Missing mingw prefix: $MINGW_PREFIX" >&2
        exit 1
    fi
    export PKG_CONFIG="${PKG_CONFIG:-$MINGW_PREFIX/bin/pkg-config}"
else
    export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
fi

for tool in git meson ninja pkg-config; do
    command -v "$tool" >/dev/null 2>&1 || { echo "$tool not found in PATH" >&2; exit 1; }
done

export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:$VCPKG_INSTALL_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

MESON_ARGS=(
    --buildtype=release
    --prefix="$INSTALL_PREFIX"
    --libdir=lib
    -Ddemos=false
    -Dtests=false
    -Dbench=false
    -Dfuzz=false
    -Dvulkan=enabled
    -Dvk-proc-addr=enabled
    -Dopengl=disabled
    -Dglslang=disabled
    -Dshaderc=enabled
    -Dlcms=enabled
    -Dunwind=disabled
    -Dxxhash=disabled
)

if "$PKG_CONFIG" --exists dovi; then
    MESON_ARGS+=( -Dlibdovi=enabled )
else
    MESON_ARGS+=( -Dlibdovi=disabled )
fi

echo "Building libplacebo with prefix=$INSTALL_PREFIX"
meson setup "$SOURCE_DIR/buildout" "$SOURCE_DIR" "${MESON_ARGS[@]}"
meson compile -C "$SOURCE_DIR/buildout" -j "$JOBS"
meson install -C "$SOURCE_DIR/buildout"

if ! "$PKG_CONFIG" --exists "libplacebo >= 7.360.1"; then
    echo "libplacebo pkg-config file not found after source build" >&2
    exit 1
fi
echo "libplacebo build output ready in: $INSTALL_PREFIX"
