#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="$PROJECT_ROOT/vendor"
MPV_DIR="$VENDOR_DIR/mpv"
BUILD_DIR="$MPV_DIR/buildout"
MINGW_PREFIX="${MINGW_PREFIX:-/mingw64}"
VCPKG_INSTALLED_DIR="${VCPKG_INSTALLED_DIR:-$PROJECT_ROOT/vcpkg_installed}"
VCPKG_TARGET_TRIPLET="${VCPKG_TARGET_TRIPLET:-x64-mingw-mp}"
MPV_WIN32_WINNT="${MPV_WIN32_WINNT:-0x0601}"

if [ ! -d "$MPV_DIR" ]; then
    echo "Missing mpv source: $MPV_DIR"
    echo "Run: ./download.sh"
    exit 1
fi

if [ ! -d "$MINGW_PREFIX" ]; then
    echo "Missing mingw prefix: $MINGW_PREFIX" >&2
    echo "Run this script under MSYS2 MINGW64 environment." >&2
    exit 1
fi

if [[ "$VCPKG_TARGET_TRIPLET" == *-static ]]; then
    VCPKG_STATIC_TRIPLET="$VCPKG_TARGET_TRIPLET"
    VCPKG_DYNAMIC_TRIPLET="${VCPKG_TARGET_TRIPLET%-static}"
    if [ ! -d "$VCPKG_INSTALLED_DIR/$VCPKG_DYNAMIC_TRIPLET" ]; then
        VCPKG_DYNAMIC_TRIPLET="${VCPKG_DYNAMIC_TRIPLET}-dynamic"
    fi
elif [[ "$VCPKG_TARGET_TRIPLET" == *-dynamic ]]; then
    VCPKG_DYNAMIC_TRIPLET="$VCPKG_TARGET_TRIPLET"
    VCPKG_STATIC_TRIPLET="${VCPKG_TARGET_TRIPLET%-dynamic}-static"
else
    VCPKG_DYNAMIC_TRIPLET="$VCPKG_TARGET_TRIPLET"
    VCPKG_STATIC_TRIPLET="${VCPKG_TARGET_TRIPLET}-static"
fi

VCPKG_DYNAMIC_PREFIX="$VCPKG_INSTALLED_DIR/$VCPKG_DYNAMIC_TRIPLET"
VCPKG_STATIC_PREFIX="$VCPKG_INSTALLED_DIR/$VCPKG_STATIC_TRIPLET"
VCPKG_PREFIX="$VCPKG_DYNAMIC_PREFIX"
if [ ! -d "$VCPKG_PREFIX" ] && [ -d "$VCPKG_STATIC_PREFIX" ]; then
    VCPKG_PREFIX="$VCPKG_STATIC_PREFIX"
fi

if [ ! -d "$VCPKG_DYNAMIC_PREFIX" ] && [ ! -d "$VCPKG_STATIC_PREFIX" ]; then
    echo "Missing vcpkg install roots for both dynamic/static triplets" >&2
    echo "Expected one of: $VCPKG_DYNAMIC_PREFIX or $VCPKG_STATIC_PREFIX" >&2
    echo "Run: bash ./install-vcpkg-deps.sh" >&2
    exit 1
fi

export PATH="$MINGW_PREFIX/bin:$PATH"
export PKG_CONFIG="$MINGW_PREFIX/bin/pkg-config"
PKG_CONFIG_DIRS=""
if [ -d "$VCPKG_DYNAMIC_PREFIX" ]; then
    PKG_CONFIG_DIRS="$VCPKG_DYNAMIC_PREFIX/lib/pkgconfig:$VCPKG_DYNAMIC_PREFIX/share/pkgconfig:$PKG_CONFIG_DIRS"
fi
if [ -d "$VCPKG_STATIC_PREFIX" ]; then
    PKG_CONFIG_DIRS="$VCPKG_STATIC_PREFIX/lib/pkgconfig:$VCPKG_STATIC_PREFIX/share/pkgconfig:$PKG_CONFIG_DIRS"
fi
export PKG_CONFIG_PATH="$PKG_CONFIG_DIRS${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_DIRS"

WINVER_FLAGS="-D_WIN32_WINNT=${MPV_WIN32_WINNT} -DWINVER=${MPV_WIN32_WINNT}"
export CFLAGS="$WINVER_FLAGS ${CFLAGS:-}"
export CXXFLAGS="$WINVER_FLAGS ${CXXFLAGS:-}"
if [ -d "$VCPKG_PREFIX/include" ]; then
    export CPPFLAGS="-I$VCPKG_PREFIX/include ${CPPFLAGS:-}"
fi
if [ -d "$VCPKG_PREFIX/lib" ]; then
    export LDFLAGS="-L$VCPKG_PREFIX/lib ${LDFLAGS:-}"
fi

if ! command -v meson >/dev/null 2>&1; then
    echo "meson not found in PATH" >&2
    exit 1
fi
if ! command -v ninja >/dev/null 2>&1; then
    echo "ninja not found in PATH" >&2
    exit 1
fi

echo "Building with MINGW_PREFIX=$MINGW_PREFIX"
echo "Using vcpkg dynamic triplet=$VCPKG_DYNAMIC_TRIPLET (exists: $([ -d "$VCPKG_DYNAMIC_PREFIX" ] && echo yes || echo no))"
echo "Using vcpkg static triplet=$VCPKG_STATIC_TRIPLET (exists: $([ -d "$VCPKG_STATIC_PREFIX" ] && echo yes || echo no))"
echo "Using MPV_WIN32_WINNT=$MPV_WIN32_WINNT"

cd "$MPV_DIR"

MESON_ARGS=(
    --buildtype=release
    -Dlibmpv=true
    -Dcplayer=false
    -Dvulkan=enabled
    -Dlua=enabled
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

DLL_COUNT="$(ls -1 "$BUILD_DIR"/libmpv*.dll 2>/dev/null | wc -l | tr -d ' ')"
if [ "$DLL_COUNT" = "0" ]; then
    echo "Build finished but no libmpv*.dll found in $BUILD_DIR" >&2
    exit 1
fi

echo "Build output ready in: $BUILD_DIR"
