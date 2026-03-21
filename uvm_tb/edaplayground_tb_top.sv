// =============================================================================
// EDA Playground Top-Level Testbench
// Paste THIS file into the Testbench (right) panel on edaplayground.com
// Paste fifo_sync.v into the Design (left) panel
//
// Settings in EDA Playground:
//   Simulator : Aldec Riviera-PRO  (or Mentor Questa)
//   UVM/OVM   : UVM 1.2
//   Language  : SystemVerilog
// =============================================================================
`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

// ---- All UVM TB classes are pasted above this line in the same panel ----
// (EDA Playground compiles the entire right-panel as one file)

module tb_top;

    // -------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;

    // -------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    // -------------------------------------------------------------------
    // Interface
    // -------------------------------------------------------------------
    fifo_if #(.DATA_WIDTH(DATA_WIDTH)) dut_if (.clk(clk));

    // -------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------
    fifo_sync #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) DUT (
        .clk    (clk),
        .rst_n  (dut_if.rst_n),
        .wr_en  (dut_if.wr_en),
        .w_data (dut_if.w_data),
        .full   (dut_if.full),
        .rd_en  (dut_if.rd_en),
        .r_data (dut_if.r_data),
        .empty  (dut_if.empty)
    );

    // -------------------------------------------------------------------
    // UVM config_db + test launch
    // -------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual fifo_if #(.DATA_WIDTH(DATA_WIDTH)))::set(
            null, "uvm_test_top.*", "vif", dut_if
        );
        // Change "fifo_directed_test" to "fifo_rand_test" or "fifo_stress_test"
        run_test("fifo_directed_test");
    end

    // -------------------------------------------------------------------
    // Timeout Watchdog
    // -------------------------------------------------------------------
    initial begin
        #500000;
        `uvm_fatal("TIMEOUT", "Simulation exceeded 500us!")
    end

endmodule : tb_top
