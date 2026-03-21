# 📖 Complete Guide: 8-bit Synchronous FIFO on Spartan-6 FPGA
### From First Principles to Hardware Implementation

---

## PART 1 — What is a FIFO?

### The Concept

**FIFO** stands for **First-In, First-Out**. It is a type of memory buffer where the **first piece of data you store is the first piece you get back** — exactly like a queue at a ticket counter.

Imagine pushing tennis balls into one end of a tube. The ball you push in first is the first one to come out the other end. That is exactly how a FIFO works.

```
 WRITE END                              READ END
 (Producer)                             (Consumer)
    │                                       │
    ▼                                       ▼
  [AA] ──► [AA][BB][CC] ──► [AA][BB][CC] ──► [AA]
  push BB       push CC          pop →  reads AA first
```

### Why Do We Need FIFOs?

FIFOs solve one of the most fundamental problems in digital design: **two parts of a system that produce and consume data at different rates or different times need a buffer between them.**

Real-world examples:
- **UART communication**: Characters arrive from a keyboard faster than the CPU can process them. A FIFO holds them temporarily.
- **USB controllers**: Data bursts from a USB device are buffered in FIFOs before being transferred to system memory.
- **Audio systems**: Audio samples are buffered in a FIFO between the ADC and the processor to prevent dropouts.
- **GPU pipelines**: Data between pipeline stages is queued in FIFOs.

### Synchronous vs Asynchronous FIFO

| Feature | Synchronous FIFO | Asynchronous FIFO |
|---------|-----------------|-------------------|
| Clocks | **Single shared clock** | Two independent clocks |
| Complexity | Simple | Complex (Gray-code pointers needed) |
| Use case | Same clock domain | Clock Domain Crossing (CDC) |
| This project | ✅ This is what we built | — |

---

## PART 2 — The Mathematical Model

### Depth and Width

A FIFO is characterised by:
- **Width**: How many bits does each "slot" hold? (This project: **8 bits** = 1 byte)
- **Depth**: How many slots exist? (This project: **16 slots**, because `ADDR_WIDTH = 4` → 2⁴ = 16)

So this FIFO can hold up to **16 bytes** at one time.

### Full and Empty Flags

We need a way to know:
1. Is the FIFO **full**? (Can I write more data?)
2. Is the FIFO **empty**? (Is there any data to read?)

This project uses an **item count** approach — we keep a counter of how many items are currently in the FIFO:

```
empty = (item_count == 0)
full  = (item_count == FIFO_DEPTH)     // FIFO_DEPTH = 16
```

Each write increments `item_count`. Each read decrements it.

**Why 5 bits for item_count when ADDR_WIDTH is 4?**
Because `item_count` must represent values from 0 to **16** (not 0 to 15). A 4-bit register can only hold 0–15. So we use 5 bits: `reg [4:0] item_count` — this is a subtle but critical detail.

---

## PART 3 — The Implementation

### Module Hierarchy

```
top_fifo.v   ← You interact with this (buttons and LEDs)
├── debounce.v × 2  ← Cleans up noisy button signals
└── fifo_sync.v     ← The actual FIFO memory core
```

---

## PART 4 — Module 1: `fifo_sync.v` (The Heart)

### Complete Code with Line-by-Line Explanation

```verilog
module fifo_sync #(
    parameter DATA_WIDTH = 8,   // Each slot stores 8 bits (1 byte)
    parameter ADDR_WIDTH = 4    // 4-bit address → 2^4 = 16 slots deep
)
(
    input               clk,    // System clock (50 MHz from board)
    input               rst_n,  // Active-LOW reset (0 = reset, 1 = normal)
    input               wr_en,  // Write Enable: 1 = write w_data into FIFO
    input  [7:0]        w_data, // 8-bit data to write
    output              full,   // 1 = FIFO is full, don't write!
    input               rd_en,  // Read Enable: 1 = pop next item from FIFO
    output reg [7:0]    r_data, // 8-bit data that was read out
    output              empty   // 1 = FIFO is empty, don't read!
);
```

**Parameters** let us reuse this module with different sizes. Change `ADDR_WIDTH` to 8 and you instantly get a 256-deep FIFO without touching any logic.

```verilog
    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;   // = 16
```
`1 << 4` means "shift binary 1 left by 4 places" = `10000` in binary = **16** in decimal.

```verilog
    reg [DATA_WIDTH-1:0] mem [FIFO_DEPTH-1:0];
```
This declares a **2D register array** — the actual physical memory.
Think of it as: `mem` is a table with 16 rows, and each row holds 8 bits.

