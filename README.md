<p align="center">
  <img src="assets/macbox-logo.png" alt="MacBox official logo" width="240">
</p>

<h1 align="center">MacBox</h1>
<h2 align="center">XCL compatibility layer for Apple Silicon macOS</h2>

<p align="center">
  <img src="assets/progress.svg" alt="Project progress: 15% complete" width="420">
</p>

**MacBox is an experimental ARM macOS compatibility layer and build workflow for
[XCL](https://github.com/xcl-dev/xcl)**, the Xbox Series X|S compatibility runtime.
It runs XCL's Windows x86-64 engine on Apple Silicon using **CrossOver, Rosetta 2
and D3DMetal**. A native ARM64 XCL runtime has not been implemented.

The project currently builds, launches and passes targeted GPU compute and rendering
tests on an M5 Max. The broader runtime suite still has failures. **Retail gameplay
has not been validated for MacBox**; upstream XCL's Windows game compatibility list
is not a MacBox compatibility list.

## How it works

| Component | Role |
|---|---|
| XCL | Loads unpacked Xbox Series executables and implements console system libraries. |
| Rosetta 2 | Translates x86-64 CPU code for Apple Silicon. |
| CrossOver / Wine | Provides the Windows environment and host APIs. |
| XCL shader recompiler + DXC | Translates console RDNA2 shaders into HLSL and then DXIL. |
| D3DMetal | Translates the D3D12 graphics workload to Apple's Metal stack. |

MacBox retains the Rust workspace, engine interfaces and **`xcl.exe`** executable
name to stay compatible with XCL's tooling. The MacBox additions provide repeatable
setup, dependency verification, DLL staging, CrossOver launch and test commands.

## Requirements

- An Apple Silicon Mac and an ARM64 macOS terminal.
- Rust and `rustup`, plus Git and the standard macOS command-line tools.
- CrossOver installed, with a valid license or trial, and Rosetta 2 available.
- For a game run, already-unpacked Xbox Series X|S game files you own.

The verified setup is **Apple M5 Max, 64 GB RAM, macOS 27.2, CrossOver 26.3 and
Rust 1.99.0**. Other machines and versions have not been verified by MacBox.
CrossOver, Rosetta, D3DMetal and game files are not included in this repository.

## Build and set up

```sh
git clone https://github.com/AyhanSh/MacBox.git
cd MacBox

./scripts/macos.sh bootstrap
./scripts/macos.sh bottle
./scripts/macos.sh build
./scripts/macos.sh doctor
./scripts/macos.sh xcl --version
```

`bootstrap` downloads pinned [LLVM-MinGW 20261117](https://github.com/mstorsjo/llvm-mingw/releases/tag/20261117)
and [DXC v1.9.2609](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.9.2609),
checks their SHA-256 hashes, and installs Rust's `x86_64-pc-windows-gnullvm` target.
Downloads stay in `target/macos/`. `build` compiles the release workspace and stages
DXC and `libunwind.dll` beside the executable and test binaries.

`bottle` creates a dedicated **XCL** Windows 10 x64 bottle with D3DMetal enabled.
Existing bottles are left unchanged; select D3DMetal in CrossOver when using your
own bottle. `doctor` checks dependencies and bottle availability; it does not prove
GPU or game compatibility.

Build output: `target/x86_64-pc-windows-gnullvm/release/xcl.exe`.

## Run and inspect

```sh
./scripts/macos.sh run "/Volumes/Games/My Game"
./scripts/macos.sh run "/Volumes/Games/My Game/game.exe" -- game arguments

./scripts/macos.sh xcl inspect "/Volumes/Games/My Game/game.exe"
./scripts/macos.sh xcl disasm "/path/to/shader.bin" --hex
./scripts/macos.sh xcl shaders "/path/to/shaders.rpf" --recomp
./scripts/macos.sh xcl rpf "/path/to/archive.rpf" --top 50
```

`run` launches a game folder or executable. `xcl` passes arguments to the original
CLI, including `--help`, `inspect`, `disasm`, `shaders` and `rpf`. Paths containing
spaces must be quoted. Keep game files outside the source checkout.

| Environment variable | Purpose / default |
|---|---|
| `XCL_CROSSOVER_APP` | CrossOver installation; defaults to `/Applications/CrossOver.app`. |
| `XCL_BOTTLE` | Bottle name; defaults to `XCL`. |
| `XCL_DATA_ROOT` | Optional Windows-visible directory for per-title data. |
| `XCL_DXC_DIR` | Optional DXC override; the script normally sets this automatically. |
| `XCL_REQUIRE_GPU` | Makes unavailable requested GPU features fail tests instead of skip. |

XCL directs writes to an overlay. Saves, configuration and logs normally live in the
bottle at `%LOCALAPPDATA%\XCL\<title>\`: `xcl.toml`, `overlay\`, `saves\`, `pls\`,
`temp\`, `cache\` and `logs\`. `logs\xcl.log` and `logs\report.json` are useful when
reporting failures. Use a Windows-visible path such as `Z:\Volumes\XCLData` for
`XCL_DATA_ROOT`, and keep it outside the game folder.

## Tests and current status

```sh
# Build every test executable without running it.
./scripts/macos.sh test --no-run

# Synthetic CLI and GPU checks; no game data required.
./scripts/macos.sh test --test disasm_e2e --test rpf_e2e -- --nocapture
XCL_REQUIRE_GPU=wave64,mesh ./scripts/macos.sh test --test gpu_compute_e2e -- --nocapture --test-threads=1
XCL_REQUIRE_GPU=wave64,mesh ./scripts/macos.sh test --lib gpu::recomp::tests::gpu_mesh_mode_two_passes -- --exact --nocapture

# Broader checks currently expose known failures.
./scripts/macos.sh test --lib -- --nocapture --test-threads=1
./scripts/macos.sh test --test e2e test_title_runs_and_game_folder_is_untouched -- --exact --nocapture --test-threads=1
```

`./scripts/macos.sh test` runs the workspace suite. Output goes to
`target/macos/test.log`, and the command preserves a failing exit status. Some tests
need host capabilities or optional `XCL_SAMPLE_*` game files; skips and ignored tests
are not evidence of working behavior. The full workspace suite has not passed.

The following results were measured on **2026-11-24**, using the setup above and a
release build of base `5ae7547582b65b8accd343d585bbe9911ff51139` plus the PR #750
patch and MacBox launch tooling. Validation was performed with **Codex (GPT-6)**.
The [machine-readable validation summary](tests/results/macos-2026-11-24.json)
records commands, individual failures and skips without private local paths.

| Check | Observed result |
|---|---|
| Release workspace / test compilation | Build succeeded; all 15 test executables compiled. |
| Targeted disassembly, RPF, compute, mesh, geometry and VS/PS checks | 8 passed, 0 failed, 0 ignored, 0 skipped. |
| Full library binary, one test thread | 649 reported passed, 21 failed, 23 ignored. |
| Runtime skips within the library's passing count | 14; missing capabilities, system components or optional game data. |
| Synthetic console title | 0 passed, 1 failed, 0 ignored, 0 skipped. |
| Retail games / Windows regression run | Not tested by MacBox. |

The shader guard avoids the synthetic title's unsupported-shader crash in D3DMetal.
Remaining failures involve GPU precision and atomics, memory sharing and synchronization,
timestamps, window behavior, DirectStorage fences and XMA2 audio. Stencil also remains
a known limitation of the inherited Mac port. Passing synthetic rendering checks does
not establish complete game compatibility.

## Source and credits

MacBox is a derivative of **[XCL](https://github.com/xcl-dev/xcl)**. The console runtime,
loader, shader recompiler and existing tests are the work of XCL's contributors.
Git history and original license notices are preserved.

- Mac host support comes from [Ahmet-Dedeler's `mac-on-main-wip` branch](https://github.com/Ahmet-Dedeler/xcl/tree/mac-on-main-wip),
  pinned at [`5ae7547582b65b8accd343d585bbe9911ff51139`](https://github.com/Ahmet-Dedeler/xcl/commit/5ae7547582b65b8accd343d585bbe9911ff51139).
  It contains D3DMetal host adaptations, memory-copy fallbacks and Rosetta instruction handling.
- [XCL PR #750](https://github.com/xcl-dev/xcl/pull/750) supplies the unsupported-graphics-shader
  guard and its regression test; this patch is applied here.
- MacBox adds the setup/build/run/test workflow in [`scripts/macos.sh`](scripts/macos.sh)
  and documents results on Apple Silicon. The base differs from current upstream XCL.
- Broader macOS work is tracked in [XCL issue #258](https://github.com/xcl-dev/xcl/issues/258).

## Next work and contributing

The immediate work is memory synchronization, DirectStorage and audio correctness,
followed by testing owned retail titles and recording repeatable regression results.
Windows regression coverage is still needed when changing shared engine code. A native
ARM64 CPU/runtime backend is future work; this project currently follows the compatibility-layer route.

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`AGENTS.md`](AGENTS.md) before changing code.
Report exact hardware, versions, commands, failures and skips; do not submit game files.
The inherited [`HANDOFF.md`](HANDOFF.md), [design specification](docs/specs/2026-11-20-xcl-design.md)
and [wave64 notes](docs/wave64-on-wave32.md) explain XCL internals and may describe
Windows or historical behavior beyond MacBox's verified status.

## License

**GPL-2.0-only**; see [`LICENSE`](LICENSE) and [`THIRD_PARTY.md`](THIRD_PARTY.md).
External tools and compatibility components retain their own licenses. No game data,
console SDK binaries, keys, decryption tools or DRM-circumvention components are included.
