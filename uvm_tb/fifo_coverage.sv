// =============================================================================
// File        : fifo_coverage.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : UVM Coverage Collector – functional coverage groups for FIFO
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_COVERAGE_SV
`define FIFO_COVERAGE_SV

class fifo_coverage #(parameter DATA_WIDTH = 8) extends uvm_subscriber #(fifo_seq_item #(DATA_WIDTH));

    `uvm_component_param_utils(fifo_coverage #(DATA_WIDTH))

    fifo_seq_item #(DATA_WIDTH) txn;

    // -------------------------------------------------------------------
    // Covergroup – Operation Types
    // -------------------------------------------------------------------
    covergroup cg_operations;
        cp_op_type: coverpoint txn.op_type {
            bins write_only = {fifo_seq_item#(DATA_WIDTH)::WRITE_ONLY};
            bins read_only  = {fifo_seq_item#(DATA_WIDTH)::READ_ONLY};
            bins read_write = {fifo_seq_item#(DATA_WIDTH)::READ_WRITE};
            bins idle       = {fifo_seq_item#(DATA_WIDTH)::IDLE};
        }

        cp_full: coverpoint txn.full {
            bins full_asserted    = {1'b1};
            bins full_deasserted  = {1'b0};
        }

        cp_empty: coverpoint txn.empty {
            bins empty_asserted   = {1'b1};
            bins empty_deasserted = {1'b0};
        }

        // Cross coverage: operation while full/empty
        cx_op_full:  cross cp_op_type, cp_full;
        cx_op_empty: cross cp_op_type, cp_empty;
    endgroup

    // -------------------------------------------------------------------
    // Covergroup – Data Boundary Coverage
    // -------------------------------------------------------------------
    covergroup cg_data_values;
        cp_wdata_boundaries: coverpoint txn.w_data {
            bins zero      = {8'h00};
            bins max_val   = {8'hFF};
            bins low_range = {[8'h01 : 8'h3F]};
            bins mid_range = {[8'h40 : 8'hBF]};
            bins hi_range  = {[8'hC0 : 8'hFE]};
        }
    endgroup

    // -------------------------------------------------------------------
    // Covergroup – Flag Transitions
    // -------------------------------------------------------------------
    // Track consecutive flag changes (fill, drain edge detection)
    logic prev_full  = 0;
    logic prev_empty = 1;

    covergroup cg_flag_transitions;
        cp_full_rise:  coverpoint (prev_full  == 0 && txn.full  == 1) { bins full_rise  = {1}; }
        cp_full_fall:  coverpoint (prev_full  == 1 && txn.full  == 0) { bins full_fall  = {1}; }
        cp_empty_rise: coverpoint (prev_empty == 0 && txn.empty == 1) { bins empty_rise = {1}; }
        cp_empty_fall: coverpoint (prev_empty == 1 && txn.empty == 0) { bins empty_fall = {1}; }
    endgroup

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------
    function new(string name = "fifo_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_operations       = new();
        cg_data_values      = new();
        cg_flag_transitions = new();
    endfunction

    // -------------------------------------------------------------------
    // write() – called every time monitor sends a transaction
    // -------------------------------------------------------------------
    function void write(fifo_seq_item #(DATA_WIDTH) t);
        txn = t;
        cg_operations.sample();
        cg_data_values.sample();
        cg_flag_transitions.sample();
        prev_full  = txn.full;
        prev_empty = txn.empty;
    endfunction

    // -------------------------------------------------------------------
    // Report Phase – Print Coverage Results
    // -------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("COVERAGE", "============================================", UVM_NONE)
        `uvm_info("COVERAGE", "       FUNCTIONAL COVERAGE SUMMARY          ", UVM_NONE)
        `uvm_info("COVERAGE", "============================================", UVM_NONE)
        `uvm_info("COVERAGE",
            $sformatf("cg_operations       : %.2f%%", cg_operations.get_coverage()),       UVM_NONE)
        `uvm_info("COVERAGE",
            $sformatf("cg_data_values      : %.2f%%", cg_data_values.get_coverage()),      UVM_NONE)
        `uvm_info("COVERAGE",
            $sformatf("cg_flag_transitions : %.2f%%", cg_flag_transitions.get_coverage()), UVM_NONE)
        `uvm_info("COVERAGE",
            $sformatf("TOTAL FUNCTIONAL COV: %.2f%%",
                (cg_operations.get_coverage() +
                 cg_data_values.get_coverage() +
                 cg_flag_transitions.get_coverage()) / 3.0),
            UVM_NONE)
        `uvm_info("COVERAGE", "============================================", UVM_NONE)
    endfunction

endclass : fifo_coverage

`endif // FIFO_COVERAGE_SV
