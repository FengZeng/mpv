# Soia Mpv Library

This project builds the `mpv` library (`libmpv`) used by the Soia Media Player.

It is designed for GitHub Actions CI, and can also be run locally for testing.

## Output Artifacts

Each successful build generates a self-contained runtime package containing:

- `libmpv` dylib
- all non-system runtime dylib dependencies (recursive)
- rewritten install names (`@rpath`) and runtime search path (`@loader_path`)
- SHA256 checksum file

This package is intended to run without requiring Homebrew on the target machine.

## Local Build

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