```verilog
    reg [ADDR_WIDTH-1:0] wr_ptr;    // 4-bit write pointer (0 to 15)
    reg [ADDR_WIDTH-1:0] rd_ptr;    // 4-bit read pointer (0 to 15)
    reg [ADDR_WIDTH:0]   item_count; // 5-bit count (0 to 16)
```

The pointers work like subscripts. `mem[wr_ptr]` is the slot we'll write into next. `mem[rd_ptr]` is the slot we'll read from next.

```verilog
    assign full  = (item_count == FIFO_DEPTH);  // == 16
    assign empty = (item_count == 0);
```
These are **combinational wires** — they update **instantly** whenever `item_count` changes, without waiting for a clock edge.

### The Main Always Block — Where Everything Happens

```verilog
    always @(posedge clk or negedge rst_n) begin
```
This block runs **every time the clock rises** (0→1 transition), OR whenever `rst_n` falls LOW (button pressed = reset).

```verilog
        if (!rst_n) begin
            // RESET CONDITION: Force everything to known zero state
            wr_ptr     <= 0;
            rd_ptr     <= 0;
            item_count <= 0;
            r_data     <= 0;
        end else begin
```

When reset is asserted: all pointers go to slot 0, count → 0, output → 0. The FIFO is now completely fresh.

```verilog
            // --- WRITE OPERATION ---
            if (wr_en && !full) begin
                mem[wr_ptr] <= w_data;      // Store incoming data
                wr_ptr      <= wr_ptr + 1;  // Advance write pointer
                item_count  <= item_count + 1;
            end
```

The guard `!full` is critical — if the FIFO were full, a write would overwrite existing data, corrupting it. The condition `wr_en && !full` means "only write if requested AND there is space."

Notice the write pointer has no special "wrap" code. Because `wr_ptr` is 4-bits wide and can only hold 0–15, when it reaches 15 and gets incremented, it naturally wraps from `1111` → `0000` in binary. **The overflow of the 4-bit register IS the wrap-around.**

```verilog
            // --- READ OPERATION ---
            if (rd_en && !empty) begin
                r_data     <= mem[rd_ptr];  // Fetch from memory
                rd_ptr     <= rd_ptr + 1;   // Advance read pointer
                item_count <= item_count - 1;
            end
```

Similarly, `!empty` guards against reading garbage from an empty FIFO. `r_data` is a **registered output** — it takes one clock cycle for the data to appear after `rd_en` is asserted. This is deliberate: it eliminates glitches on the LED outputs.

### Visual Walkthrough (Write AA, BB, CC then Read)

**Step 1: Initial State (after reset)**
```
mem: [--][--][--]...[--]   (16 empty slots)
wr_ptr = 0, rd_ptr = 0, item_count = 0
empty=1, full=0
```

**Step 2: wr_en=1, w_data=0xAA**
```
mem: [AA][--][--]...[--]
wr_ptr = 1, rd_ptr = 0, item_count = 1
empty=0, full=0
```

**Step 3: wr_en=1, w_data=0xBB**
```
mem: [AA][BB][--]...[--]
wr_ptr = 2, rd_ptr = 0, item_count = 2
```

**Step 4: wr_en=1, w_data=0xCC**
```
mem: [AA][BB][CC][--]...[--]
wr_ptr = 3, rd_ptr = 0, item_count = 3
```

**Step 5: rd_en=1 → reads mem[0] = 0xAA**
```
mem: [AA][BB][CC][--]...[--]  (AA remains in memory, but pointer moved past it)
wr_ptr = 3, rd_ptr = 1, item_count = 2
r_data = 0xAA (appears on next clock)
```

**Step 6: rd_en=1 → reads mem[1] = 0xBB**
```
r_data = 0xBB (FIFO order preserved ✅)
```

---

## PART 5 — Module 2: `debounce.v` (The Noise Filter)

### Why Debouncing is Essential

Mechanical push buttons don't press cleanly. Under a microscope of time (microseconds), pressing a button looks like this:

```
Ideal:    ───────────╔══════════╗──────────
                     │          │
                     press      release

Reality:  ───────────╔╗╔╗╔═════╗╗╔╗──────
                   bouncing!  bouncing!
```

Each bounce appears as a separate press to digital logic. Without debouncing, one button press could trigger **dozens** of FIFO writes — completely destroys the design.

### The 2-Stage Synchronizer

```verilog
    reg sync_ff1, sync_ff2;
    always @(posedge clk or negedge rst_n) begin
        sync_ff1 <= noisy_in;   // First flip-flop
        sync_ff2 <= sync_ff1;   // Second flip-flop
    end
```

