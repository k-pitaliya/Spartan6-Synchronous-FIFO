// debounce.v
// Timer-based debounce filter with 2-stage synchronizer for metastability safety.
// Generates a single clean rising-edge pulse after the input stabilises.
// At 50 MHz, COUNTER_WIDTH=20 gives a debounce window of ~20.97 ms.

module debounce #(
    parameter COUNTER_WIDTH = 20   // Debounce window: 2^COUNTER_WIDTH clock cycles
)(
    input  clk,
    input  rst_n,
    input  noisy_in,
    output reg debounced_pulse
);

    // -----------------------------------------------------------------------
    // Stage 1 & 2: Two-FF synchronizer to prevent metastability issues when
    // sampling an asynchronous button signal into the clk domain.
    // -----------------------------------------------------------------------
    reg sync_ff1, sync_ff2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= noisy_in;   // first capture (may be metastable)
            sync_ff2 <= sync_ff1;   // second capture (resolved)
        end
    end

    // -----------------------------------------------------------------------
    // Stage 3: Stability counter
    // If synced input differs from last-confirmed value, start counting.
    // When the counter wraps all-ones, commit the new value.
    // -----------------------------------------------------------------------
    reg [COUNTER_WIDTH-1:0] counter;
    reg debounced_signal_reg;
    reg prev_debounced_signal;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter               <= 0;
            debounced_signal_reg  <= 1'b0;
            prev_debounced_signal <= 1'b0;
            debounced_pulse       <= 1'b0;
        end else begin
            // -- Stability detection --
            if (sync_ff2 == debounced_signal_reg) begin
                // Input is stable at the current confirmed value; reset counter
                counter <= 0;
            end else begin
                // Input disagrees with confirmed value; keep counting
                counter <= counter + 1;
            end

            // When counter is all-ones the input has been stable long enough
            if (&counter) begin
                debounced_signal_reg <= sync_ff2;
            end

            // -- Edge detection (rising edge only) --
            prev_debounced_signal <= debounced_signal_reg;
            debounced_pulse <= debounced_signal_reg & ~prev_debounced_signal;
        end
    end

endmodule
