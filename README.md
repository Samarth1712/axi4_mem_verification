# AXI4 SRAM Verification Environment

UVM-lite constrained-random verification of a custom AXI4 SRAM controller,
targeting coverage closure across protocol correctness, data integrity,
boundary conditions, and burst behaviour.

---

## Repository Structure

```
axi4_mem_verif/
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
    ├── run.tcl               # Simulator control TCL
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

## Running

### Prerequisites
- Cadence Xcelium with UVM 1.2
- Set `UVM_HOME` if your path differs from the default in `run.sh`

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

### Default (regression)
```bash
./run.sh
```

### View coverage in IMC
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