**The problem it solves — Metastability:**
When an asynchronous signal (the button) is sampled by a flip-flop, the FF might catch the signal right at the transition between 0 and 1. The FF output can then settle to a random voltage — neither 0 nor 1 — and propagate as garbage through the circuit. This is called **metastability**.

The fix: use **two flip-flops in series**. If the first FF goes metastable, it resolves (settles to 0 or 1) within one clock cycle due to the exponential nature of the settling process. By the time `sync_ff2` samples `sync_ff1`, the signal is always clean.

After this two-stage filter, we use `sync_ff2` everywhere.

### The Counter-Based Stability Checker

```verilog
    if (sync_ff2 == debounced_signal_reg) begin
        counter <= 0;                  // Signal stable = keep resetting counter
    end else begin
        counter <= counter + 1;        // Signal changing = keep counting
    end

    if (&counter) begin                // All bits = 1 means counter overflowed
        debounced_signal_reg <= sync_ff2;  // NOW commit the new value
    end
```

The `&counter` (reduction AND) is true only when ALL 20 bits of the counter are 1 — that requires the signal to have been consistently different from the confirmed value for **2²⁰ = 1,048,576 clock cycles = ~20.97 ms**. Only after this long stability period do we "believe" the button changed.

### Edge Detection (Generating a Single Pulse)

```verilog
    prev_debounced_signal <= debounced_signal_reg;
    debounced_pulse <= debounced_signal_reg & ~prev_debounced_signal;
```

We only want to write **once** per button press — not continuously for as long as the button is held. This detects the **rising edge**: the output is HIGH only for **exactly one clock cycle** at the moment the debounced signal transitions 0→1.

```
debounced_signal:  ────────╔══════════════╗────────
prev_debounced:    ─────────────╔══════════════╗───
debounced_pulse:   ─────────────╔═╗─────────────────
                              (ONE cycle only)
```

---

## PART 6 — Module 3: `top_fifo.v` (The Integration Layer)

This module connects everything to the physical world. It does three things:

### 1. Power-On Reset (POR) Circuit

```verilog
reg [7:0] pwr_on_rst_counter = 8'h00;
always @(posedge clk_50mhz) begin
    if (pwr_on_rst_counter != 8'hFF)
        pwr_on_rst_counter <= pwr_on_rst_counter + 1;
end
wire master_rst_n = (pwr_on_rst_counter == 8'hFF) && rst_n_internal;
```

When the FPGA first powers up, the supply voltage ramps up slowly, and flip-flops can start in random states. The POR circuit holds `master_rst_n = 0` (reset active) for **256 clock cycles ≈ 5.12 µs** to guarantee all FFs start at zero before any operation begins.

After 256 cycles, `pwr_on_rst_counter == 8'hFF` becomes true, and `master_rst_n` is handed over to the user's reset button.

### 2. Three Debounce Instances

```verilog
debounce #(.COUNTER_WIDTH(20)) DEBOUNCE_WRITE (
    .clk(clk_50mhz),  .rst_n(master_rst_n),
    .noisy_in(wr_btn), .debounced_pulse(wr_en_pulse)
);
```

One debounce module for Write, one for Read. Each takes its noisy button input and returns a clean single-cycle pulse ready to be used as `wr_en` and `rd_en` for the FIFO core.

### 3. FIFO Core and LED Connections

```verilog
fifo_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(4)) FIFO_CORE_INST (
    .clk(clk_50mhz),      .rst_n(master_rst_n),
    .wr_en(wr_en_pulse),   .w_data(sw_data),
    .full(fifo_full_w),    .rd_en(rd_en_pulse),
    .r_data(fifo_r_data_w),.empty(fifo_empty_w)
);
assign led_data  = fifo_r_data_w;
assign led_full  = fifo_full_w;
assign led_empty = fifo_empty_w;
```

The 8 LEDs directly show the last-read byte in binary. The two status LEDs light up when the FIFO is full or empty.

---

## PART 7 — The UCF File (Pinout / Constraints)

The `.ucf` (User Constraints File) is like a **wiring diagram** — it tells the Xilinx ISE tools which physical FPGA pin connects to which signal in your Verilog code.

```ucf
NET "clk_50mhz"  LOC = "P84";    // Pin P84 connects to a 50MHz crystal
NET "wr_btn"     LOC = "P41";    // Pin P41 is a push button
NET "sw_data<0>" LOC = "P22";    // Pin P22 connects to slide switch 0
NET "led_data<0>" LOC = "P33";   // Pin P33 drives LED 0
NET "led_full"   LOC = "P139";   // Status LED
```

The timing constraint:
```ucf
TIMESPEC "TS_sys_clk" = PERIOD "sys_clk" 20 ns HIGH 50%;
```
This tells the synthesis tools "the clock must complete a full cycle every 20 ns (= 50 MHz)." ISE uses this to verify that all combinational paths between flip-flops fit within 20 ns — this is called **Static Timing Analysis (STA)**.

