#!/usr/bin/env bash

set -euo pipefail

BUILD_OS="$(uname -s)"
HOST_ARCH="$(uname -m)"
MPV_TARGET_ARCH="${MPV_TARGET_ARCH:-$HOST_ARCH}"
case "$MPV_TARGET_ARCH" in
    arm64|x86_64) ;;
    *)
        echo "Unsupported MPV_TARGET_ARCH: $MPV_TARGET_ARCH" >&2
        exit 1
        ;;
esac

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

MESON_CROSS_ARGS=()
if [ "$BUILD_OS" = "Darwin" ]; then
    export XDG_CACHE_HOME="$PROJECT_ROOT/.cache"
    mkdir -p "$XDG_CACHE_HOME"
    if [ "$MPV_TARGET_ARCH" != "$HOST_ARCH" ]; then
        case "$MPV_TARGET_ARCH" in
            arm64) MESON_CPU_FAMILY="aarch64" ;;
            x86_64) MESON_CPU_FAMILY="x86_64" ;;
        esac
        CROSS_FILE="$XDG_CACHE_HOME/meson-cross-${MPV_TARGET_ARCH}.ini"
        cat > "$CROSS_FILE" <<EOF
[binaries]
c = 'clang'
cpp = 'clang++'
objc = 'clang'
objcpp = 'clang++'
ar = 'ar'
strip = 'strip'
pkg-config = 'pkg-config'
swift = 'swiftc'

[host_machine]
system = 'darwin'
cpu_family = '${MESON_CPU_FAMILY}'
cpu = '${MPV_TARGET_ARCH}'
endian = 'little'

[properties]
needs_exe_wrapper = true
EOF
        MESON_CROSS_ARGS+=(--cross-file "$CROSS_FILE")
    fi
fi

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
if [ "${#MESON_CROSS_ARGS[@]}" -gt 0 ]; then
    meson setup "$SOURCE_DIR/buildout" "$SOURCE_DIR" "${MESON_ARGS[@]}" "${MESON_CROSS_ARGS[@]}"
else
    meson setup "$SOURCE_DIR/buildout" "$SOURCE_DIR" "${MESON_ARGS[@]}"
fi
meson compile -C "$SOURCE_DIR/buildout" -j "$JOBS"
meson install -C "$SOURCE_DIR/buildout"

if ! "$PKG_CONFIG" --exists "libplacebo >= 7.360.1"; then
    echo "libplacebo pkg-config file not found after source build" >&2
    exit 1
fi
echo "libplacebo build output ready in: $INSTALL_PREFIX"
