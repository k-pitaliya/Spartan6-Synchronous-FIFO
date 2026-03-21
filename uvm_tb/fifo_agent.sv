// =============================================================================
// File        : fifo_agent.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : UVM Agent – bundles driver, monitor, sequencer
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_AGENT_SV
`define FIFO_AGENT_SV

class fifo_agent #(parameter DATA_WIDTH = 8) extends uvm_agent;

    `uvm_component_param_utils(fifo_agent #(DATA_WIDTH))

    // -------------------------------------------------------------------
    // Sub-components
    // -------------------------------------------------------------------
    fifo_driver    #(DATA_WIDTH)                         driver;
    fifo_monitor   #(DATA_WIDTH)                         monitor;
    uvm_sequencer  #(fifo_seq_item #(DATA_WIDTH))        sequencer;

    // Analysis port passthrough to environment
    uvm_analysis_port #(fifo_seq_item #(DATA_WIDTH))     ap;

    // Active/passive config
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------
    function new(string name = "fifo_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // -------------------------------------------------------------------
    // Build Phase
    // -------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap      = new("ap", this);
        monitor = fifo_monitor #(DATA_WIDTH)::type_id::create("monitor", this);

        if (is_active == UVM_ACTIVE) begin
            driver    = fifo_driver   #(DATA_WIDTH)::type_id::create("driver",    this);
            sequencer = uvm_sequencer #(fifo_seq_item #(DATA_WIDTH))::type_id::create("sequencer", this);
        end
    endfunction

    // -------------------------------------------------------------------
    // Connect Phase
    // -------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        // Pass monitor AP to agent AP
        monitor.ap.connect(ap);

        // Connect driver to sequencer (active mode only)
        if (is_active == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass : fifo_agent

`endif // FIFO_AGENT_SV