---

## PART 8 — The Testbench: `tb_fifo.v`

A testbench is a Verilog file that **has no hardware output** — it exists purely in simulation. It acts like a virtual test engineer, pressing buttons and checking outputs.

### Why We Test fifo_sync Directly (Not top_fifo)

The debounce filter requires ~20 ms of stable input before it passes a pulse. In simulation, we don't want to simulate 1,048,576 clock cycles just to trigger one write. Instead, we test the FIFO core directly — this is called **unit testing**.

### The Test Cases

| Test | What it Checks |
|------|----------------|
| 1. Reset | empty=1, full=0 after reset |
| 2. Write→Read ordering | 0xAA, 0xBB, 0xCC come back in FIFO order |
| 3. Fill to full | full=1 after 16 writes |
| 4. Overflow guard | 17th write is silently ignored |
| 5. Underflow guard | Read on empty FIFO does not corrupt r_data |
| 6. Simultaneous R/W | item_count stays correct when both happen same cycle |

### Self-Checking Mechanism

Instead of you reading waveforms manually, the testbench automatically compares:
```verilog
if (r_data === expected) begin
    $display("[PASS] ...");
    pass_count = pass_count + 1;
end else begin
    $display("[FAIL] ...");
    fail_count = fail_count + 1;
end
```
At the end it prints: `RESULTS: 12 PASSED, 0 FAILED`

---

## PART 9 — Complete Data Flow (End to End)

Here is what happens physically when you press the **Write Button** on the board:

```
PHYSICAL WORLD
User sets switches to 0b10110011 (= 0xB3)
User presses Write Button

FPGA INTERNAL LOGIC (cycle by cycle at 50 MHz):

Cycles 1–2:      sync_ff1 ← 1 (button HIGH captured by first synchronizer FF)
                 sync_ff2 ← 1 (second FF confirms clean HIGH)

Cycles 3–20ms:   Stability counter counts up to 2^20 = 1,048,576
                 (this is the 20ms debounce window)

                 If button bounces back to 0 during this time:
                    → counter resets to 0 (bounce filtered out)

Cycle 1,048,577: &counter = 1 → debounced_signal_reg ← 1
                 (button state committed)

Next cycle:      debounced_pulse = debounced_signal_reg & ~prev
                 = 1 & ~0 = 1
                 → wr_en_pulse = HIGH for exactly ONE clock cycle

FIFO CORE:
Same cycle (wr_en=1, full=0):
    mem[wr_ptr] ← sw_data (= 0xB3 stored in FIFO memory)
    wr_ptr ← wr_ptr + 1
    item_count ← item_count + 1

LEDS:
    led_full  updates immediately (combinational assign)
    led_empty updates immediately
    led_data  remains unchanged (only updates on READ)
```

---

## PART 10 — KEY CONCEPTS SUMMARY TABLE

| Concept | What It Is | Where in Code |
|---------|------------|---------------|
| FIFO | First-In-First-Out buffer | `fifo_sync.v` |
| Write pointer | Points to next empty slot | `wr_ptr` in `fifo_sync.v` |
| Read pointer | Points to oldest filled slot | `rd_ptr` in `fifo_sync.v` |
| Item count | Tracks how many items are in FIFO | `item_count` in `fifo_sync.v` |
| Full flag | `item_count == FIFO_DEPTH` | `assign full` |
| Empty flag | `item_count == 0` | `assign empty` |
| Registered output | r_data clocked, not combinational | `output reg r_data` |
| Pointer wrap-around | 4-bit natural overflow | automatic in Verilog |
| Metastability | Undefined logic state from async signal | `sync_ff1, sync_ff2` |
| Two-stage sync | Fixes metastability | `debounce.v` lines 20–29 |
| Debounce window | 2^20 cycles @ 50MHz = ~21ms | `COUNTER_WIDTH=20` |
| Rising edge detect | `signal & ~prev_signal` | `debounced_pulse` logic |
| Power-on reset | Forces known state at powerup | `pwr_on_rst_counter` |
| Active-LOW reset | 0=reset, 1=normal | `rst_n` naming convention |
| UCF | Maps Verilog names to physical pins | `top_fifo.ucf` |
| Timescale | Simulation time units | `` `timescale 1ns/1ps `` |
| Unit testing | Testing one module in isolation | `tb_fifo.v` tests `fifo_sync` |

---

*This document was created as a comprehensive reference for the Spartan6-Synchronous-FIFO project.*
*Last updated: 2026-03-19*
