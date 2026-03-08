# Soia Mpv Library

This project builds the `mpv` library (`libmpv`) used by the Soia Media Player.

It is designed for GitHub Actions CI, and can also be run locally for testing.

## Output Artifacts

Each successful build generates a self-contained runtime package containing:

- `libmpv` runtime library (`.dylib` on macOS, `.dll` on mingw64, `.so` on Linux)
- `libmpv` link libraries on mingw64 (`.lib`/`.a`/`.dll.a`, when generated)
- all non-system runtime dynamic dependencies (recursive)
- rewritten install names (`@rpath`) and runtime search path (`@loader_path`) on macOS
- SHA256 checksum file

This package is intended to run without requiring Homebrew on the target machine.

## Local Build (MacOS)

Download source and build:

```bash
bash ./download.sh
bash ./build-macos.sh
```

Build a specific mpv version:

```bash
MPV_VERSION=0.41.1 bash ./download.sh
bash ./build-macos.sh
```

Build a local runtime package:

```bash
bash ./package-macos-runtime.sh --pkg-name libmpv-local-macos
```

## Local Build (mingw64 / MSYS2)

Download source and build in `MSYS2 MINGW64` shell:

```bash
bash ./download.sh
bash ./build-mingw64.sh
```

Build a local runtime package:

```bash
bash ./package-mingw64-runtime.sh --pkg-name libmpv-local-windows-mingw64-x86_64
```

## Local Build (Linux)

Install dependencies on Ubuntu/Debian (example):

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential git curl python3 meson ninja-build pkg-config \
  libfreetype-dev libfribidi-dev liblcms2-dev libluajit-5.1-dev \
  libass-dev libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
  libarchive-dev libbluray-dev libcdio-paranoia-dev libdvdnav-dev \
  librubberband-dev libzimg-dev libplacebo-dev libvulkan-dev patchelf
```

Download source and build:

```bash
bash ./download.sh
bash ./build-linux.sh
```

Build a local runtime package:

```bash
bash ./package-linux-runtime.sh --pkg-name libmpv-local-linux
```
