# Sobel C-to-RTL and SKY130 demonstration

PandA Bambu generates the actual Verilog arithmetic for a saturated eight-bit Sobel window kernel. An APB wrapper supplies pixels and captures the result. Independent C/Python reference checks, RTL and gate simulations, routed timing, Magic DRC and hierarchical Netgen LVS test the implementation at the scope below. **Crucible is beta.**

The reviewed [twelve-page PDF](docs/Sobel_HLS_APB_SKY130_Ignytion_A4.pdf) and [editable A4 PowerPoint](docs/Sobel_HLS_APB_SKY130_Ignytion_A4.pptx) are included. [Compact results](evidence/summary.json), [dependency identities](evidence/dependencies.json) and [document hashes](evidence/documents.sha256.json) preserve the recorded measurements. Raw logs and generated builds stay outside Git.

## Recorded result

Measured locally through 29 October 2026:

| Check | Outcome |
|---|---|
| C and generated core | 5,162 frozen windows; 126 distinct outputs, 4,382 unsaturated |
| APB, mapped and routed netlists | 67,124 checks per APB run; zero-delay functional models |
| Extracted nominal setup / hold | +11.72 / +0.12 ns worst slack at a 20 ns clock |
| Slew / capacitance / fanout | Zero reported violations |
| Magic DRC | Zero reported errors |
| Hierarchical LVS | Unique match; 874 devices and 921 nets on each side |
| Negative controls | Wrong expected result, disconnected result-Q reference and infeasible 1 ns clock rejected |

Numerical agreement is sampled evidence rather than exhaustive equivalence proof. Timing uses SKY130 HD TT 25 C/1.80 V and nominal OpenRCX extraction. The hierarchical comparison retains supply/body pins and exempts physical filler/tap classes through the PDK setup.

## Numerical and register contract

Supply nine unsigned byte pixels p0 through p8 in row-major order. Compute `gx = -p0+p2-2*p3+2*p5-p6+p8` and `gy = -p0-2*p1-p2+p6+2*p7+p8`. The output is `min(255, abs(gx)+abs(gy))`, with signed integer intermediates. This is the L1 gradient approximation. The caller supplies the complete window; frame storage and image-border handling are outside this kernel.

| Offset | Register |
|---|---|
| 0x00 | Write bit 0 to start; reads return zero |
| 0x04 | Read status: bit 0 busy, bit 1 sticky done |
| 0x08 | Read result in bits 7:0 |
| 0x10 | Read/write p0 through p3, with p0 in the least significant byte |
| 0x14 | Read/write p4 through p7, with p4 in the least significant byte |
| 0x18 | Read/write storage; p8 uses bits 7:0 |

Reset is active low. APB accesses have no wait states; setup phases have no write side effects. Invalid/unaligned addresses and writes to status/result return errors. The generated arithmetic is combinational and done follows start. The wrapper captures the result on the following core-completion edge, before the next legal APB access; this is not a multi-cycle backpressure demonstration.

## Prerequisites

Use the tested Linux x86-64/WSL route with an existing Crucible beta installation, Bash, host GCC and Python 3. The existing `crucible.lock` pins Bambu, Yosys, OpenROAD, Icarus, KLayout stream tools, Magic and Netgen artifacts. Bambu's packaged archive is approximately 1.39 GB and may need downloading on a new machine.

Provide a complete SKY130A PDK, including HD LEF/Liberty/GDS/functional Verilog views, Magic technology, Netgen setup and OpenRCX rules. PDK files and native runtime dependencies are not vendored. The default PDK location is `$HOME/.ciel/sky130A`; export `PDKPATH` to override it. `CAD_ROOT` may override the managed Magic library location. See [example configuration](config/example.env.sh) and the dependency hashes above.

The final observer needs KLayout Python bindings, pinned in `requirements.txt`. It was run on the Windows host against WSL-generated artifacts; install compatible bindings in the Python environment where the observer is run. The C reference uses host GCC and Python's standard library. Native Windows/macOS/ARM tool acquisition and an independent clean-machine rebuild have not been demonstrated.

## 1. Choose the correct shell and directory

Run every Linux command below from this repository's root: the directory containing `crucible.toml`, `crucible.lock` and `scripts/`. The tested flow uses **WSL/Linux x86-64**. A Windows PowerShell block is labelled separately. Do not paste a PowerShell block into Bash or run a Bash block in PowerShell.

Crucible must already be installed in that Linux/WSL shell. A PDK, Tcl-capable Magic where required, and native runtime libraries are separate prerequisites; this repository does not provide an installation archive for them. Commands containing `/path/to/...` require your actual dependency location before execution.

## 2. Restore and inspect the Crucible environment

Linux/WSL Bash:

```bash
igny init
igny --version
igny workspace sync
igny status
igny env show hls-sobel
igny tool show bambu --env hls-sobel
igny tool show yosys --env hls-sobel
igny tool show openroad --env hls-sobel
igny tool show iverilog --env hls-sobel
igny tool show magic --env hls-sobel
igny tool show netgen --env hls-sobel
igny tool show klayout-stream --env hls-sobel
```

