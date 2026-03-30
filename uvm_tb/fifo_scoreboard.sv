// fifo_scoreboard.sv  -  Kushal Pitaliya
// Self-checking scoreboard using a SV queue as the golden reference model.
//
// Key timing fix: the monitor captures signals at #1step (before clock edge
// processes), so flags seen are PRE-transaction. Check flags before updating
// the model, and check r_data one cycle later (registered DUT output).
`ifndef FIFO_SCOREBOARD_SV
`define FIFO_SCOREBOARD_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import fifo_pkg::*;

class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)

    uvm_analysis_imp #(fifo_seq_item, fifo_scoreboard) analysis_export;

    // this queue is the "perfect FIFO" - mirrors what the DUT should be doing
    logic [fifo_pkg::DATA_WIDTH-1:0] ref_model[$];

    // for r_data: DUT output is registered (1 cycle latency), so we
    // save what we expect and check it on the next transaction
    logic [fifo_pkg::DATA_WIDTH-1:0] pending_rdata;
    bit         check_rdata = 0;

    int total = 0, passes = 0, fails = 0;
    int wr_cnt = 0, rd_cnt = 0, full_hits = 0, empty_hits = 0;

    function new(string name = "fifo_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
    endfunction

    function void write(fifo_seq_item txn);
        bit can_wr, can_rd;
        total++;

        // step 1: check flags against model BEFORE updating it
        // (monitor sees pre-clock-edge DUT state due to #1step sampling)
        if (txn.full !== (ref_model.size() == fifo_pkg::FIFO_DEPTH)) begin
            `uvm_error("SB", $sformatf("[FLAG FAIL] full: got=%0b exp=%0b size=%0d",
                txn.full, (ref_model.size() == fifo_pkg::FIFO_DEPTH), ref_model.size()))
            fails++;
        end
        if (txn.empty !== (ref_model.size() == 0)) begin
            `uvm_error("SB", $sformatf("[FLAG FAIL] empty: got=%0b exp=%0b size=%0d",
                txn.empty, (ref_model.size() == 0), ref_model.size()))
            fails++;
        end

        // step 2: check r_data from the PREVIOUS read (registered output, 1 cycle late)
        if (check_rdata) begin
            if (txn.r_data !== pending_rdata) begin
                `uvm_error("SB", $sformatf("[FAIL] r_data: got=0x%02h exp=0x%02h",
                    txn.r_data, pending_rdata))
                fails++;
            end else begin
                passes++;
            end
            check_rdata = 0;
        end

        if (txn.full)  full_hits++;
        if (txn.empty) empty_hits++;

        // step 3: apply transaction to reference model
        // NOTE: Check can_rd first, then can_wr considers if read will free space
        // This matches DUT behavior where simultaneous R+W when full is allowed
        can_rd = txn.rd_en && (ref_model.size() > 0);
        can_wr = txn.wr_en && ((ref_model.size() < FIFO_DEPTH) || can_rd);

        // pop first (read happens at start of cycle in DUT)
        if (can_rd) begin
            pending_rdata = ref_model.pop_front();
            check_rdata   = 1;
            rd_cnt++;
        end
        if (can_wr) begin
            ref_model.push_back(txn.w_data);
            wr_cnt++;
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD", "============================================", UVM_NONE)
        `uvm_info("SCOREBOARD", "       FIFO UVM SCOREBOARD SUMMARY          ", UVM_NONE)
        `uvm_info("SCOREBOARD", "============================================", UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Total Transactions : %0d", total),     UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Writes             : %0d", wr_cnt),    UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Reads              : %0d", rd_cnt),    UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Full flag hits     : %0d", full_hits), UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Empty flag hits    : %0d", empty_hits),UVM_NONE)
        `uvm_info("SCOREBOARD", "--------------------------------------------", UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("PASS               : %0d", passes),    UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("FAIL               : %0d", fails),     UVM_NONE)
        if (fails == 0)
            `uvm_info("SCOREBOARD", ">>> ALL CHECKS PASSED <<<", UVM_NONE)
        else
            `uvm_error("SCOREBOARD", $sformatf(">>> %0d FAILURES <<<", fails))
        `uvm_info("SCOREBOARD", "============================================", UVM_NONE)
    endfunction

endclass

`endif
