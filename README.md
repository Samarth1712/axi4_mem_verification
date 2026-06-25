# AXI4 SRAM Verification Environment

UVM-lite constrained-random verification of a custom AXI4 SRAM controller,
targeting coverage closure across protocol correctness, data integrity,
boundary conditions, and burst behaviour.

---

## Repository Structure

```
axi4_mem_verification/
├── rtl/
│   └── axi4_sram.sv          # DUT: AXI4 slave SRAM controller (32-bit, 4KB)
├── tb/
│   ├── intf/
│   │   └── axi4_if.sv        # AXI4 interface + SVA protocol assertions
│   ├── pkg/
│   │   ├── axi4_pkg.sv       # Transaction item, constraints, coverage group
│   │   ├── axi4_driver.sv    # UVM driver (master-side stimulus)
│   │   ├── axi4_monitor.sv   # UVM monitor (passive bus observer)
│   │   ├── axi4_scoreboard.sv# Reference model + checker
│   │   ├── axi4_agent_env.sv # Agent and Environment
│   │   ├── axi4_sequences.sv # All sequences (rand, wr/rd, boundary, burst, strobe, bb)
│   │   └── axi4_tests.sv     # All test classes
│   └── top/
│       └── tb_top.sv         # Top-level: DUT instantiation, clock gen, UVM kickoff
└── sim/
    ├── run.sh                # Xcelium compile + run script
    ├── run.tcl               # Batch-mode simulator control TCL (auto-exits)
    ├── run_gui.tcl           # GUI-mode TCL: opens waveform DB, probes all signals
    └── merge_cov.tcl         # IMC coverage merge + report
```

---

## DUT

`axi4_sram.sv` — 32-bit AXI4 slave with:
- 4KB SRAM (1024 × 32-bit words)
- FIXED and INCR burst support (up to 16 beats)
- Byte-level write strobes
- SLVERR on out-of-bounds access
- Separate write (AW/W/B) and read (AR/R) FSMs

---

## SVA Assertions (in `axi4_if.sv`)

| Category            | Assertions                                              |
|---------------------|---------------------------------------------------------|
| Reset               | AWVALID, WVALID, ARVALID, BVALID, RVALID = 0 in reset  |
| Handshake stability | VALID stays high until READY seen (all 5 channels)      |
| Sideband stability  | AWADDR, AWID, AWLEN, WDATA, WSTRB, WLAST stable pre-hs  |
| Response legality   | BRESP, RRESP ∈ {OKAY, SLVERR}                           |
| No X/Z              | AWADDR, ARADDR, WSTRB free of unknowns during VALID     |
| Burst type          | AWBURST, ARBURST ∈ {FIXED, INCR}                        |
| Burst size          | AWSIZE, ARSIZE ≤ 2 (bus width = 32-bit)                 |

---

## Test Suite

| Test                    | What it does                                              |
|-------------------------|-----------------------------------------------------------|
| `axi4_smoke_test`       | Single write/read pair                                    |
| `axi4_integrity_test`   | 50 write-then-read-back pairs, scoreboard checks all      |
| `axi4_boundary_test`    | Last valid address, first OOB address (SLVERR expected)   |
| `axi4_max_burst_test`   | 16-beat INCR bursts                                       |
| `axi4_strobe_test`      | Partial byte-enable writes                                |
| `axi4_bb_test`          | Back-to-back single-beat handshakes                       |
| `axi4_rand_test`        | 100 fully constrained-random transactions                 |
| `axi4_regression_test`  | All of the above in sequence                              |

---

## Coverage Model (`axi4_pkg.sv`)

| Coverpoint       | Bins                                              |
|------------------|---------------------------------------------------|
| Direction        | write, read                                       |
| Burst type       | FIXED, INCR                                       |
| Burst length     | single, short(1-3), mid(4-7), long(8-14), max(15) |
| Address region   | zero-page, mid-range, near-top, OOB               |
| Write strobe     | full, partial, none                               |
| Crosses          | dir×type, dir×length, dir×address                 |

