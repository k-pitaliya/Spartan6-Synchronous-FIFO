# Spartan-6 Synchronous FIFO – RTL Design & UVM Verification

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Language: SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-orange.svg)]()
[![UVM: 1.2](https://img.shields.io/badge/UVM-1.2-green.svg)]()
[![FPGA: Spartan-6](https://img.shields.io/badge/FPGA-Spartan--6-red.svg)]()

A complete **RTL-to-verification** project featuring:
- Parameterized synchronous FIFO design in **Verilog HDL**
- Industry-standard **UVM 1.2** testbench environment (full env/agent/driver/monitor/scoreboard/coverage)
- **SVA assertion** suite embedded in the interface
- **FPGA synthesis** on Xilinx Spartan-6
- Automated simulation flow via **GNU Makefile**

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [DUT Interface](#dut-interface)
5. [UVM Testbench Architecture](#uvm-testbench-architecture)
6. [Sequences & Tests](#sequences--tests)
7. [SVA Assertions](#sva-assertions)
8. [Functional Coverage](#functional-coverage)
9. [Running on EDA Playground](#running-on-eda-playground)
10. [Running Locally (ModelSim/QuestaSim)](#running-locally-modelsimquestasim)
11. [FPGA Synthesis](#fpga-synthesis)
12. [Key Results](#key-results)

---

## Project Overview

| Parameter | Value |
|-----------|-------|
| Design | Synchronous FIFO (single-clock domain) |
| Data Width | 8-bit (parameterized) |
| Address Width | 4-bit → FIFO Depth: 16 entries (parameterized) |
| Full/Empty Flags | Item-count–based (glitch-free) |
| Target FPGA | Xilinx Spartan-6 (XC6SLX9) |
| Verification | UVM 1.2, Constrained-Random, SVA |
| EDA Tools | ModelSim / QuestaSim / EDA Playground |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    fifo_sync (DUT)                          │
│                                                             │
│   wr_en ──►┌───────────┐     ┌───────────┐◄── rd_en        │
│   w_data──►│  Write    │     │  Read     │──► r_data        │
│            │  Logic    │     │  Logic    │                  │
│            └─────┬─────┘     └─────┬─────┘                 │
│                  │                 │                        │
│            wr_ptr│           rd_ptr│                        │
│                  ▼                 ▼                        │
│           ┌──────────────────────────┐                      │
│           │   mem[FIFO_DEPTH-1:0]    │  (Register Array)   │
│           └──────────────────────────┘                      │
│                                                             │
│   item_count ──► full / empty flags                         │
└─────────────────────────────────────────────────────────────┘
```

**Key Design Decisions:**
- `item_count` register (not Gray-code comparison) for clean flag logic
- `r_data` is registered (clocked output) — no combinational read path
- Simultaneous read+write supported when not empty/full

---

## Directory Structure

```
Spartan6-Synchronous-FIFO/
│
├── src/                        # RTL Design Files
│   ├── fifo_sync.v             # ← Main DUT: Parameterized Synchronous FIFO
│   ├── tb_fifo.v               # Legacy directed testbench (Verilog)
│   ├── top_fifo.v              # FPGA top-level wrapper (7-segment display)
│   ├── debounce.v              # Button debounce module for FPGA board
│   └── top_fifo.ucf            # Xilinx constraint file (pin assignments)
│
├── uvm_tb/                     # UVM 1.2 Testbench Environment
│   ├── fifo_if.sv              # Interface (clocking blocks + SVA assertions)
│   ├── fifo_seq_item.sv        # Transaction / Sequence Item
│   ├── fifo_sequences.sv       # 6 Sequences (reset, fill, drain, R+W, random, stress)
│   ├── fifo_driver.sv          # UVM Driver
│   ├── fifo_monitor.sv         # UVM Monitor (passive observer)
│   ├── fifo_scoreboard.sv      # Self-checking scoreboard (golden model)
│   ├── fifo_coverage.sv        # Functional coverage collector
│   ├── fifo_agent.sv           # UVM Agent (bundles driver+monitor+sequencer)
│   ├── fifo_env.sv             # UVM Environment
│   ├── fifo_test.sv            # 3 UVM Tests (directed, random, stress)
│   ├── tb_top.sv               # Top-level testbench module (local sim)
│   ├── edaplayground_FULL_TB.sv # ← Single-file TB for EDA Playground
│   └── Makefile                # Compile / Sim / Coverage automation
│
└── docs/                       # Documentation
    ├── SELF_CHECKING_TESTBENCH_GUIDE.md
    ├── DV_UPGRADE_GUIDE.md
    └── PROJECT_EXPLAINED.md
```

---

## DUT Interface

```verilog
module fifo_sync #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4       // FIFO Depth = 2^ADDR_WIDTH = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,    // Active-low synchronous reset
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  w_data,
    output wire                   full,
    input  wire                   rd_en,
    output reg  [DATA_WIDTH-1:0]  r_data,
    output wire                   empty
);
```

---

## UVM Testbench Architecture

```
                    ┌────────────────────────────────────┐
                    │          fifo_env                  │
                    │                                    │
                    │  ┌──────────────────────────────┐  │
                    │  │        fifo_agent            │  │
                    │  │                              │  │
                    │  │  ┌────────┐  ┌───────────┐  │  │
  Sequences ───────────►  │ seqr   │  │  driver   │──┼──┼──► DUT
                    │  │  └────────┘  └───────────┘  │  │
                    │  │                              │  │
                    │  │              ┌───────────┐   │  │
  DUT outputs ──────────────────────►│  monitor  │   │  │
                    │  │              └─────┬─────┘   │  │
                    │  └────────────────────┼─────────┘  │
                    │        analysis_port  │             │
                    │            ┌──────────┴──────────┐  │
                    │            │                     │  │
                    │    ┌───────▼──────┐   ┌──────────▼─┐│
                    │    │ scoreboard   │   │  coverage  ││
                    │    │ (ref model)  │   │ collector  ││
                    │    └──────────────┘   └────────────┘│
                    └────────────────────────────────────┘
```

| Component | File | Role |
|-----------|------|------|
| `fifo_if` | `fifo_if.sv` | Interface with clocking blocks + SVA |
| `fifo_seq_item` | `fifo_seq_item.sv` | Constrained-random transaction |
| `fifo_driver` | `fifo_driver.sv` | Drives transactions onto DUT pins |
| `fifo_monitor` | `fifo_monitor.sv` | Passively samples DUT, broadcasts via AP |
| `fifo_scoreboard` | `fifo_scoreboard.sv` | SV-queue reference model, self-checking |
| `fifo_coverage` | `fifo_coverage.sv` | Functional coverage collection |
| `fifo_agent` | `fifo_agent.sv` | Active agent (driver+monitor+sequencer) |
| `fifo_env` | `fifo_env.sv` | Top-level environment |

---

## Sequences & Tests

### Sequences (in `fifo_sequences.sv`)

| Sequence | Purpose |
|----------|---------|
| `fifo_reset_seq` | 5-cycle idle / reset sanity |
| `fifo_fill_seq` | Write until FULL (corner case) |
| `fifo_drain_seq` | Read until EMPTY (corner case) |
| `fifo_sim_rw_seq` | Simultaneous read+write (32 cycles) |
| `fifo_rand_seq` | 500 constrained-random transactions |
| `fifo_stress_seq` | 10× fill → sim-RW → drain cycles |

### Tests (in `fifo_test.sv`)

| Test | Sequences Run | Coverage Target |
|------|--------------|-----------------|
| `fifo_directed_test` | reset → fill → sim-RW → drain | Corner cases |
| `fifo_rand_test` | 500 random transactions | Broad coverage sweep |
| `fifo_stress_test` | 10 fill-drain stress cycles | Flag transition coverage |

---

## SVA Assertions

Three SVA properties are synthesized directly into the interface (`fifo_if.sv`):

```systemverilog
// 1. Writing when FULL must not increase fill level
property p_no_write_when_full;
    @(posedge clk) disable iff (!rst_n)
    (full && wr_en) |=> full;
endproperty

// 2. Reading when EMPTY must not decrease fill level
property p_no_read_when_empty;
    @(posedge clk) disable iff (!rst_n)
    (empty && rd_en) |=> empty;
endproperty

// 3. Post-reset: must be empty and not full
property p_reset_state;
    @(posedge clk) $fell(rst_n) |=> (!full && empty);
endproperty
```

> These assertions **caught 2 flag logic bugs** during development before synthesis.

---

## Functional Coverage

Coverage groups defined in `fifo_coverage.sv`:

| Covergroup | Coverpoints | Description |
|-----------|-------------|-------------|
| `cg_operations` | op_type, full, empty | All 4 operation types × flag states |
| `cg_data_values` | w_data boundaries | Zero, max, low/mid/high ranges |
| `cg_flag_transitions` | full/empty rise/fall | Fill and drain edge detection |
| Cross coverage | op_type × full, op_type × empty | Operations under boundary conditions |

**Coverage Result:** `>95%` functional coverage achieved with `fifo_stress_test`
*(Run `make coverage` and check the `COVERAGE SUMMARY` printout)*

---

## Running on EDA Playground

> **Fastest way to run — no install required**

1. Go to **[edaplayground.com](https://edaplayground.com)** (free account)
2. Settings → Simulator: `Aldec Riviera-PRO` | UVM/OVM: `UVM 1.2`
3. **Left panel (Design):** paste contents of `src/fifo_sync.v`
4. **Right panel (Testbench):** paste contents of `uvm_tb/edaplayground_FULL_TB.sv`
5. Click **Run**
6. Change test by editing this line in `tb_top`:
    ```systemverilog
    run_test("fifo_directed_test");   // or fifo_rand_test / fifo_stress_test
    ```

---

## Running Locally (ModelSim/QuestaSim)

```bash
cd uvm_tb/

# Run directed corner-case test
make all

# Run constrained-random test (500 transactions)
make sim TEST=fifo_rand_test

# Run stress test (10 fill-drain cycles)
make sim TEST=fifo_stress_test

# Run with code + functional coverage and generate HTML report
make coverage TEST=fifo_stress_test
make report

# Clean all build artifacts
make clean
```

---

## FPGA Synthesis

- **Tool:** Xilinx ISE 14.7
- **Device:** Spartan-6 XC6SLX9 (Nexys 3 / equivalent board)
- **Top-level:** `top_fifo.v` (includes 7-segment display output and button debounce)
- **Constraints:** `top_fifo.ucf`

The FPGA demo allows interactive push-button write/read operations with the current FIFO state (full, empty, data) displayed on the 7-segment display.

---

## Key Results

| Metric | Result |
|--------|--------|
| Functional Coverage | >95% (stress test) |
| SVA Assertion Failures Caught | 2 flag logic bugs pre-synthesis |
| Scoreboard Mismatches | 0 (all tests pass) |
| FPGA Synthesis | Timing closure achieved, Spartan-6 |
| Test Corpus | 500+ constrained-random + directed corner cases |

---

## Author

**Kushal Pitaliya** — Electronics & Communication Engineering, CHARUSAT  
[LinkedIn](https://linkedin.com/in/kushalpitaliya06) | [GitHub](https://github.com/KushalPitaliya)
