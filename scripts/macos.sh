#!/bin/bash
# Cross-compile XCL on Apple Silicon and run its x64 Windows build through CrossOver.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cache="$root/target/macos"
target=x86_64-pc-windows-gnullvm
toolchain="$cache/llvm-mingw-20261117-ucrt-macos-universal"
dxc="$cache/dxc/bin/x64"
crossover="${XCL_CROSSOVER_APP:-/Applications/CrossOver.app}"
cxbin="$crossover/Contents/SharedSupport/CrossOver/bin"
bottle="${XCL_BOTTLE:-XCL}"
output="$root/target/$target/release"

usage() {
    cat <<'EOF'
Usage: scripts/macos.sh COMMAND [arguments]

  doctor       Check the Mac, CrossOver, bottle, and build dependencies.
  bootstrap    Download verified LLVM-MinGW/DXC releases; add the Rust target.
  bottle       Create a dedicated Windows 10 64-bit bottle using D3DMetal.
  build        Build the release workspace and stage the DXC DLLs.
  run GAME     Launch an unpacked game folder or executable; extra args pass through.
  xcl ARGS     Run any xcl.exe command (inspect, disasm, shaders, rpf, --version).
  test ARGS    Build and run the release test suite; ARGS go to cargo test.
               Default test arguments: -- --test-threads=4 --nocapture

Examples:
  scripts/macos.sh bootstrap
  scripts/macos.sh bottle
  scripts/macos.sh build
  scripts/macos.sh xcl --version
  scripts/macos.sh run "/Volumes/Games/My Game" -- game arguments
  scripts/macos.sh test --lib pe:: -- --nocapture

Requires macOS on Apple Silicon, Rust/rustup, Rosetta, and licensed CrossOver.
XCL_CROSSOVER_APP overrides /Applications/CrossOver.app; XCL_BOTTLE overrides XCL.
Downloads and build output stay in target/. This produces a Windows x64 binary,
not a native ARM64 runtime. CrossOver translates CPU and Windows/D3D12 calls.
EOF
}

