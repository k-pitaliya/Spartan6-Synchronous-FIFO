//==============================================================================
// tb_fifo.v — Self-Checking Testbench for fifo_sync
//
// This testbench directly tests the FIFO core (fifo_sync), bypassing the
// top_fifo wrapper and debounce modules — that is the correct approach for
// unit-level verification.
//
// Tests performed:
//   1. Reset behaviour
//   2. Sequential write → read (data integrity / FIFO ordering)
//   3. Fill-to-full and verify full flag
//   4. Drain-to-empty and verify empty flag
//   5. Overflow guard (write when full must be ignored)
//   6. Underflow guard (read when empty must be ignored)
//   7. Back-to-back read-write in same cycle
//==============================================================================
`timescale 1ns / 1ps

module tb_fifo;

    // -----------------------------------------------------------------------
    // DUT parameters — must match fifo_sync defaults
    // -----------------------------------------------------------------------
    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 4;
    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;   // 16

    // -----------------------------------------------------------------------
    // DUT port connections
    // -----------------------------------------------------------------------
    reg                    clk;
    reg                    rst_n;
    reg                    wr_en;
    reg  [DATA_WIDTH-1:0]  w_data;
    reg                    rd_en;

    wire                   full;
    wire                   empty;
    wire [DATA_WIDTH-1:0]  r_data;

    // -----------------------------------------------------------------------
    // Instantiate the Device Under Test — fifo_sync (core only)
    // -----------------------------------------------------------------------
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

    // -----------------------------------------------------------------------
    // Clock: 20 ns period → 50 MHz
    // -----------------------------------------------------------------------
    initial clk = 0;
    always #10 clk = ~clk;

    // -----------------------------------------------------------------------
    // Pass/Fail counters
    // -----------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // -----------------------------------------------------------------------
    // Helper task: apply reset
    // -----------------------------------------------------------------------
    task apply_reset;
        begin
            rst_n  = 1'b0;
            wr_en  = 1'b0;
            rd_en  = 1'b0;
            w_data = 8'h00;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rst_n  = 1'b1;
            @(posedge clk); #1;
        end
    endtask

    // -----------------------------------------------------------------------
    // Helper task: write one word
    // -----------------------------------------------------------------------
    task do_write;
        input [DATA_WIDTH-1:0] data;
        begin
            w_data = data;
            wr_en  = 1'b1;
            @(posedge clk); #1;
            wr_en  = 1'b0;
        end
    endtask

    // -----------------------------------------------------------------------
    // Helper task: read one word and compare
    // -----------------------------------------------------------------------
    task do_read;
        input [DATA_WIDTH-1:0] expected;
        begin
            rd_en = 1'b1;
            @(posedge clk); #1;
            rd_en = 1'b0;
            // r_data is registered — value appears one cycle after rd_en
            @(posedge clk); #1;
            if (r_data === expected) begin
                $display("[PASS] Read data = 0x%02h (expected 0x%02h)", r_data, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Read data = 0x%02h (expected 0x%02h) at time %0t ns",
                         r_data, expected, $time);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // Helper task: check a flag condition
    // -----------------------------------------------------------------------
    task check_flag;
        input        actual;
        input        expected;
        input [63:0] label;   // use 8-char string as label
        begin
            if (actual === expected) begin
                $display("[PASS] %s = %b", label, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s = %b (expected %b) at time %0t ns",
                         label, actual, expected, $time);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------------
    integer i;

    initial begin
        $display("=======================================================");
        $display("  fifo_sync Self-Checking Testbench");
        $display("  Depth = %0d, Width = %0d bits", FIFO_DEPTH, DATA_WIDTH);
        $display("=======================================================");

        // === TEST 1: Reset ===
        $display("\n--- TEST 1: Reset Behaviour ---");
        apply_reset;
        check_flag(empty, 1'b1, "EMPTY   ");
        check_flag(full,  1'b0, "FULL    ");

        // === TEST 2: Write then read 3 values — verify FIFO ordering ===
        $display("\n--- TEST 2: Write 3 Values, Read Back in Order ---");
        do_write(8'hAA);
        do_write(8'hBB);
        do_write(8'hCC);
        check_flag(empty, 1'b0, "EMPTY   ");
        do_read(8'hAA);   // First-In, First-Out
        do_read(8'hBB);
        do_read(8'hCC);
        check_flag(empty, 1'b1, "EMPTY   ");

        // === TEST 3: Fill FIFO to full ===
        $display("\n--- TEST 3: Fill to Full ---");
        apply_reset;
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            do_write(i[7:0]);
        end
        check_flag(full, 1'b1, "FULL    ");

        // === TEST 4: Overflow guard — write when full must be ignored ===
        $display("\n--- TEST 4: Overflow Guard ---");
        // Attempt one more write — should be silently dropped
        do_write(8'hFF);
        check_flag(full, 1'b1, "FULL    ");

        // Drain and verify order (0,1,2,...,15); extra write must not appear
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            do_read(i[7:0]);
        end
        check_flag(empty, 1'b1, "EMPTY   ");

        // === TEST 5: Underflow guard — read when empty must be ignored ===
        $display("\n--- TEST 5: Underflow Guard ---");
        // Capture r_data before attempting rogue read
        do_write(8'hAB);
        do_read(8'hAB);    // drain to empty
        check_flag(empty, 1'b1, "EMPTY   ");
        // Now attempt a read on empty FIFO — r_data must remain 0xAB (last value)
        rd_en = 1'b1;
        @(posedge clk); #1;
        rd_en = 1'b0;
        @(posedge clk); #1;
        if (r_data === 8'hAB) begin
            $display("[PASS] Underflow guard: r_data held at 0x%02h", r_data);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Underflow guard: r_data changed to 0x%02h", r_data);
            fail_count = fail_count + 1;
        end

        // === TEST 6: Simultaneous read and write ===
        $display("\n--- TEST 6: Simultaneous Read & Write ---");
        apply_reset;
        do_write(8'hDE);   // pre-load one item so read is valid
        wr_en  = 1'b1;
        rd_en  = 1'b1;
        w_data = 8'hAD;    // simultaneously write 0xAD while reading 0xDE
        @(posedge clk); #1;
        wr_en = 1'b0;
        rd_en = 1'b0;
        @(posedge clk); #1;
        // After the simultaneous op: 0xDE was read out, 0xAD now sits in FIFO
        // item_count should still be 1 (net change = 0)
        check_flag(empty, 1'b0, "EMPTY   ");
        check_flag(full,  1'b0, "FULL    ");
        do_read(8'hAD);   // drain remaining item

        // === Summary ===
        $display("\n=======================================================");
        $display("  RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED — SIMULATION SUCCESSFUL ***");
        else
            $display("  *** FAILURES DETECTED — REVIEW OUTPUT ABOVE ***");
        $display("=======================================================");
        $finish;
    end

    // -----------------------------------------------------------------------
    // Waveform dump (for ISim or GTKWave)
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("fifo_sim.vcd");
        $dumpvars(0, tb_fifo);
    end

endmodule
