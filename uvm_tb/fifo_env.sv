// =============================================================================
// File        : fifo_env.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : UVM Environment – top-level env connecting agent, scoreboard,
//               and coverage collector
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_ENV_SV
`define FIFO_ENV_SV

class fifo_env #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) extends uvm_env;

    `uvm_component_param_utils(fifo_env #(DATA_WIDTH, ADDR_WIDTH))

    // -------------------------------------------------------------------
    // Sub-components
    // -------------------------------------------------------------------
    fifo_agent      #(DATA_WIDTH)             agent;
    fifo_scoreboard #(DATA_WIDTH, ADDR_WIDTH) scoreboard;
    fifo_coverage   #(DATA_WIDTH)             coverage;

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------
    function new(string name = "fifo_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // -------------------------------------------------------------------
    // Build Phase
    // -------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = fifo_agent      #(DATA_WIDTH)::type_id::create("agent",      this);
        scoreboard = fifo_scoreboard #(DATA_WIDTH, ADDR_WIDTH)::type_id::create("scoreboard", this);
        coverage   = fifo_coverage   #(DATA_WIDTH)::type_id::create("coverage",   this);
    endfunction

    // -------------------------------------------------------------------
    // Connect Phase
    // -------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        // Agent monitor AP  →  Scoreboard analysis export
        agent.ap.connect(scoreboard.analysis_export);
        // Agent monitor AP  →  Coverage subscriber
        agent.ap.connect(coverage.analysis_export);
    endfunction

endclass : fifo_env

`endif // FIFO_ENV_SV