fail() { printf 'xcl macOS: %s\n' "$*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null || fail "missing $1"; }
require_mac() {
    [[ $(uname -s) == Darwin && $(uname -m) == arm64 ]] || fail 'run from an ARM64 macOS terminal'
}
require_crossover() {
    [[ -x "$cxbin/wine" && -x "$cxbin/cxbottle" ]] || fail "CrossOver not found at $crossover"
    /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null || fail 'Rosetta is required; install it before running XCL'
}
bottle_exists() {
    "$cxbin/cxbottle" --bottle "$bottle" --status >/dev/null 2>&1
}
require_bottle() {
    bottle_exists || fail "bottle '$bottle' is missing; use the bottle command or open CrossOver"
}

verify() {
    local actual
    actual=$(shasum -a 256 "$1")
    [[ ${actual%% *} == "$2" ]] || fail "SHA-256 mismatch: $1"
}
download() {
    local url=$1 archive=$2 hash=$3
    if [[ ! -f "$archive" ]]; then
        curl --fail --location --retry 3 --output "$archive.part" "$url"
        verify "$archive.part" "$hash"
        mv "$archive.part" "$archive"
    fi
    verify "$archive" "$hash"
}
bootstrap() {
    local unzip_status=0
    require_command rustup
    require_command cargo
    mkdir -p "$cache"
    download 'https://github.com/mstorsjo/llvm-mingw/releases/download/20261117/llvm-mingw-20261117-ucrt-macos-universal.tar.xz' \
        "$cache/llvm-mingw.tar.xz" '98d340bbb8d46b09ad6886ffba88bd9d5415e131c316de48e6bd7647377446aa'
    if [[ ! -f "$toolchain/.xcl-extracted" ]]; then
        tar -xf "$cache/llvm-mingw.tar.xz" -C "$cache"
        [[ -x "$toolchain/bin/x86_64-w64-mingw32-clang" && -f "$toolchain/x86_64-w64-mingw32/bin/libunwind.dll" ]] || fail 'LLVM-MinGW extraction is incomplete'
        touch "$toolchain/.xcl-extracted"
    fi
    download 'https://github.com/microsoft/DirectXShaderCompiler/releases/download/v1.9.2609/dxc_2026_09_29.zip' \
        "$cache/dxc.zip" 'ad31b1fc8443175d204f77a611fdb3ef2ec42759bdc2f1167368de24a4a7e7f1'
    if [[ ! -f "$cache/dxc/.xcl-extracted" ]]; then
        # This verified Windows ZIP uses backslashes. macOS unzip normalizes them
        # and returns warning status 1; ditto preserves them as literal filenames.
        unzip -oq "$cache/dxc.zip" -d "$cache/dxc" || unzip_status=$?
        [[ $unzip_status -le 1 ]] || fail 'DXC extraction failed'
        [[ -f "$dxc/dxcompiler.dll" && -f "$dxc/dxil.dll" ]] || fail 'DXC archive is missing the x64 DLLs'
        touch "$cache/dxc/.xcl-extracted"
    fi
    [[ -f "$dxc/dxcompiler.dll" && -f "$dxc/dxil.dll" ]] || fail 'DXC archive is missing the x64 DLLs'
    rustup target add "$target"
}
build_environment() {
    require_command cargo
    [[ -x "$toolchain/bin/x86_64-w64-mingw32-clang" ]] || fail 'LLVM-MinGW is missing; run bootstrap'
    [[ -f "$dxc/dxcompiler.dll" && -f "$dxc/dxil.dll" ]] || fail 'DXC is missing; run bootstrap'
    export PATH="$root/scripts:$toolchain/bin:$PATH"
    export CARGO_TARGET_DIR="$root/target"
    export CARGO_TARGET_X86_64_PC_WINDOWS_GNULLVM_LINKER=x86_64-w64-mingw32-clang
    export CC_x86_64_pc_windows_gnullvm=x86_64-w64-mingw32-clang
    export AR_x86_64_pc_windows_gnullvm=x86_64-w64-mingw32-ar
}
stage_dxc() {
    mkdir -p "$output/deps"
    cp "$dxc/dxcompiler.dll" "$dxc/dxil.dll" "$toolchain/x86_64-w64-mingw32/bin/libunwind.dll" "$output/"
    cp "$dxc/dxcompiler.dll" "$dxc/dxil.dll" "$toolchain/x86_64-w64-mingw32/bin/libunwind.dll" "$output/deps/"
}
build() {
    build_environment
    (cd "$root" && cargo build --locked --workspace --release --target "$target")
    stage_dxc
}
wine_run() {
    require_crossover
    require_bottle
    # CrossOver's standard Z: drive maps /. DLL copies beside each executable also
    # allow DXC discovery if the caller has configured a different drive mapping.
    export XCL_DXC_DIR="${XCL_DXC_DIR:-Z:${dxc//\//\\}}"
    # Stop CrossOver option parsing before the executable: --version/--help and
    # other application options must reach XCL, and Unix executable paths convert.
    # CrossOver otherwise chooses its Y: home mapping for this workspace. The
    # tests embed Unix absolute Cargo paths, which must resolve from Z: (/).
    exec "$cxbin/wine" --bottle "$bottle" --workdir "Z:${PWD//\//\\}" -- "$@"
}
doctor() {
    require_mac
    require_crossover
    require_command rustup
    require_command cargo
    printf 'CrossOver: %s\nBottle: %s\nTarget: %s\n' "$crossover" "$bottle" "$target"
    require_bottle
    build_environment
    rustup target list --installed | /usr/bin/grep -qx "$target" || fail 'Rust target is missing; run bootstrap'
    printf 'Build and launch dependencies are available. GPU and game compatibility still need testing.\n'
}

command=${1:-help}
[[ $# == 0 ]] || shift
case "$command" in
    help|--help|-h) usage ;;
    bootstrap) require_mac; bootstrap ;;
    doctor) doctor ;;
    bottle)
        require_mac
        require_crossover
        if bottle_exists; then
            printf "Bottle '%s' already exists; its settings were left unchanged.\n" "$bottle"
        else
            "$cxbin/cxbottle" --bottle "$bottle" --create --template win10_64 \
                --param 'EnvironmentVariables:CX_GRAPHICS_BACKEND=d3dmetal'
        fi
        ;;
    build) require_mac; build ;;
    run|xcl)
        require_mac
        [[ -f "$output/xcl.exe" ]] || fail 'xcl.exe is missing; run build'
        if [[ "$command" == run ]]; then
            [[ $# -gt 0 ]] || fail 'run requires an unpacked game folder or executable'
            set -- run "$@"
        fi
        wine_run "$output/xcl.exe" "$@"
        ;;
    wine) wine_run "$@" ;; # Cargo's runner; executable and arguments remain separate.
    test)
        require_mac
        require_crossover
        require_bottle
        build
        export CARGO_TARGET_X86_64_PC_WINDOWS_GNULLVM_RUNNER='macos.sh wine'
        [[ $# != 0 ]] || set -- -- --test-threads=4 --nocapture
        mkdir -p "$cache"
        printf 'Test output: %s/test.log\n' "$cache"
        cd "$root"
        cargo test --locked --workspace --release --target "$target" "$@" 2>&1 | tee "$cache/test.log"
        ;;
    *) usage >&2; fail "unknown command: $command" ;;
esac
