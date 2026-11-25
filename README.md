<p align="center">
  <img src="assets/macbox-logo.png" alt="MacBox official logo" width="240">
</p>

<h1 align="center">MacBox</h1>
<h2 align="center">XCL compatibility layer for Apple Silicon macOS</h2>

<p align="center">
  <a href="#requirements"><img src="assets/badges/apple-silicon.svg" alt="Apple Silicon: M5 Max tested"></a>
  <a href="#requirements"><img src="assets/badges/macos.svg" alt="macOS: 27.2 tested"></a>
  <a href="#tests-and-current-status"><img src="assets/badges/tests.svg" alt="Test suite: known failures"></a>
  <a href="LICENSE"><img src="assets/badges/license.svg" alt="License: GPL-2.0-only"></a>
</p>

<p align="center">
  Star MacBox to follow its progress on Apple Silicon. Help with testing, bug reports
  and focused fixes is welcome; start with <a href="CONTRIBUTING.md">the contribution guide</a>.
</p>

> [!IMPORTANT]
> **GTA VI has reached the Terms & Conditions screen in local MacBox development testing. It is not playable yet.**
>
> Local testing has shown the account picker, Rockstar intro, legal screens and loading
> artwork on an Apple M5 Max. The latest configured 600-second run stayed on loading
> artwork while large native pipelines continued compiling. No title crash or fatal compiler
> event was captured, but rendering stopped after about 132 seconds. The main menu and
> gameplay have not been reached.
> These historical development runs included a private BCPack integration that is
> excluded from this branch pending table-rights verification. They do not validate
> the published runtime subset.
> See the [launch notes](tests/results/macos-launch-2026-11-25.json) for the measured results.
>
> MacBox includes no game files. Running a title requires your own copy of its game data.

Read the [terms of use and legal notice](TERMS_OF_USE.md) for license rights,
third-party requirements and the project's repository policies.

