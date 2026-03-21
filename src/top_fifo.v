// top_fifo.v
// Top-level integration module for the 8-bit Synchronous FIFO on the
// EDGE Spartan-6 (XC6SLX9) board.
//
// Signal flow:
//   Push buttons  →  debounce (×3)  →  fifo_sync core  →  LED indicators
//   Slide switches ─────────────────────────────────────►  data write bus

module top_fifo (
    input        clk_50mhz,   // 50 MHz on-board oscillator
    input        rst_btn,     // Active-HIGH reset push button
    input  [7:0] sw_data,     // 8 slide switches (data to write)
    input        wr_btn,      // Write push button
    input        rd_btn,      // Read push button
    output [7:0] led_data,    // 8 LEDs showing last read data
    output       led_full,    // Status LED: FIFO full
    output       led_empty    // Status LED: FIFO empty
);

    // -----------------------------------------------------------------------
    // Power-On Reset (POR) circuit
    // Holds master_rst_n LOW for 256 clock cycles (~5.12 µs at 50 MHz)
    // after power-up, guaranteeing every register starts in a known state
    // before any logic runs.
    // -----------------------------------------------------------------------
    reg [7:0] pwr_on_rst_counter = 8'h00;
    always @(posedge clk_50mhz) begin
        if (pwr_on_rst_counter != 8'hFF)
            pwr_on_rst_counter <= pwr_on_rst_counter + 1;
    end

    // rst_btn is Active-HIGH; invert to produce Active-LOW for internal logic.
    // master_rst_n is LOW (reset asserted) until POR finishes AND user is not
    // pressing the reset button.
    wire rst_n_internal = ~rst_btn;
    wire master_rst_n   = (pwr_on_rst_counter == 8'hFF) && rst_n_internal;

    // -----------------------------------------------------------------------
    // Debounce instances — one per button input
    // Each produces a single-cycle clean pulse on the rising edge of the
    // stabilised button signal.
    // -----------------------------------------------------------------------
    wire wr_en_pulse;
    wire rd_en_pulse;

    debounce #(.COUNTER_WIDTH(20)) DEBOUNCE_WRITE (
        .clk            (clk_50mhz),
        .rst_n          (master_rst_n),
        .noisy_in       (wr_btn),
        .debounced_pulse(wr_en_pulse)
    );

    debounce #(.COUNTER_WIDTH(20)) DEBOUNCE_READ (
        .clk            (clk_50mhz),
        .rst_n          (master_rst_n),
        .noisy_in       (rd_btn),
        .debounced_pulse(rd_en_pulse)
    );

    // -----------------------------------------------------------------------
    // FIFO Core instantiation
    // -----------------------------------------------------------------------
    wire        fifo_full_w;
    wire        fifo_empty_w;
    wire [7:0]  fifo_r_data_w;

    fifo_sync #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) FIFO_CORE_INST (
        .clk    (clk_50mhz),
        .rst_n  (master_rst_n),
        .wr_en  (wr_en_pulse),   // clean pulse from debouncer
        .w_data (sw_data),
        .full   (fifo_full_w),
        .rd_en  (rd_en_pulse),   // clean pulse from debouncer
        .r_data (fifo_r_data_w),
        .empty  (fifo_empty_w)
    );

    // -----------------------------------------------------------------------
    // Connect FIFO outputs to physical LEDs
    // -----------------------------------------------------------------------
    assign led_data  = fifo_r_data_w;
    assign led_full  = fifo_full_w;
    assign led_empty = fifo_empty_w;

endmodule