`igny init` initializes the outer workbench shell. `workspace sync` reads the supplied lock, acquires missing pinned artifacts and restores the recorded environment. It may download large archives; it does not build this design, provision a PDK, or install every native library. `status` should identify this workspace, and `env show` should list the tools in `hls-sobel`. `tool show` establishes the binary/provider resolution before a run.

Stop on an acquisition/binding error and inspect its reported log. A successful version or inventory command is a prerequisite check, not a design PASS. The commands below select the same project environment explicitly through the scripts.

## 3. Configure the PDK, host compiler and observer

Linux/WSL Bash:

```bash
export PDKPATH="$HOME/.ciel/sky130A"
# Alternative, after replacing this example with your actual path:
# export PDKPATH='/path/to/sky130A'
test -f "$PDKPATH/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
test -f "$PDKPATH/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"
test -f "$PDKPATH/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds"
test -f "$PDKPATH/libs.tech/magic/sky130A.tech"
test -f "$PDKPATH/libs.tech/netgen/sky130A_setup.tcl"
test -f "$PDKPATH/libs.tech/openlane/rcx_rules.info"
gcc --version
python3 --version
igny run --env hls-sobel bambu --version
igny run --env hls-sobel yosys -V
```

GCC is the host compiler used to compile the C reference; it is not supplied by this project's tool lock. The PDK must also include technology LEF, functional cell Verilog and primitives. `CAD_ROOT` may override the managed Magic library root if the workbench payload location differs.

### Python observer setup

The measured route used the **Windows Python observer against WSL-generated files**. In Windows PowerShell, from this same repository root:

```powershell
python --version
python -m venv .venv-win
.\.venv-win\Scripts\python.exe -m pip install -r requirements.txt
.\.venv-win\Scripts\python.exe -c "import klayout.db; print('Observer imports available')"
```

Use that explicit virtual-environment interpreter for the PowerShell verification commands below; activation and execution-policy changes are unnecessary. The virtual environment is ignored by Git. Package installation needs access to the configured Python package index.

