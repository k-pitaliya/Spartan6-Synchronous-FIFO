// =============================================================================
// File        : fifo_scoreboard.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : UVM Scoreboard – golden reference model & self-checking logic
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_SCOREBOARD_SV
`define FIFO_SCOREBOARD_SV

class fifo_scoreboard #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) extends uvm_scoreboard;

    `uvm_component_param_utils(fifo_scoreboard #(DATA_WIDTH, ADDR_WIDTH))

    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;

    // Analysis export – receives transactions from monitor
    uvm_analysis_imp #(fifo_seq_item #(DATA_WIDTH), fifo_scoreboard #(DATA_WIDTH, ADDR_WIDTH)) analysis_export;

    // -------------------------------------------------------------------
    // Golden Reference Model (a SystemVerilog queue)
    // -------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] ref_model[$];

    // -------------------------------------------------------------------
    // Statistics
    // -------------------------------------------------------------------
    int unsigned total_txns     = 0;
    int unsigned pass_count     = 0;
    int unsigned fail_count     = 0;
    int unsigned write_count    = 0;
    int unsigned read_count     = 0;
    int unsigned full_hits      = 0;
    int unsigned empty_hits     = 0;
    int unsigned sim_rw_count   = 0;

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------
    function new(string name = "fifo_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // -------------------------------------------------------------------
    // Build Phase
    // -------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
    endfunction

    // -------------------------------------------------------------------
    // write() – called by monitor AP on every transaction
    // -------------------------------------------------------------------
    function void write(fifo_seq_item #(DATA_WIDTH) txn);
        logic [DATA_WIDTH-1:0] expected_rdata;
        logic expected_full, expected_empty;

        total_txns++;

        // --- Apply stimulus to reference model ---
        // Write
        if (txn.wr_en && (ref_model.size() < FIFO_DEPTH)) begin
            ref_model.push_back(txn.w_data);
            write_count++;
        end

        // Read
        if (txn.rd_en && (ref_model.size() > 0)) begin
            expected_rdata = ref_model.pop_front();
            read_count++;

            // Check r_data
            if (txn.r_data !== expected_rdata) begin
                `uvm_error("SCOREBOARD",
                    $sformatf("[FAIL] r_data mismatch: Got=0x%02h Expected=0x%02h | %s",
                              txn.r_data, expected_rdata, txn.convert2string()))
                fail_count++;
            end else begin
                `uvm_info("SCOREBOARD",
                    $sformatf("[PASS] r_data=0x%02h matches expected", txn.r_data), UVM_HIGH)
                pass_count++;
            end
        end

        // --- Verify full/empty flags against model ---
        expected_full  = (ref_model.size() == FIFO_DEPTH);
        expected_empty = (ref_model.size() == 0);

        if (txn.full !== expected_full) begin
            `uvm_error("SCOREBOARD",
                $sformatf("[FLAG FAIL] full: Got=%0b Expected=%0b model_size=%0d",
                          txn.full, expected_full, ref_model.size()))
            fail_count++;
        end

        if (txn.empty !== expected_empty) begin
            `uvm_error("SCOREBOARD",
                $sformatf("[FLAG FAIL] empty: Got=%0b Expected=%0b model_size=%0d",
                          txn.empty, expected_empty, ref_model.size()))
            fail_count++;
        end

        // Track statistics
        if (txn.full)  full_hits++;
        if (txn.empty) empty_hits++;
        if (txn.wr_en && txn.rd_en) sim_rw_count++;

    endfunction

    // -------------------------------------------------------------------
    // Report Phase – Final Summary
    // -------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD", "============================================", UVM_NONE)
        `uvm_info("SCOREBOARD", "         FIFO UVM SCOREBOARD SUMMARY        ", UVM_NONE)
        `uvm_info("SCOREBOARD", "============================================", UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Total Transactions : %0d", total_txns),   UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Writes             : %0d", write_count),  UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Reads              : %0d", read_count),   UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Simultaneous R+W   : %0d", sim_rw_count), UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Full-flag hits     : %0d", full_hits),    UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("Empty-flag hits    : %0d", empty_hits),   UVM_NONE)
        `uvm_info("SCOREBOARD", "--------------------------------------------", UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("PASS               : %0d", pass_count),  UVM_NONE)
        `uvm_info("SCOREBOARD", $sformatf("FAIL               : %0d", fail_count),  UVM_NONE)
        if (fail_count == 0)
            `uvm_info("SCOREBOARD", ">>> ALL CHECKS PASSED <<<", UVM_NONE)
        else
            `uvm_error("SCOREBOARD", $sformatf(">>> %0d FAILURES DETECTED <<<", fail_count))
        `uvm_info("SCOREBOARD", "============================================", UVM_NONE)
    endfunction

endclass : fifo_scoreboard

`endif // FIFO_SCOREBOARD_SV
