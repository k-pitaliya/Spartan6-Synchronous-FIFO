// fifo_coverage.sv  -  Kushal Pitaliya
// Coverage collector for the FIFO UVM testbench.
// Three covergroups: operation types, data value boundaries, flag transitions.
`ifndef FIFO_COVERAGE_SV
`define FIFO_COVERAGE_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import fifo_pkg::*;

class fifo_coverage extends uvm_subscriber #(fifo_seq_item);
    `uvm_component_utils(fifo_coverage)

    fifo_seq_item txn;

    // track previous flag values for transition detection
    logic prev_full  = 0;
    logic prev_empty = 1;  // starts empty after reset

    // covergroup 1: what operations happened and under what flag conditions
    covergroup cg_ops;
        option.per_instance = 1;  // Enable per-instance coverage for regression merging
        cp_op: coverpoint txn.op_type {
            bins write_only = {fifo_seq_item::WRITE_ONLY};
            bins read_only  = {fifo_seq_item::READ_ONLY};
            bins read_write = {fifo_seq_item::READ_WRITE};   // simultaneous - important case
            bins idle       = {fifo_seq_item::IDLE};
        }
        cp_full:  coverpoint txn.full  { bins is_full  = {1}; bins not_full  = {0}; }
        cp_empty: coverpoint txn.empty { bins is_empty = {1}; bins not_empty = {0}; }

        // cross: write while full? read while empty? these are the boundary cases
        cx_op_full:  cross cp_op, cp_full;
        cx_op_empty: cross cp_op, cp_empty;
    endgroup

    // covergroup 2: make sure we hit data boundaries dynamically based on DATA_WIDTH
    covergroup cg_data;
        cp_wdata: coverpoint txn.w_data {
            bins zero      = {0};
            bins max_val   = { (1<<fifo_pkg::DATA_WIDTH)-1 };
            bins others[3] = { [1 : (1<<fifo_pkg::DATA_WIDTH)-2] };
        }
        cp_rdata: coverpoint txn.r_data {
            bins zero      = {0};
            bins max_val   = { (1<<fifo_pkg::DATA_WIDTH)-1 };
            bins others[3] = { [1 : (1<<fifo_pkg::DATA_WIDTH)-2] };
        }
    endgroup

    // covergroup 3: did the full/empty flags actually toggle?
    // want to see FIFO go from not-full to full, and back down
    covergroup cg_flags;
        cp_full_rise:  coverpoint (prev_full  == 0 && txn.full  == 1) { bins v = {1}; }
        cp_full_fall:  coverpoint (prev_full  == 1 && txn.full  == 0) { bins v = {1}; }
        cp_empty_rise: coverpoint (prev_empty == 0 && txn.empty == 1) { bins v = {1}; }
        cp_empty_fall: coverpoint (prev_empty == 1 && txn.empty == 0) { bins v = {1}; }
    endgroup

    function new(string name = "fifo_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_ops   = new();
        cg_data  = new();
        cg_flags = new();
    endfunction

    // called by analysis port every cycle
    function void write(fifo_seq_item t);
        txn = t;
        cg_ops.sample();
        cg_data.sample();
        cg_flags.sample();
        prev_full  = txn.full;
        prev_empty = txn.empty;
    endfunction

    function void report_phase(uvm_phase phase);
        real ops_cov, data_cov, flag_cov, total_cov;
        ops_cov   = cg_ops.get_coverage();
        data_cov  = cg_data.get_coverage();
        flag_cov  = cg_flags.get_coverage();
        total_cov = (ops_cov + data_cov + flag_cov) / 3.0;

        `uvm_info("COVERAGE", "============================================", UVM_NONE)
        `uvm_info("COVERAGE", "       FUNCTIONAL COVERAGE SUMMARY          ", UVM_NONE)
        `uvm_info("COVERAGE", "============================================", UVM_NONE)
        `uvm_info("COVERAGE", $sformatf("cg_ops  (operations) : %.2f%%", ops_cov),   UVM_NONE)
        `uvm_info("COVERAGE", $sformatf("cg_data (data vals)  : %.2f%%", data_cov),  UVM_NONE)
        `uvm_info("COVERAGE", $sformatf("cg_flags(transitions): %.2f%%", flag_cov),  UVM_NONE)
        `uvm_info("COVERAGE", $sformatf("TOTAL FUNCTIONAL COV : %.2f%%", total_cov), UVM_NONE)
        `uvm_info("COVERAGE", "============================================", UVM_NONE)
    endfunction

endclass

`endif