**MacBox is an experimental compatibility layer and build workflow for
[XCL](https://github.com/xcl-dev/xcl)**, the Xbox Series X|S compatibility runtime.
It runs XCL's Windows x86-64 engine on Apple Silicon using **CrossOver, Rosetta 2
and D3DMetal**. A native ARM64 XCL runtime has not been implemented.

Targeted GPU compute and rendering checks pass on the tested setup, while the broader
runtime suite still has failures. Upstream XCL's Windows compatibility results do not
establish MacBox compatibility; the measurements below describe this Mac build.

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

For native pipeline diagnostics, `XCL_PSO_TRACE=1` logs a numbered start and finish
for each translated compute/graphics pipeline driver call, including both passes of
mesh/geometry pipelines. Entries give the original shader-blob hashes by stage, DXIL
bytes, driver-call duration and HRESULT. The existing compute slot/commit wait is
reported separately; IID and rect-list retries get separate call IDs. This switch is
off by default and does not change compile concurrency. Direct PC and stand-in
pipelines are not traced. A start without its finish identifies an unfinished host
call, not its cause.

`XCL_SHADOW_UPLOAD_WAIT=1` enables an experimental upload-completion wait on Mac
hosts using shadowed sparse memory. It is off by default. The title queue completes
prior work before its next submission; this can delay the submitting thread for up
to 10 seconds. A failed wait is logged and execution continues. Gameplay benefit
has not been established.

`XCL_MAC_BOTTOM_WRITE_COPY=1` enables an experimental Mac workaround for
`Write32BitValueBottomOfPipeX` on direct command lists: a full GPU barrier followed
by a four-byte copy from immutable upload memory. It is off by default. Predicated
lists, other list types, 64-bit writes and timestamps keep their existing paths.
The barrier can reduce performance.
Validation uses `XCL_SHADOW_UPLOAD_WAIT=1` separately; gameplay benefit is unverified.

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

The **published source snapshot on 2026-11-25** excludes the private BCPack
integration. Its release cross-build and all 11 intermediate compile checks passed.
`./scripts/macos.sh test --lib -- --nocapture --test-threads=1` reported
**695 passed / 21 failed / 23 ignored**, with the same 21 failures as the recorded
private candidate. The passing count includes 15 runtime skips and one optional
sample no-op. The exact environment and source binding are in the
[publication validation](tests/results/macos-launch-2026-11-25.json). Native Windows
and retail-title behavior of this published subset have not been tested.

The following development measurements used private builds including BCPack.

On **2026-11-25**, the optional Mac shadow-upload wait passed a new DMA regression
that fails before the change and with the option disabled. The project's matched
synthetic-title checks improved from **41 passed / 9 failed** with the option off
to **45 passed / 5 failed** with it on; neither Rust e2e harness passed. DMA copying,
sparse buffers, coherent readback and asynchronous uploads improved. Full-library
runs reported **701 passed / 21 failed / 23 ignored**, with the same failure names
as before. The passing count includes 15 logged runtime skips and one optional
sample no-op. These are Windows cross-builds run through CrossOver/D3DMetal;
native Windows and loading improvement with this option remain unverified. A later
account-picker run with the option enabled did not exercise loading. Commands,
source fingerprints and the separate test conditions are in the
[launch results](tests/results/macos-launch-2026-11-25.json).

The subsequent opt-in bottom-write copy passed its guarded memory and allocator-lifetime
regression; the same test fails with the option disabled. The synthetic title now gets
past its 32-bit bottom-write assertion and fails on the next 64-bit top write, retaining
**45 passed / 5 failed** checks. The library reports **702 passed / 21 failed / 23 ignored**;
all failure names and the 15 runtime skips match the baseline. One optional sample
also remains a no-op. These tests used CrossOver/D3DMetal, not native Windows.

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
These checks exposed failures in GPU precision and atomics, memory sharing and synchronization,
timestamps, window behavior, DirectStorage fences and XMA2 audio. Stencil also remains
a known limitation of the inherited Mac port. Passing synthetic rendering checks does
not establish complete game compatibility.

On **2026-11-25**, command-list creation was updated to translate the console's
GraphicsCommandList5/6 interface IDs before calling D3DMetal and to reject a
successful host result with a null object. The existing console wrapper remains
in use. All three new regression tests failed before the fix; afterward, 11
targeted and neighboring tests passed, with no failures, ignores or skips. The
three new tests also passed with `XCL_CONSOLE_LISTS=1`.

A local Xbox title that previously crashed during command-list creation completed
a 30-second bounded run with 377 PresentX calls and no crash. Captured output was
black; shader-pipeline errors and unimplemented graphics calls remain. This does
not establish playable gameplay. [Validation details](tests/results/macos-command-list-2026-11-25.json)
record the commands and limits, measured with **Codex (GPT-6)** on the setup above.

A subsequent 180-second run from `5c1fbc3` reached the first-run account screen:
the first nonblack capture at 46 seconds showed the account-picker, screen-narration
and Player1 controls. It completed with 4,521 shown frames, no crash and a reported
30 fps while waiting for input. The earlier 30-second runs ended before this screen
appeared. This verifies the account screen, not the main menu or gameplay.

A later manually advanced run displayed the Rockstar intro and legal screens, then
reached loading after accepting the terms before a watchdog crash. The main menu
and gameplay remain unverified.

DirectStorage fence signaling now accepts D3DMetal objects whose memory Wine's
`VirtualQuery` does not recognize ([XCL #1813](https://github.com/xcl-dev/xcl/pull/1813)).
Queues honor `AutoSubmitDisabled` and wait for explicit submission
([#1790](https://github.com/xcl-dev/xcl/pull/1790)). A private, unpublished BCPack
integration supports BC1, BC3, BC4, BC5, BC6H and BC7
([#905](https://github.com/xcl-dev/xcl/pull/905)); BC2 and hardware swizzle remain
unsupported. Its combined DirectStorage and BCPack checks passed 22 tests, with
no failures, ignores or skips. The published branch retains BCPack refusal while
[table provenance](docs/legal-provenance.md) remains unresolved.
[Validation details](tests/results/macos-launch-2026-11-25.json) record the commands
and limitations, measured with **Codex (GPT-6)** on the setup above.

With these storage changes and a partial shader cache, a later run displayed full-color
loading artwork. It decoded 2,374 BCPack streams and processed 87,299 storage requests
with no reported storage failures, but crashed at the title's watchdog after 221.365
seconds and 2,245 presents. The main menu and gameplay remain unverified.

The subsequent [XCL #1288](https://github.com/xcl-dev/xcl/pull/1288) adaptation excludes
time waiting at a pipeline bind from title `Sleep` calls of at least 100 ms by default;
`XCL_SLEEP_HOLD=0` restores host Sleep behavior. Before the fix, its five targeted
tests reported 2 passed and 3 failed; afterward, those and the storage checks reported
27 passed, with no failures, ignores or skips.
The broader library reported 666 passed, 21 failed and 23 ignored, with 14 runtime
skips within the passing count. The synthetic title still failed: 41 checks passed
and 9 failed, versus 42 passed and 8 failed with Sleep hold disabled.

With #1288, the title stayed alive until the 900-second limit and exited with code 0.
It presented 2,115 frames, but none after the interval ending at 191.549 seconds;
the watchdog was observed in the hold loop at 300 seconds. Storage processed 87,781
requests, including 2,401 decoded BCPack streams, with no reported failures. Three
native pipeline-error lines and four Metal compiler-service MTE crash reports were
recorded for this run. These were compiler-service crashes, not a title crash; the
responsible shader is unproven. Rendering did not resume and the main menu was not reached.

An opt-in compact compute backend adapts [XCL #1315](https://github.com/xcl-dev/xcl/pull/1315),
[#1316](https://github.com/xcl-dev/xcl/pull/1316) and [#1448](https://github.com/xcl-dev/xcl/pull/1448).
`XCL_COMPACT_CS=auto` selects repetitive compute programs; unset or `0` keeps classic
translation. Three large sample shaders produced DXIL 34.99×, 38.31× and 4.99× smaller
than classic. After DXIL preparation, all three native pipelines were created with
zero refusals in 48.5 seconds. Pipeline creation does not establish retail shader
output parity.

A subsequent manually advanced title run with `XCL_COMPACT_CS=auto` and the prepared
cache presented 2,711 frames, with none after the interval ending at 169.300 seconds.
The watchdog first raised an exception at 192.384 seconds and terminated the title at
230.777 seconds. Storage reported no failures, including 371 BCPack decodes; no native
pipeline errors or Metal compiler-service crashes attributable to this run were found.
Only 23 translated pipelines were reported, and execution of the three large compact
shaders was not established. The main menu was not reached; rendering recovery and
gameplay remain unverified.

A follow-up with the same executable and built-in speakers as the default output
reached the 900-second limit with exit code 0 and 2,620 frames, none after 204.183
seconds. USB remained the default input. Audio timer threads stayed at six in the
180-, 300- and 600-second dumps, but three native pipeline errors and four Metal
compiler-service crashes recurred. Compute pipeline creation continued through
892.577 seconds. Native caches may also have warmed, so this does not establish an
audio fix or a permanent compiler hang. Rendering did not resume and the main menu
was not reached.

The compact checks reported 37 passed, 0 failed and 0 ignored; one passing test skipped
native wave64 and another returned without its optional retail sample. The full library
reported 694 passed, the same 21 failures and 23 ignored, including 15 runtime skips
and the unexercised optional sample. The synthetic title retained 41 passing and
9 failing checks. Exact commands and measurements are in the
[launch notes](tests/results/macos-launch-2026-11-25.json).

Texture-layout caching adapts [XCL #1048](https://github.com/xcl-dev/xcl/pull/1048).
Its pointer-sharing regression failed before the change; the final layout checks passed
18 tests with no failures, ignores or skips. Repeated synthetic texture-layout calls
became faster, but that benchmark does not measure title loading time. With layout
caching and native tracing enabled, the full library reported 698 passed, the same
21 failures and 23 ignored, including 15 runtime skips; the optional retail comparison
remained unexercised. The synthetic title retained 41 passing and 9 failing checks.

The later 360-second title run displayed loading artwork and exited at its configured
limit without a title crash. It presented 1,709 frames, none after 126.713 seconds,
and decoded 2,386 BCPack streams with no reported storage failures. Saved setup state
and warmer native caches prevent attributing the artwork timing to layout caching.
Three native pipeline errors and four Metal compiler-service crashes recurred.
`XCL_PSO_TRACE=1` recorded 698 native calls: 697 returned `S_OK`, including all three
calls outstanding when the errors appeared. Their source hashes narrow the investigation
but do not establish which shader caused a compiler crash or whether its output was
correct. Calls continued returning through 347.614 seconds; one remained outstanding
at the limit. Rendering did not resume and the main menu was not reached.

A compute no-GVN experiment based on [XCL #1398](https://github.com/xcl-dev/xcl/pull/1398)
was rejected and removed from the active tree. It avoided one isolated compiler failure,
but a matched RayMiss shader compiled with default classic options and caused four
compiler-service deaths with no-GVN. Every native API call still returned `S_OK`;
compiler logs and kernel events distinguished success from failure. Both compact
variants compiled in that isolated test, without shader dispatch or output validation.
Two full-pack native attempts were intentionally stopped; neither completed. The
retained CLI trace identifies source hashes for native calls. Historical test counts,
frozen source snapshots and the four-variant comparison remain in the
[launch notes](tests/results/macos-launch-2026-11-25.json). The main menu remains unverified.

Compute shaders can be prepared before launch using the existing shader CLI:

```sh
XCL_DXC_THREADS=4 XCL_PIPELINE_THREADS=2 ./scripts/macos.sh xcl shaders \
  'Z:\path\to\your\game\shaders.rpf' --precompile --only cs --windows 4 --pipelines
```

Replace the placeholder with the pack's Wine `Z:` path. Add `XCL_COMPACT_CS=auto`
to prepare selected shaders in compact form, and use the same setting at launch.

`XCL_COMPACT_CS_PROGRAMS=<16-digit-program-code-hash>[,...]` adds individual programs
when `XCL_COMPACT_CS=auto`; use both settings for preparation and launch. These are
FNV64 hashes of raw program code, not the container hashes printed by `XCL_PSO_TRACE`.
Surrounding whitespace is allowed; an invalid entry rejects the whole list with one
warning. The list does not affect `XCL_COMPACT_CS=0` or `1`; classic remains the default.
The measured list `668149ddc1fd8bf6,662ed18a5f7f853f` completed full-pack preparation:
2,689 records with zero errors/skips and 2,689 native calls with zero refusals, in
2,843.8 seconds (CLI). The compiler capture recorded 1,182 starts and 1,173 successes,
with nine completions unobserved, no fatal exits or console errors, and one nonfatal
memory snapshot. All 2,682 unique expected cache entries were verified, including
the nine pinned sample payloads.
Existing caches were retained; no shader dispatch, output parity or main-menu progress
was tested by this preparation.

Before this expanded list, two full-pack native attempts were intentionally interrupted.
The first finished 856 calls with no observed compiler failure; the four-worker restart finished
1,459 calls but recorded four fatal Metal compiler-service exits and retries. All
finished calls still returned `S_OK`. Serial isolation reproduced the fault in an
additional HeatHaze program's classic translation; its compact translation and the
other three classic candidates compiled successfully. An earlier nonfatal memory
snapshot and unmatched compiler log entries are recorded separately in the launch
notes. Neither attempt completed. A later run with the expanded selection reached
loading artwork, but rendering stopped; the main menu remains unverified.

Start with a small sample: `--limit` counts input records before `--only cs` filtering.
Rebuilding the runtime can invalidate its translation cache; do not reuse an old
`XCL_TRANSLATED_IDENT` override after compiler changes.

Earlier classic preparation compiled three sample shaders and created all three
pipelines with no errors. Its full-pack attempts were interrupted, leaving 834 valid
translations for that build; the last native progress was 500 made and zero refused,
not final totals. The full-pack DXIL pass with `XCL_COMPACT_CS=auto` completed in
1,799.8 seconds with zero reported errors: 2,689 compute records, representing 2,682
unique containers, all have valid translation-cache entries for the tested build.
This includes existing cache hits; it does not mean 2,689 new DXC compilations.
That earlier completed pass did not request native pipeline creation; the later native
preparation stages are recorded above.

## Source and credits

MacBox is a derivative of **[XCL](https://github.com/xcl-dev/xcl)**. The console runtime,
loader, shader recompiler and existing tests are the work of XCL's contributors.
Git history and original license notices are preserved.

- Mac host support comes from [Ahmet-Dedeler's `mac-on-main-wip` branch](https://github.com/Ahmet-Dedeler/xcl/tree/mac-on-main-wip),
  pinned at [`5ae7547582b65b8accd343d585bbe9911ff51139`](https://github.com/Ahmet-Dedeler/xcl/commit/5ae7547582b65b8accd343d585bbe9911ff51139).
  It contains D3DMetal host adaptations, memory-copy fallbacks and Rosetta instruction handling.
- [XCL PR #750](https://github.com/xcl-dev/xcl/pull/750) supplies the unsupported-graphics-shader
  guard and its regression test; this patch is applied here.
- The private BCPack experiment uses XCL's VIctory port and is excluded from this branch. [`THIRD_PARTY.md`](THIRD_PARTY.md)
  records the sources and permission reported by XCL; the
  [provenance notes](docs/legal-provenance.md) distinguish the unresolved table rights.
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
The [terms of use and legal notice](TERMS_OF_USE.md) explain the project's scope
without changing the GPL. [Provenance review notes](docs/legal-provenance.md)
record the upstream sources and an unresolved rights question about BCPack tables.
External tools and compatibility components retain their own licenses. No game data,
console SDK binaries, keys, decryption tools or DRM-circumvention components are included.
