// =============================================================================
// File        : fifo_monitor.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : UVM Monitor – passively observes DUT interface & broadcasts txns
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_MONITOR_SV
`define FIFO_MONITOR_SV

class fifo_monitor #(parameter DATA_WIDTH = 8) extends uvm_monitor;

    `uvm_component_param_utils(fifo_monitor #(DATA_WIDTH))

    // Virtual interface
    virtual fifo_if #(.DATA_WIDTH(DATA_WIDTH)) vif;

    // Analysis port – broadcasts to scoreboard and coverage collector
    uvm_analysis_port #(fifo_seq_item #(DATA_WIDTH)) ap;

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------
    function new(string name = "fifo_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // -------------------------------------------------------------------
    // Build Phase
    // -------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual fifo_if #(.DATA_WIDTH(DATA_WIDTH)))::get(
                this, "", "vif", vif))
            `uvm_fatal("CFG_ERR", "fifo_monitor: vif not found in config_db")
    endfunction

    // -------------------------------------------------------------------
    // Run Phase – sample on every clock edge
    // -------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        fifo_seq_item #(DATA_WIDTH) txn;

        // Wait until reset is released
        @(posedge vif.rst_n);
        `uvm_info(get_name(), "Reset released – monitoring begins", UVM_MEDIUM)

        forever begin
            @(vif.monitor_cb);
            txn = fifo_seq_item #(DATA_WIDTH)::type_id::create("mon_txn");

            // Capture all signals one step after clock edge (skew-free)
            txn.wr_en  = vif.monitor_cb.wr_en;
            txn.rd_en  = vif.monitor_cb.rd_en;
            txn.w_data = vif.monitor_cb.w_data;
            txn.r_data = vif.monitor_cb.r_data;
            txn.full   = vif.monitor_cb.full;
            txn.empty  = vif.monitor_cb.empty;

            // Set op_type
            case ({txn.wr_en, txn.rd_en})
                2'b10: txn.op_type = fifo_seq_item#(DATA_WIDTH)::WRITE_ONLY;
                2'b01: txn.op_type = fifo_seq_item#(DATA_WIDTH)::READ_ONLY;
                2'b11: txn.op_type = fifo_seq_item#(DATA_WIDTH)::READ_WRITE;
                2'b00: txn.op_type = fifo_seq_item#(DATA_WIDTH)::IDLE;
            endcase

            ap.write(txn);
            `uvm_info(get_name(), txn.convert2string(), UVM_HIGH)
        end
    endtask

endclass : fifo_monitor

`endif // FIFO_MONITOR_SV
