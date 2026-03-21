// =============================================================================
// File        : fifo_test.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : UVM Tests – base test + directed corner-case + full coverage
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_TEST_SV
`define FIFO_TEST_SV

// =============================================================================
// Base Test
// =============================================================================
class fifo_base_test #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) extends uvm_test;

    `uvm_component_param_utils(fifo_base_test #(DATA_WIDTH, ADDR_WIDTH))

    fifo_env #(DATA_WIDTH, ADDR_WIDTH) env;

    function new(string name = "fifo_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fifo_env #(DATA_WIDTH, ADDR_WIDTH)::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info(get_name(), "fifo_base_test: run_phase – override in child", UVM_MEDIUM)
    endtask

endclass

// =============================================================================
// Test 1 – Directed Corner-Case Test
//   Covers: reset, fill-to-full, drain-to-empty, simultaneous R+W
// =============================================================================
class fifo_directed_test #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) extends fifo_base_test #(DATA_WIDTH, ADDR_WIDTH);

    `uvm_component_param_utils(fifo_directed_test #(DATA_WIDTH, ADDR_WIDTH))

    function new(string name = "fifo_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_reset_seq   #(DATA_WIDTH)             rst_seq;
        fifo_fill_seq    #(DATA_WIDTH, ADDR_WIDTH) fill_seq;
        fifo_sim_rw_seq  #(DATA_WIDTH)             rw_seq;
        fifo_drain_seq   #(DATA_WIDTH, ADDR_WIDTH) drain_seq;

        phase.raise_objection(this, "Directed test running");
        `uvm_info(get_name(), ">>> Starting fifo_directed_test <<<", UVM_NONE)

        rst_seq   = fifo_reset_seq   #(DATA_WIDTH)::type_id::create("rst_seq");
        fill_seq  = fifo_fill_seq    #(DATA_WIDTH, ADDR_WIDTH)::type_id::create("fill_seq");
        rw_seq    = fifo_sim_rw_seq  #(DATA_WIDTH)::type_id::create("rw_seq");
        drain_seq = fifo_drain_seq   #(DATA_WIDTH, ADDR_WIDTH)::type_id::create("drain_seq");

        // Run sequences in order
        rst_seq.start(env.agent.sequencer);
        fill_seq.start(env.agent.sequencer);
        rw_seq.start(env.agent.sequencer);
        drain_seq.start(env.agent.sequencer);

        #50; // Allow final transactions to propagate
        phase.drop_objection(this, "Directed test done");
    endtask

endclass

// =============================================================================
// Test 2 – Constrained Random Coverage Test
// =============================================================================
class fifo_rand_test #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) extends fifo_base_test #(DATA_WIDTH, ADDR_WIDTH);

    `uvm_component_param_utils(fifo_rand_test #(DATA_WIDTH, ADDR_WIDTH))

    function new(string name = "fifo_rand_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_rand_seq #(DATA_WIDTH) rand_seq;

        phase.raise_objection(this, "Random test running");
        `uvm_info(get_name(), ">>> Starting fifo_rand_test <<<", UVM_NONE)

        rand_seq = fifo_rand_seq #(DATA_WIDTH)::type_id::create("rand_seq");
        rand_seq.num_txns = 500; // Run 500 random transactions
        rand_seq.start(env.agent.sequencer);

        #100;
        phase.drop_objection(this, "Random test done");
    endtask

endclass

// =============================================================================
// Test 3 – Full Stress Test (multiple fill-drain cycles)
// =============================================================================
class fifo_stress_test #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) extends fifo_base_test #(DATA_WIDTH, ADDR_WIDTH);

    `uvm_component_param_utils(fifo_stress_test #(DATA_WIDTH, ADDR_WIDTH))

    function new(string name = "fifo_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_stress_seq #(DATA_WIDTH, ADDR_WIDTH) stress_seq;

        phase.raise_objection(this, "Stress test running");
        `uvm_info(get_name(), ">>> Starting fifo_stress_test <<<", UVM_NONE)

        stress_seq = fifo_stress_seq #(DATA_WIDTH, ADDR_WIDTH)::type_id::create("stress_seq");
        stress_seq.num_cycles = 10;
        stress_seq.start(env.agent.sequencer);

        #100;
        phase.drop_objection(this, "Stress test done");
    endtask

endclass

`endif // FIFO_TEST_SV
