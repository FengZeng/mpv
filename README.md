# Soia Mpv Library

This project builds the `mpv` library (`libmpv`) used by the Soia Media Player.

It is designed for GitHub Actions CI, and can also be run locally for testing.

## Output Artifacts

Each successful build generates a self-contained runtime package containing:

- `libmpv` runtime library (`.dylib` on macOS, `.dll` on Windows, `.so` on Linux)
- `soia_utils` runtime library for the current target platform
- `libmpv` link libraries on Windows (`.lib`, when generated)
- all non-system runtime dynamic dependencies (recursive)
- Linux package includes runtime dependencies recursively (excluding core glibc/loader libraries)
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
MPV_VERSION=0.41.0 bash ./download.sh
bash ./build-macos.sh
```

Build a local runtime package:

```bash
bash ./package-macos-runtime.sh --pkg-name libmpv-local-macos
```

## Local Build (Windows Target via Ubuntu x64 + MinGW-w64)

Recommended approach for Windows builds is cross-compiling on Ubuntu x64 with
`mingw-w64`. This keeps the toolchain aligned with CI and avoids maintaining a
separate MSVC pipeline.

Install host tools on Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y \
  autoconf autoconf-archive automake build-essential curl git libtool make \
  mingw-w64 gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 \
  nasm pkg-config python3 python3-pip zip
python3 -m pip install --upgrade pip
python3 -m pip install meson ninja
```

Bootstrap vcpkg, install Windows target dependencies, and build:

```bash
bash ./download.sh
git clone --depth 1 https://github.com/microsoft/vcpkg.git ./vcpkg
./vcpkg/bootstrap-vcpkg.sh -disableMetrics
bash ./install-vcpkg-deps-mingw.sh
bash ./build-mingw64.sh
```

Optional: tune minimum Windows target API level (default is `0x0601`, Windows 7):

```bash
export MPV_WIN32_WINNT=0x0603
bash ./install-vcpkg-deps-mingw.sh
bash ./build-mingw64.sh
```

## GitHub CI (ubuntu-24.04, MinGW-w64 Cross Build)

Recommended CI steps:

```yaml
- uses: actions/checkout@v4

- name: Setup Python
  uses: actions/setup-python@v5
  with:
    python-version: "3.12"

- name: Install host build tools
  shell: bash
  run: |
    sudo apt-get update
    sudo apt-get install -y \
      autoconf autoconf-archive automake build-essential curl git libtool make \
      mingw-w64 gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 \
      nasm pkg-config zip
    python -m pip install --upgrade pip
    python -m pip install meson ninja

- name: Bootstrap vcpkg
  shell: bash
  run: |
    git clone --depth 1 https://github.com/microsoft/vcpkg.git ./vcpkg
    ./vcpkg/bootstrap-vcpkg.sh -disableMetrics

- name: Download mpv source
  shell: bash
  run: |
    bash ./download.sh

- name: Install vcpkg deps (MinGW triplet)
  shell: bash
  run: |
    ./install-vcpkg-deps-mingw.sh

- name: Build libmpv (MinGW-w64)
  shell: bash
  run: |
    ./build-mingw64.sh
```

## Local Build (Linux)

Install dependencies on Ubuntu/Debian (example):

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential git curl python3 meson ninja-build pkg-config \
  libfreetype-dev libfribidi-dev liblcms2-dev libluajit-5.1-dev \
  libass-dev libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev libavutil-dev \
  libswresample-dev libswscale-dev \
  libpipewire-0.3-dev libpulse-dev \
  libxss-dev libxpresent-dev \
  libwayland-dev wayland-protocols libxkbcommon-dev \
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
