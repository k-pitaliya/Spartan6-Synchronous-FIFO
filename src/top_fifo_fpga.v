// =============================================================================
// File        : top_fifo_fpga.v
// Project     : Spartan-6 Synchronous FIFO — FPGA Demo
// Board       : Spartan-6 (e.g., SP605, Nexys3, or custom board)
// Description : Top-level wrapper that connects fifo_sync to physical board I/O.
//               Uses push-buttons for control, switches for data input,
//               and LEDs for status output.
//
// HOW IT WORKS ON THE BOARD:
//   SW[7:0]   = 8-bit data you want to write into the FIFO
//   BTN_WRITE = Press to write SW[7:0] into FIFO (1 pulse = 1 write)
//   BTN_READ  = Press to read from FIFO (output appears on LED[7:0])
//   BTN_RESET = Press to reset FIFO (clears everything)
//   LED[7:0]  = Shows r_data (last data read out)
//   LED[8]    = FULL flag  (1 = FIFO is full, can't write more)
//   LED[9]    = EMPTY flag (1 = FIFO is empty, can't read)
//
// Author      : Kushal Pitaliya
// =============================================================================
`timescale 1ns/1ps

module top_fifo_fpga (
    input  wire        clk_in,      // Board clock (typically 50MHz or 100MHz)

    // Push buttons (active HIGH on most boards, check your board)
    input  wire        btn_reset,   // Reset button
    input  wire        btn_write,   // Write button
    input  wire        btn_read,    // Read button

    // Switches for data input
    input  wire [7:0]  sw,          // 8-bit data to write

    // LEDs for output
    output wire [7:0]  led_data,    // r_data (what you read out)
    output wire        led_full,    // FULL flag
    output wire        led_empty    // EMPTY flag
);

    // =========================================================================
    // 1. CLOCK DIVIDER
    // Board clock is usually 50MHz or 100MHz — too fast to see with your eyes.
    // We divide it down to ~1Hz so LED changes are visible.
    // For synthesis/timing analysis, keep the full clock.
    // For human demo, uncomment the slow clock section.
    // =========================================================================

    // For simulation / timing analysis — use board clock directly
    wire clk = clk_in;

    // =========================================================================
    // 2. RESET — Asynchronous, active-low with 2-FF synchronizer
    // btn_reset is active-HIGH on board → invert and synchronize for rst_n
    // The 2-FF synchronizer prevents metastability from async button input
    // =========================================================================
    reg rst_sync1, rst_sync2;
    always @(posedge clk) begin
        rst_sync1 <= ~btn_reset;
        rst_sync2 <= rst_sync1;
    end
    wire rst_n = rst_sync2;

    // =========================================================================
    // 3. BUTTON DEBOUNCE
    // Physical buttons bounce for ~10ms. We use the debounce module which 
    // includes a 2-FF synchronizer and a stability counter, and outputs a 
    // clean 1-cycle pulse.
    // =========================================================================

    wire wr_pulse;
    wire rd_pulse;

    debounce #(.COUNTER_WIDTH(20)) write_debouncer (
        .clk(clk),
        .rst_n(rst_n),
        .noisy_in(btn_write),
        .debounced_pulse(wr_pulse)
    );

    debounce #(.COUNTER_WIDTH(20)) read_debouncer (
        .clk(clk),
        .rst_n(rst_n),
        .noisy_in(btn_read),
        .debounced_pulse(rd_pulse)
    );

    // =========================================================================
    // 4. FIFO INSTANTIATION
    // =========================================================================
    wire        full, empty;
    wire [7:0]  r_data;

    fifo_sync #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)   // 2^4 = 16 entries deep
    ) fifo_inst (
        .clk    (clk),
        .rst_n  (rst_n),
        .wr_en  (wr_pulse),   // Only write on button press (one pulse)
        .w_data (sw),         // Data comes from switches
        .full   (full),
        .rd_en  (rd_pulse),   // Only read on button press (one pulse)
        .r_data (r_data),
        .empty  (empty)
    );

    // =========================================================================
    // 5. OUTPUT CONNECTIONS
    // =========================================================================
    assign led_data  = r_data;   // Show read data on LEDs
    assign led_full  = full;     // Full flag
    assign led_empty = empty;    // Empty flag

endmodule
