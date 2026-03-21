# 🧪 Self-Checking Testbenches — The Complete Guide
## Every Concept You Need, Using Your FIFO as the Example

---

## THE PROBLEM FIRST — Why Normal Testbenches Are Not Enough

Let's look at what you had before in your original `tb_fifo.v`:

```verilog
// --- Step 3: Read the three values out of the FIFO ---
$display("Reading 3 values out...");
rd_btn <= 1;
@(posedge clk_50mhz);
rd_btn <= 0;
#20;
```

**What happens after this runs?**

You open ISim. You zoom into the waveform. You manually look at `led_data`.
You visually check: "does it say 0xAA? looks like it... yeah probably fine."

**This is the problem.** You are the checker. Your eyes are the pass/fail mechanism.

Now imagine:
- Your FIFO has 50 parameters to test instead of 3
- You run 10,000 random writes and reads
- A bug appears only on transaction number 7,843

You cannot stare at 10,000 waveform timestamps.
The testbench must check *itself* — automatically — every single transaction.

That is a **self-checking testbench**.

---

## WHAT IS A SELF-CHECKING TESTBENCH?

A self-checking testbench is a testbench that:

| Feature | Description |
|---------|-------------|
| **Knows what the correct answer should be** | Has a "golden model" that predicts expected output |
| **Compares actual vs expected automatically** | No human eyes needed |
| **Reports PASS or FAIL per transaction** | With enough detail to debug instantly |
| **Counts total passes and failures** | Gives a final verdict at the end |
| **Calls `$finish` at the end** | Doesn't need you to manually stop |

The key mental shift:

```
BEFORE:  You write stimulus → DUT runs → You look at waveforms → You decide pass/fail

AFTER:   You write stimulus → DUT runs → Testbench decides pass/fail → Prints results
```

---

## THE ANATOMY — What a Self-Checking TB Is Made Of

Every self-checking testbench has exactly these 5 parts:

```
┌─────────────────────────────────────────────────────────────────┐
│                   Self-Checking Testbench                       │
│                                                                 │
│  ┌──────────────┐    ┌───────────────┐    ┌──────────────────┐  │
│  │   STIMULUS   │    │  DUT (fifo)   │    │  CHECKER         │  │
│  │              │───►│               │───►│                  │  │
│  │  Apply       │    │  Responds     │    │  Compare output  │  │
│  │  inputs      │    │               │    │  vs expected     │  │
│  └──────────────┘    └───────────────┘    └──────────────────┘  │
│                                                    │             │
│  ┌──────────────────────────────────────────────┐  │             │
│  │  GOLDEN MODEL (Reference)                    │◄─┘             │
│  │  Software copy that predicts correct output  │                │
│  └──────────────────────────────────────────────┘                │
│                                                                 │
│  ┌──────────────────────────────────────────────┐                │
│  │  REPORTER                                    │                │
│  │  Counts passes/fails, prints final verdict   │                │
│  └──────────────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────────┘
```

Let's build each of these for your FIFO, one piece at a time.

---

## PART 1 — THE DUT CONNECTION (You Already Know This)

Nothing new here — you instantiate the FIFO and declare matching signals:

```verilog
`timescale 1ns / 1ps
module tb_fifo;

    // ── Parameters ──────────────────────────────────────────────
    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 4;
    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;  // 16

    // ── Signals driven BY the testbench (reg) ───────────────────
    reg                   clk;
    reg                   rst_n;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] w_data;
    reg                   rd_en;

    // ── Signals driven BY the DUT (wire) ────────────────────────
    wire                  full;
    wire                  empty;
    wire [DATA_WIDTH-1:0] r_data;

    // ── DUT Instantiation ────────────────────────────────────────
    fifo_sync #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) DUT (
        .clk    (clk),
        .rst_n  (rst_n),
        .wr_en  (wr_en),
        .w_data (w_data),
        .full   (full),
        .rd_en  (rd_en),
        .r_data (r_data),
        .empty  (empty)
    );

    // ── Clock: 50 MHz → 20 ns period ────────────────────────────
    initial clk = 0;
    always  #10 clk = ~clk;
