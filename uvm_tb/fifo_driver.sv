// =============================================================================
// File        : fifo_driver.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : UVM Driver – drives transactions onto the FIFO interface
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_DRIVER_SV
`define FIFO_DRIVER_SV

class fifo_driver #(parameter DATA_WIDTH = 8) extends uvm_driver #(fifo_seq_item #(DATA_WIDTH));

    `uvm_component_param_utils(fifo_driver #(DATA_WIDTH))

    // Virtual interface handle
    virtual fifo_if #(.DATA_WIDTH(DATA_WIDTH)) vif;

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------
    function new(string name = "fifo_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // -------------------------------------------------------------------
    // Build Phase – get vif from config_db
    // -------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual fifo_if #(.DATA_WIDTH(DATA_WIDTH)))::get(
                this, "", "vif", vif))
            `uvm_fatal("CFG_ERR", "fifo_driver: vif not found in config_db")
        `uvm_info(get_name(), "Build phase complete", UVM_HIGH)
    endfunction

    // -------------------------------------------------------------------
    // Run Phase – main driver loop
    // -------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        fifo_seq_item #(DATA_WIDTH) txn;

        // Initialise outputs to safe state
        vif.driver_cb.wr_en  <= 0;
        vif.driver_cb.rd_en  <= 0;
        vif.driver_cb.w_data <= 0;
        vif.driver_cb.rst_n  <= 0;

        // Assert reset for 5 cycles
        repeat (5) @(vif.driver_cb);
        vif.driver_cb.rst_n <= 1;
        `uvm_info(get_name(), "Reset deasserted – starting stimulus", UVM_MEDIUM)

        forever begin
            seq_item_port.get_next_item(txn);
            drive_txn(txn);
            seq_item_port.item_done();
        end
    endtask

    // -------------------------------------------------------------------
    // Drive single transaction
    // -------------------------------------------------------------------
    task drive_txn(fifo_seq_item #(DATA_WIDTH) txn);
        @(vif.driver_cb);
        vif.driver_cb.wr_en  <= txn.wr_en;
        vif.driver_cb.rd_en  <= txn.rd_en;
        vif.driver_cb.w_data <= txn.w_data;
        `uvm_info(get_name(), txn.convert2string(), UVM_HIGH)
    endtask

endclass : fifo_driver

`endif // FIFO_DRIVER_SV
