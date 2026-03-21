// =============================================================================
// File        : fifo_if.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : SystemVerilog Interface for fifo_sync DUT
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_IF_SV
`define FIFO_IF_SV

interface fifo_if #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(input logic clk);

    // -------------------------------------------------------------------
    // DUT Ports
    // -------------------------------------------------------------------
    logic                   rst_n;
    logic                   wr_en;
    logic [DATA_WIDTH-1:0]  w_data;
    logic                   full;
    logic                   rd_en;
    logic [DATA_WIDTH-1:0]  r_data;
    logic                   empty;

    // -------------------------------------------------------------------
    // Clocking Block – Driver (active)
    // -------------------------------------------------------------------
    clocking driver_cb @(posedge clk);
        default input  #1step;
        default output #1;
        output rst_n;
        output wr_en;
        output w_data;
        output rd_en;
        input  full;
        input  empty;
        input  r_data;
    endclocking

    // -------------------------------------------------------------------
    // Clocking Block – Monitor (passive)
    // -------------------------------------------------------------------
    clocking monitor_cb @(posedge clk);
        default input #1step;
        input rst_n;
        input wr_en;
        input w_data;
        input full;
        input rd_en;
        input r_data;
        input empty;
    endclocking

    // -------------------------------------------------------------------
    // Modports
    // -------------------------------------------------------------------
    modport DRIVER  (clocking driver_cb,  input clk);
    modport MONITOR (clocking monitor_cb, input clk);

    // -------------------------------------------------------------------
    // Assertions – Flag Protocol Checks
    // -------------------------------------------------------------------
    // FULL flag: item_count == FIFO_DEPTH  →  no write should increment further
    property p_no_write_when_full;
        @(posedge clk) disable iff (!rst_n)
        (full && wr_en) |=> full;
    endproperty
    assert_no_write_when_full: assert property (p_no_write_when_full)
        else $error("[ASSERT] Write attempted when FIFO is FULL at time %0t", $time);

    // EMPTY flag: item_count == 0  →  no read should decrement further
    property p_no_read_when_empty;
        @(posedge clk) disable iff (!rst_n)
        (empty && rd_en) |=> empty;
    endproperty
    assert_no_read_when_empty: assert property (p_no_read_when_empty)
        else $error("[ASSERT] Read attempted when FIFO is EMPTY at time %0t", $time);

    // After reset, both full and empty must be in known state
    property p_reset_state;
        @(posedge clk)
        $fell(rst_n) |=> (!full && empty);
    endproperty
    assert_reset_state: assert property (p_reset_state)
        else $error("[ASSERT] Post-reset state invalid: full=%0b empty=%0b", full, empty);

endinterface : fifo_if

`endif // FIFO_IF_SV