If running the observer entirely in Linux instead, install the same requirements in a Linux Python environment:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -c "import klayout.db; print('Observer imports available')"
```

The two Python environments are alternatives. A Windows virtual environment cannot be used as a Linux interpreter. Independent clean-machine reproduction remains unverified.

## 4. Run every engineering stage in order

Linux/WSL Bash:

```bash
bash scripts/reference.sh
bash scripts/run.sh hls
bash scripts/run.sh core
bash scripts/run.sh apb
bash scripts/run.sh synth
bash scripts/run.sh mapped
bash scripts/run.sh physical
bash scripts/run.sh stream
bash scripts/run.sh routed
bash scripts/physical_verify.sh
bash scripts/controls.sh
python3 scripts/provenance.py
```

| Stage | Work performed / principal outputs |
|---|---|
| `reference.sh` | Compile actual C, compare with independent matrix kernels, enforce frozen cases; `reports/reference.json`, `reference/vectors.mem` |
| `hls` | Actual Bambu generation; `build/hls/sobel3x3.v`, `reports/bambu.log` |
| `core` | Generated RTL/vector comparisons plus corrupted-expected control; `reports/core_positive.log`, `reports/core_negative.log` |
| `apb` | Register/start/result/consecutive-transfer checks and negative control; `reports/apb_*` |
| `synth` | Expand the configured Liberty path and map the real generated design; `build/mapped.v`, `reports/synthesis.log` |
| `mapped` | Same APB suite with unchanged official functional cell models; `reports/mapped_positive.log` |
| `physical` | Floorplan, PDN/taps, placement/repair, CTS/hold repair, routing and OpenRCX; DEF/ODB/SPEF plus `reports/physical.log` |
| `stream` | Add physical supply ports and stream actual cell geometry with the explicit layer map; `build/sobel_apb.gds`, `build/routed_power.v` |
| `routed` | Same functional suite against the final routed netlist; `reports/routed_positive.log` |
| `physical_verify.sh` | Read GDS in Magic, check/extract, compare hierarchical supply-retaining netlists; `reports/magic_drc_extract.log`, `reports/lvs.log` |
| `controls.sh` | Disconnect one result-Q in a scratch LVS reference and analyse the route at 20 ns / deliberately infeasible 1 ns; `reports/lvs_negative.log`, `reports/sta.log`, timing/electrical reports |
| `provenance.py` | Hash the actual PDK input views; `reports/dependencies.json` |

The generated Bambu file preserves upstream notices and remains a generated build artifact. The adapter only maps actual core ports. `simulation_models.py` selects unchanged used PDK functional modules after preprocessing. No handwritten Sobel replacement or fabricated cell model is inserted.

## 5. Run the final observer and inspect all result classes

Windows PowerShell:

```powershell
.\.venv-win\Scripts\python.exe scripts\verify.py
```

Or, with the Linux Python environment from step 3:

```bash
.venv/bin/python scripts/verify.py
```

Require `SOBEL_NUMERICAL_APB_PHYSICAL_AND_NEGATIVE_CONTROLS_VERIFIED`. The core must report `vectors=5162 max_cycles=1`. APB, mapped and routed runs must each report `checks=67124`. The wrong-expected-byte controls must fail at vector 0, expected 1 and observed 0, with simulator exit 1. The runner treats those intentional failures as successful guard tests.

Linux/WSL log inspection:

```bash
cat reports/core_positive.log
cat reports/core_negative.log
cat reports/apb_positive.log
cat reports/apb_negative.log
cat reports/mapped_positive.log
cat reports/routed_positive.log
tail -n 10 reports/sta.log
cat reports/electrical.rpt
cat reports/check_setup.rpt
tail -n 12 reports/lvs.log
tail -n 12 reports/lvs_negative.log
tail -n 12 reports/timing_negative.rpt
cat reports/summary.json
```

The observer requires an empty routing-DRC report, zero Magic DRC errors, unique LVS matching with VPWR/VGND retained, nonnegative extracted setup/hold slack and no reported electrical violations. Reset is explicitly excluded from timing; the setup-check warning for `preset_n` is documented, not silently removed. The scratch disconnected-Q reference must not match. The 1 ns analysis must have negative setup slack; it does not modify the saved 20 ns implementation constraints.

## 6. Troubleshooting

| Symptom | Check and next action |
|---|---|
| Bambu acquisition fails | Inspect the acquisition log; normal pinned artifact acquisition is required before HLS. No generated-core substitute is permitted |
| C reference cannot compile | Check host GCC and the freestanding unsigned-char kernel; do not change expected vectors to match an error |
| Missing `build/hls/sobel3x3.v` | Run actual `hls` before core/APB/synthesis |
| Gate simulation port mismatch | Use the named APB port connections in the supplied testbench; routed declarations may be reordered |
| Missing supply pin / LVS mismatch | Inspect the DEF-to-GDS pin map and actual extraction, including metal-5 names; keep power/body pins in the comparison |
| Setup passes but electrical/hold check fails | Inspect extracted reports; all required checks must pass before treating the candidate as verified |
| Magic cannot load its technology/runtime | Check PDK completeness, native dependencies and `CAD_ROOT` |
| Observer lacks KLayout | Use the explicit Python environment prepared above |

## 7. Open the whitepaper and check the public Git candidate

Windows PowerShell, from the repository root:

```powershell
Invoke-Item .\docs\Sobel_HLS_APB_SKY130_Ignytion_A4.pdf
Invoke-Item .\docs\Sobel_HLS_APB_SKY130_Ignytion_A4.pptx
.\.venv-win\Scripts\python.exe scripts\preflight_git.py
```

The preflight script uses Python's standard library, so `python scripts/preflight_git.py` also works in an existing Python environment. It checks documentation links, the exact document hashes, indexed/unignored paths, shell index modes, selected credential/personal-path patterns and Git whitespace. This is a public-candidate check; it does not rerun EDA tools.

Linux/WSL Git review, after reviewing the files selected by the repository allowlist:

```bash
git status --short
git diff --check
git add -- .
git diff --cached --check
python3 scripts/preflight_git.py
git diff --cached --stat
git diff --cached
```

Do not force-add ignored build products, PDK/runtime payloads, raw logs, local configuration or agent/work notes. The repository contains no invented project-wide licence grant; upstream dependencies retain their own terms.

The following are **manual commit/publication commands**, not steps already performed by this project. Review the staged content and choose your own author identity and public destination first. Run `remote add` only when this repository has no `origin`:

```bash
git branch --show-current
git config user.name
git config user.email
git commit -m "Add verified HLS_Sobel demonstration and whitepaper"
PUBLIC_REPOSITORY_URL='REPLACE_WITH_YOUR_PUBLIC_REPOSITORY_URL'
git remote add origin "$PUBLIC_REPOSITORY_URL"
git push -u origin HEAD
```

Replace the destination placeholder before use. A new package is staged on `demo/verified`; the branch command confirms the actual current branch. If `origin` already exists, inspect it with `git remote get-url origin` and skip `remote add`. No commit, remote mutation or push is performed by the reproduction scripts.

## Files and limits

`src/` holds the C kernel; `rtl/` holds the port adapter and APB wrapper; `tests/` contains the core/APB observers; `reference/` retains the frozen vectors. `scripts/` implements HLS, synthesis, physical flow, extraction, controls and final verification. The DEF floorplan target is 180 by 180 micrometres; top-level GDS instance counts also include physical/via instances and should not be read as logic-cell counts.

Excluded from the demonstrated scope: image line buffers, DMA/video timing, exhaustive APB compliance, exhaustive equivalence, SDF simulation, other PVT/RC corners, reset recovery/removal/distribution, antenna/density/IR/EM signoff, pad/ESD design, physical FPGA operation and fabricated silicon. Local DRC/LVS and GDS generation do not establish tapeout readiness.