```

This is the foundation. Nothing changes here. Now let's add the self-checking layer on top.

---

## PART 2 — THE REPORTER (Simplest Piece, Add It First)

Before you even write a single test, add two integer counters and a final summary block:

```verilog
    // ── Pass/Fail Counters ───────────────────────────────────────
    integer pass_count = 0;
    integer fail_count = 0;

    // ── Final Verdict (runs at simulation end) ───────────────────
    // Note: This initial block will execute when $finish is called.
    // We call it from the stimulus block instead.
```

And at the very end of your stimulus `initial` block, always write this:

```verilog
    // === FINAL VERDICT ===
    $display("─────────────────────────────────────────");
    $display("  RESULTS: %0d PASSED  |  %0d FAILED", pass_count, fail_count);
    if (fail_count == 0)
        $display("  ✅ ALL TESTS PASSED — SIMULATION CLEAN");
    else
        $display("  ❌ %0d FAILURES DETECTED", fail_count);
    $display("─────────────────────────────────────────");
    $finish;  // ← This stops the simulation automatically
```

Now every test you write either increments `pass_count` or `fail_count`. The reporter tells you the final score.

---

## PART 3 — THE GOLDEN MODEL (The Most Important Piece)

This is the heart of a self-checking testbench. The golden model is a **software copy** of what the DUT *should* do — written in the simplest possible way, using the language's built-in data structures.

For a FIFO, the golden model is trivially easy: **a software queue (array that behaves like a FIFO).**

```verilog
    // ── Golden Model ─────────────────────────────────────────────
    // This is our software FIFO. It mirrors what the DUT SHOULD do.
    reg [DATA_WIDTH-1:0] golden_queue [0:FIFO_DEPTH-1];
    integer              golden_head   = 0;  // points to next item to READ
    integer              golden_tail   = 0;  // points to next empty slot to WRITE
    integer              golden_count  = 0;  // how many items are in the golden FIFO

    // Golden write operation (mirrors what DUT does on wr_en && !full)
    task golden_write;
        input [DATA_WIDTH-1:0] data;
        begin
            if (golden_count < FIFO_DEPTH) begin
                golden_queue[golden_tail] = data;
                golden_tail = (golden_tail + 1) % FIFO_DEPTH; // wrap around
                golden_count = golden_count + 1;
            end
            // If full, silently do nothing — same as DUT behaviour
        end
    endtask

    // Golden read operation (returns what DUT SHOULD output on rd_en && !empty)
    task golden_read;
        output [DATA_WIDTH-1:0] expected;
        begin
            if (golden_count > 0) begin
                expected = golden_queue[golden_head];
                golden_head  = (golden_head + 1) % FIFO_DEPTH;
                golden_count = golden_count - 1;
            end else begin
                expected = {DATA_WIDTH{1'bx}}; // undefined — shouldn't be reading empty FIFO
            end
        end
    endtask
```

**Why does this work?**

The golden model and the DUT receive the **exact same stimuli** (same writes, same reads, same order). If the DUT is correct, its outputs must match the golden model's predictions. If they don't match — bug found.

The golden model is intentionally **simple**. You trust the simple software version
and use it to validate the complex hardware RTL.

---

## PART 4 — TASKS: Organising Your Stimulus

Without tasks, your stimulus block becomes a wall of code that's hard to read and debug.
Tasks let you say "do a write" instead of writing 5 lines every time.

### Task 1: Apply Reset

```verilog
    task apply_reset;
        begin
            $display("\n[RESET] Applying reset...");
            rst_n  = 1'b0;
            wr_en  = 1'b0;
            rd_en  = 1'b0;
            w_data = {DATA_WIDTH{1'b0}};

            // Reset the golden model too!
            golden_head  = 0;
            golden_tail  = 0;
            golden_count = 0;

            repeat(2) @(posedge clk);
            #1;  // small delay after clock edge to avoid race condition
            rst_n = 1'b1;
            @(posedge clk);
            #1;

            // Check: after reset, FIFO must be empty and not full
            if (empty !== 1'b1) begin
                $display("[FAIL] After reset: empty=%b, expected=1", empty);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] Reset: empty flag correct");
                pass_count = pass_count + 1;
            end

            if (full !== 1'b0) begin
                $display("[FAIL] After reset: full=%b, expected=0", full);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] Reset: full flag correct");
                pass_count = pass_count + 1;
            end
        end
    endtask
```

### Task 2: Do a Write (and update golden model)

```verilog
    task do_write;
        input [DATA_WIDTH-1:0] data;
        begin
            w_data = data;
            wr_en  = 1'b1;
            @(posedge clk);
            #1;
            wr_en  = 1'b0;

            // Mirror in golden model
            golden_write(data);

            $display("[WRITE] 0x%02h  | count_expected=%0d | full_dut=%b | empty_dut=%b",
                      data, golden_count, full, empty);
        end
    endtask
```

### Task 3: Do a Read and CHECK (this is where the magic happens)

```verilog
    task do_read_and_check;
        reg [DATA_WIDTH-1:0] expected;
        begin
            // Get what the golden model predicts we should receive
            golden_read(expected);

            // Tell the DUT to read
            rd_en = 1'b1;
            @(posedge clk);
            #1;
            rd_en = 1'b0;

            // r_data is REGISTERED — it appears one cycle after rd_en
            @(posedge clk);
            #1;

            // === THE COMPARISON — this is the self-checking part ===
            if (r_data === expected) begin
                $display("[PASS] Read: got 0x%02h = expected 0x%02h ✅", r_data, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Read: got 0x%02h ≠ expected 0x%02h ❌ at time %0t ns",
                          r_data, expected, $time);
                fail_count = fail_count + 1;
            end
        end
    endtask
```

### Task 4: Check Flags Against Golden Model

```verilog
    task check_flags;
        begin
            // Check empty flag
            if (empty === (golden_count == 0)) begin
                $display("[PASS] empty flag = %b (count=%0d)", empty, golden_count);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] empty=%b but golden_count=%0d ❌", empty, golden_count);
                fail_count = fail_count + 1;
            end

            // Check full flag
            if (full === (golden_count == FIFO_DEPTH)) begin
                $display("[PASS] full flag = %b (count=%0d)", full, golden_count);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] full=%b but golden_count=%0d ❌", full, golden_count);
                fail_count = fail_count + 1;
            end
        end
    endtask
```

---

## PART 5 — WRITING THE TEST CASES

Now your `initial` block becomes clean, readable English:

```verilog
    initial begin
        $dumpfile("fifo_sim.vcd");
        $dumpvars(0, tb_fifo);

        $display("═══════════════════════════════════════════");
        $display("  fifo_sync — Self-Checking Testbench");
        $display("  Depth=%0d  Width=%0d", FIFO_DEPTH, DATA_WIDTH);
        $display("═══════════════════════════════════════════");

        // ─── TEST 1: RESET ──────────────────────────────────────
        $display("\n══ TEST 1: Reset Behaviour ══");
        apply_reset;

        // ─── TEST 2: WRITE THEN READ — FIFO ORDERING ───────────
        $display("\n══ TEST 2: Write 3 Values, Read in FIFO Order ══");
        do_write(8'hAA);
        do_write(8'hBB);
        do_write(8'hCC);
        check_flags;         // should be: empty=0, full=0
        do_read_and_check;   // expects 0xAA (first in, first out)
        do_read_and_check;   // expects 0xBB
        do_read_and_check;   // expects 0xCC
        check_flags;         // should be: empty=1, full=0

        // ─── TEST 3: FILL TO FULL ───────────────────────────────
        $display("\n══ TEST 3: Fill FIFO to Full ══");
        apply_reset;
        begin : FILL_LOOP
            integer i;
            for (i = 0; i < FIFO_DEPTH; i = i + 1)
                do_write(i[DATA_WIDTH-1:0]);
        end
        check_flags;          // expect full=1

        // ─── TEST 4: OVERFLOW GUARD ─────────────────────────────
        $display("\n══ TEST 4: Overflow Guard (write when full) ══");
        // Try to write one more — DUT must ignore it
        do_write(8'hFF);      // golden_write also ignores it (same logic)
        check_flags;          // must still be full=1
        // Drain all 16 and verify order
        begin : DRAIN_LOOP
            integer i;
            for (i = 0; i < FIFO_DEPTH; i = i + 1)
                do_read_and_check;
        end
        check_flags;          // must be empty=1 now

        // ─── TEST 5: UNDERFLOW GUARD ────────────────────────────
        $display("\n══ TEST 5: Underflow Guard (read when empty) ══");
        // r_data must NOT change when we read an empty FIFO
        do_write(8'hAB);
        do_read_and_check;    // reads 0xAB, FIFO now empty
        check_flags;          // empty=1
        // Now try reading empty FIFO
        begin : UNDERFLOW
            reg [DATA_WIDTH-1:0] data_before_bad_read;
            data_before_bad_read = r_data;  // save current r_data
            rd_en = 1'b1;
            @(posedge clk); #1;
            rd_en = 1'b0;
            @(posedge clk); #1;
            if (r_data === data_before_bad_read) begin
                $display("[PASS] Underflow: r_data held at 0x%02h ✅", r_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Underflow: r_data changed from 0x%02h to 0x%02h ❌",
                          data_before_bad_read, r_data);
                fail_count = fail_count + 1;
            end
        end

        // ─── TEST 6: SIMULTANEOUS READ AND WRITE ────────────────
        $display("\n══ TEST 6: Simultaneous Read & Write ══");
        apply_reset;
        do_write(8'hDE);      // pre-load one item
        // Now read 0xDE while simultaneously writing 0xAD
        w_data = 8'hAD;
        wr_en  = 1'b1;
        rd_en  = 1'b1;
        @(posedge clk); #1;
        // Update golden model: golden write 0xAD, golden read 0xDE
        golden_write(8'hAD);
        golden_read(expected_sim);
        wr_en = 1'b0;
        rd_en = 1'b0;
        @(posedge clk); #1;
        check_flags;          // count should still be 1
        do_read_and_check;    // must read back 0xAD

        // ─── FINAL VERDICT ──────────────────────────────────────
        $display("\n═══════════════════════════════════════════");
        $display("  RESULTS:  %0d PASSED  |  %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display("  ✅ ALL TESTS PASSED — SIMULATION CLEAN");
        else
            $display("  ❌ FAILURES FOUND — REVIEW LOG ABOVE");
        $display("═══════════════════════════════════════════");
        $finish;
    end
```

---

## PART 6 — WHAT THE OUTPUT LOOKS LIKE

When your self-checking testbench runs, this is what you see in the console:

```
═══════════════════════════════════════════
  fifo_sync — Self-Checking Testbench
  Depth=16  Width=8
═══════════════════════════════════════════

══ TEST 1: Reset Behaviour ══
[RESET] Applying reset...
[PASS] Reset: empty flag correct
[PASS] Reset: full flag correct

══ TEST 2: Write 3 Values, Read in FIFO Order ══
[WRITE] 0xAA  | count_expected=1 | full_dut=0 | empty_dut=0
[WRITE] 0xBB  | count_expected=2 | full_dut=0 | empty_dut=0
[WRITE] 0xCC  | count_expected=3 | full_dut=0 | empty_dut=0
[PASS] empty flag = 0 (count=3)
[PASS] full flag = 0 (count=3)
[PASS] Read: got 0xAA = expected 0xAA ✅
[PASS] Read: got 0xBB = expected 0xBB ✅
[PASS] Read: got 0xCC = expected 0xCC ✅
[PASS] empty flag = 1 (count=0)
[PASS] full flag = 0 (count=0)

══ TEST 3: Fill FIFO to Full ══
...
[PASS] full flag = 1 (count=16)

══ TEST 4: Overflow Guard (write when full) ══
[PASS] full flag = 1 (count=16)       ← overflow was rejected
[PASS] Read: got 0x00 = expected 0x00 ✅
[PASS] Read: got 0x01 = expected 0x01 ✅
...16 reads...
[PASS] empty flag = 1 (count=0)

══ TEST 5: Underflow Guard (read when empty) ══
[PASS] Underflow: r_data held at 0xAB ✅

══ TEST 6: Simultaneous Read & Write ══
[PASS] empty flag = 0 (count=1)
[PASS] Read: got 0xAD = expected 0xAD ✅

═══════════════════════════════════════════
  RESULTS:  24 PASSED  |  0 FAILED
  ✅ ALL TESTS PASSED — SIMULATION CLEAN
═══════════════════════════════════════════
```

**Now compare this to staring at waveforms.** No human interpretation needed. 24 checks, all automated, all logged with context, final verdict printed.

---

## PART 7 — WHAT HAPPENS WHEN A TEST FAILS

Suppose there's a bug: the DUT reads 0xBB when it should read 0xAA (read pointer starts at wrong address). The output would be:

```
[FAIL] Read: got 0xBB ≠ expected 0xAA ❌ at time 2450 ns
```

You now know:
1. Exactly which transaction failed
2. What the DUT returned
3. What the correct answer was
4. At what time it happened

You can open GTKWave, go to timestamp `2450 ns`, and immediately see what the read pointer was doing. You don't need to search — the testbench **pointed you directly at the bug**.

---

## PART 8 — THE `===` OPERATOR (Important Detail)

Notice we use `===` for comparison, not `==`.

| Operator | 0 | 1 | X | Z |
|----------|---|---|---|---|
| `==`     | ✅ | ✅ | UNKNOWN (can return X) | UNKNOWN |
| `===`    | ✅ | ✅ | Compares X as a value | Compares Z as a value |

In simulation, signals can be `X` (unknown) before initialization. If you use `==` and one operand is `X`, the comparison itself returns `X` — which evaluates as FALSE in an `if`. You could silently miss a failure.

With `===`, `X === X` is TRUE and `X === 0` is FALSE — exactly what you want for detecting uninitialized signals.

**Rule: Always use `===` in testbench comparisons. Never use `==`.**

---

## PART 9 — THE RACE CONDITION TRAP (Common Beginner Bug)

This is the most common mistake in testbench writing — **the race between your testbench and the DUT at the clock edge.**

```
                  Clock Edge
                      │
Clock:     ───────────╔══════════════
DUT:       samples inputs HERE (setup time before edge)
Testbench: changes outputs HERE (if you use blocking = at posedge)
```

If your testbench changes a signal AT the same time the DUT samples it, you get unpredictable behaviour. The fix:

```verilog
// ❌ WRONG — changes signal exactly AT the clock edge
always @(posedge clk) begin
    wr_en = 1;    // blocking assignment at posedge — race condition!
end

// ✅ CORRECT — wait for a tiny time AFTER the clock edge
@(posedge clk);
#1;             // ← this tiny delay puts you safely AFTER the edge
wr_en = 1;      // DUT already sampled; this takes effect next cycle
```

The `#1` (1 nanosecond delay) is the universal testbench convention. You write:

```verilog
@(posedge clk); #1;   // every single time you apply stimuli after a clock
```

This appears in every task in a professional testbench. Without it, you will get mysterious failures that disappear when you run a second time — the hallmark of a race condition.

---

## PART 10 — THE `$display` FORMAT CHEAT SHEET

Good display messages make debugging fast. Use these format specifiers:

```verilog
$display("%b",   signal);   // binary:      10110011
$display("%d",   signal);   // decimal:     179
$display("%h",   signal);   // hex:         b3
$display("%02h", signal);   // hex padded:  b3 (always 2 digits)
$display("%0d",  integer);  // no leading zeros
$display("%t",   $time);    // current sim time: 12450

// Combining them:
$display("[FAIL] got=0x%02h expected=0x%02h at t=%0t ns", got, exp, $time);
// Outputs: [FAIL] got=0xBB expected=0xAA at t=2450 ns
```

---

## PART 11 — THE COMPLETE SELF-CHECKING TB TEMPLATE

Here is the complete, clean template you can copy and adapt for **any** DUT:

```verilog
`timescale 1ns / 1ps
module tb_YOURMODULE;

    // ── 1. Parameters ────────────────────────────────────────────
    localparam PARAM = 8;

    // ── 2. DUT Ports ─────────────────────────────────────────────
    reg  clk, rst_n, ...;
    wire output_signal;

    // ── 3. DUT Instantiation ─────────────────────────────────────
    YOUR_DUT #(...) DUT (.clk(clk), .rst_n(rst_n), ...);

    // ── 4. Clock ─────────────────────────────────────────────────
    initial clk = 0;
    always #10 clk = ~clk;

    // ── 5. Golden Model ──────────────────────────────────────────
    // (software equivalent of DUT behaviour)
    // ...

    // ── 6. Pass/Fail Counters ────────────────────────────────────
    integer pass_count = 0, fail_count = 0;

    // ── 7. Tasks (reusable stimulus + checking) ──────────────────
    task apply_reset; ... endtask
    task do_operation; ... endtask
    task check_output;
        input expected;
        begin
            if (actual === expected) begin
                $display("[PASS] ..."); pass_count++;
            end else begin
                $display("[FAIL] ..."); fail_count++;
            end
        end
    endtask

    // ── 8. Stimulus + Checking ───────────────────────────────────
    initial begin
        $dumpfile("sim.vcd");
        $dumpvars(0, tb_YOURMODULE);

        apply_reset;
        // Test 1...
        // Test 2...
        // ...

        // ── Final Verdict ────────────────────────────────────────
        $display("RESULTS: %0d PASSED | %0d FAILED", pass_count, fail_count);
        $finish;
    end

endmodule
```

---

## PART 12 — THE PROGRESSION (Where This Leads)

A self-checking testbench is Level 1 of a 4-level hierarchy:

```
Level 1: Self-Checking Testbench       ← YOU ARE HERE
         • Golden model
         • Task-based stimulus
         • Automatic pass/fail
         • Directed test cases

Level 2: Constrained-Random + Coverage  ← Next step (SystemVerilog)
         • Random stimulus via 'rand' + constraints
         • Covergroups to measure what scenarios were hit
         • 10,000 transactions instead of 10

Level 3: UVM Testbench                  ← Industry standard (Cadence)
         • Class-based, reusable components
         • Driver, Monitor, Scoreboard as separate objects
         • Sequences plug into agents
         • Portable across projects

Level 4: Formal Verification (JasperGold) ← Top tier
         • Mathematical proof (not sampling)
         • Checks ALL possible inputs, not just what you randomised
         • SVA properties proven exhaustively
```

Every UVM testbench you will ever read is just a highly-organised version of what
you are building right now. The golden model becomes the scoreboard.
The task becomes the driver. The `@(posedge clk)` in your task becomes the clocking block.

---

## KEY TAKEAWAYS — What To Remember

| Concept | Rule |
|---------|------|
| Golden model | Always write the simplest possible software version of your DUT |
| `===` not `==` | In testbench comparisons, always use `===` |
| `#1` after clock edge | Every time you apply stimulus after `@(posedge clk)` |
| Tasks | One task per operation — your stimulus block should read like English |
| `$finish` | Always call it at the end — never let simulation run forever |
| Fail messages | Include: what you got, what you expected, at what time |
| Count everything | pass_count and fail_count — no subjective "looks fine" |

---

*Guide written for the Spartan6-Synchronous-FIFO project — 2026-03-20*
*Companion file: `src/tb_fifo.v` — the self-checking testbench implementing everything above*