---

## Machine-specific setup
Xcelium's UVM install path differs by machine. Before running anything:

1. Find where Xcelium is installed:
```bash
   which xrun
```
   This prints something like `/home/install/XCELIUM2509/tools.lnx86/bin/xrun`.
   The install root is everything before `tools...` — in this example, `/home/install/XCELIUM2209`.

2. Search that root for the UVM SystemVerilog library (works in any shell):
```bash
   find /home/install/XCELIUM2509 -iname "uvm_macros.svh"
```
   Pick the result under the version your script expects (e.g. `.../UVM/CDNS-1.2/sv/src/uvm_macros.svh`).

3. Set `UVM_HOME` to the directory *containing* `src/` (i.e. drop the trailing `/src/uvm_macros.svh`) — so it ends in `.../sv`:

   **bash:**
```bash
   export UVM_HOME=/home/install/XCELIUM2509/tools.lnx86/methodology/UVM/CDNS-1.2/sv
```

   **tcsh/csh:**
```tcsh
   setenv UVM_HOME /home/install/XCELIUM2509/tools.lnx86/methodology/UVM/CDNS-1.2/sv
```

> **Note:** `setenv`/`export` only applies to your current terminal session.
> To avoid repeating this every time, add the `setenv` line to your `~/.cshrc`
> (tcsh) or the `export` line to your `~/.bashrc` (bash), then run
> `source ~/.cshrc` (or open a new terminal) once. If `UVM_HOME` is already
> set correctly, `run.sh` will use it automatically; if it's unset or
> invalid, `run.sh` will tell you exactly what's wrong instead of failing
> deep inside a compiler error.

---

## Running

### Prerequisites
- Cadence Xcelium with UVM 1.2
- Set `UVM_HOME` if your path differs from default in `run.sh` — see "Machine-specific setup" above

### Help
```bash
./run.sh -h
# or
./run.sh --help
```

### Single test
```bash
cd sim
chmod +x run.sh
./run.sh axi4_smoke_test
```

### All tests
```bash
./run.sh all
```
Runs all 8 tests sequentially, writes a per-test log/coverage DB under
`results/<test>/`, merges coverage at the end, and prints a summary table
showing each test's tool exit status and UVM_ERROR count.

> Tool status reflects whether `xrun` itself completed cleanly (compile/
> elaboration/crash-level). It does **not** by itself confirm the scoreboard
> passed — always also check the UVM_ERROR count column, and the
> `SCOREBOARD SUMMARY` inside each `results/<test>/run.log` for the real
> pass/fail verdict.

### Default (regression)
```bash
./run.sh
```

### Single test with live GUI (waveform debug)
```bash
cd sim
./run.sh axi4_smoke_test --gui
```
Opens SimVision with every signal already added to the waveform window, runs
the test, and stays open afterward for inspection. The waveform database is
also saved to `results/<test>/waves.shm` for later viewing.

> `--gui` only works on a single named test — not `all` or the default
> regression — since the GUI blocks until you close it.

### Viewing a saved waveform later (no re-simulation)
```bash
cd sim
simvision results/axi4_smoke_test/waves.shm
```

### Generate and view coverage in IMC
After running tests (`./run.sh all` or individually), merge the per-test
coverage databases:
```bash
cd sim
imc -exec merge_cov.tcl
```
This writes `results/merged.vdb` and a text summary to
`results/cov_summary.txt`. Then open it in the GUI:
```bash
imc -load results/merged.vdb
```

---

## Notes

- All TB classes are `include`d into `tb_top.sv` for Xcelium compatibility
- `axi4_pkg.sv` must be compiled before `tb_top.sv`
- The OOB constraints (`c_addr_oob`) are disabled by default and activated
  explicitly in `axi4_boundary_seq`
- Reference model in scoreboard uses an associative array — only written
  addresses are tracked; unwritten addresses return 0
