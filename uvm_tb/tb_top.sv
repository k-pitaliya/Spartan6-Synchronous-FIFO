// =============================================================================
// File        : tb_top.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : Top-level testbench module – DUT instantiation, clock gen,
//               interface wiring, uvm_config_db setup, and test launch
// Author      : Kushal Pitaliya
// =============================================================================
`timescale 1ns/1ps

// Import UVM
`include "uvm_macros.svh"
import uvm_pkg::*;

// Include all TB files
`include "fifo_if.sv"
`include "fifo_seq_item.sv"
`include "fifo_sequences.sv"
`include "fifo_driver.sv"
`include "fifo_monitor.sv"
`include "fifo_scoreboard.sv"
`include "fifo_coverage.sv"
`include "fifo_agent.sv"
`include "fifo_env.sv"
`include "fifo_test.sv"

module tb_top;

    // -------------------------------------------------------------------
    // Parameters (must match DUT)
    // -------------------------------------------------------------------
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;

    // -------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz (10 ns period)

    // -------------------------------------------------------------------
    // Interface Instantiation
    // -------------------------------------------------------------------
    fifo_if #(.DATA_WIDTH(DATA_WIDTH)) dut_if (.clk(clk));

    // -------------------------------------------------------------------
    // DUT Instantiation
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
    // UVM Config DB – register virtual interface
    // -------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual fifo_if #(.DATA_WIDTH(DATA_WIDTH)))::set(
            null, "uvm_test_top.*", "vif", dut_if
        );

        // Run the test specified by +UVM_TESTNAME argument
        // Default: fifo_directed_test
        run_test("fifo_directed_test");
    end

    // -------------------------------------------------------------------
    // Waveform Dump (for ModelSim / QuestaSim)
    // -------------------------------------------------------------------
    initial begin
        $dumpfile("fifo_uvm_waves.vcd");
        $dumpvars(0, tb_top);
    end

    // -------------------------------------------------------------------
    // Timeout Watchdog
    // -------------------------------------------------------------------
    initial begin
        #500000;
        `uvm_fatal("TIMEOUT", "Simulation exceeded 500us – possible hang!")
    end

endmodule : tb_top
