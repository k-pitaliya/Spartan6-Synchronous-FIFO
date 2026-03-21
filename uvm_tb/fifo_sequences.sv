// =============================================================================
// File        : fifo_sequences.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : UVM Sequences – base, directed corner-case, random, stress
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_SEQUENCES_SV
`define FIFO_SEQUENCES_SV

// =============================================================================
// Base Sequence
// =============================================================================
class fifo_base_seq #(parameter DATA_WIDTH = 8) extends uvm_sequence #(fifo_seq_item #(DATA_WIDTH));
    `uvm_object_param_utils(fifo_base_seq #(DATA_WIDTH))

    function new(string name = "fifo_base_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info(get_name(), "fifo_base_seq::body – override in child", UVM_MEDIUM)
    endtask
endclass

// =============================================================================
// Sequence 1 – Reset & Idle (sanity check)
// =============================================================================
class fifo_reset_seq #(parameter DATA_WIDTH = 8) extends fifo_base_seq #(DATA_WIDTH);
    `uvm_object_param_utils(fifo_reset_seq #(DATA_WIDTH))

    function new(string name = "fifo_reset_seq");
        super.new(name);
    endfunction

    task body();
        fifo_seq_item #(DATA_WIDTH) txn;
        txn = fifo_seq_item #(DATA_WIDTH)::type_id::create("txn");
        repeat (5) begin
            start_item(txn);
            if (!txn.randomize() with {wr_en == 0; rd_en == 0;})
                `uvm_fatal("RAND_FAIL", "Randomize failed in fifo_reset_seq")
            finish_item(txn);
        end
        `uvm_info(get_name(), "fifo_reset_seq DONE", UVM_MEDIUM)
    endtask
endclass

// =============================================================================
// Sequence 2 – Fill FIFO to FULL (write until full)
// =============================================================================
class fifo_fill_seq #(parameter DATA_WIDTH = 8, parameter ADDR_WIDTH = 4)
    extends fifo_base_seq #(DATA_WIDTH);
    
    `uvm_object_param_utils(fifo_fill_seq #(DATA_WIDTH, ADDR_WIDTH))

    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;

    function new(string name = "fifo_fill_seq");
        super.new(name);
    endfunction

    task body();
        fifo_seq_item #(DATA_WIDTH) txn;
        txn = fifo_seq_item #(DATA_WIDTH)::type_id::create("txn");
        
        `uvm_info(get_name(), $sformatf("Filling FIFO to FULL (%0d entries)", FIFO_DEPTH), UVM_MEDIUM)
        repeat (FIFO_DEPTH) begin
            start_item(txn);
            if (!txn.randomize() with {wr_en == 1; rd_en == 0;})
                `uvm_fatal("RAND_FAIL", "Randomize failed in fifo_fill_seq")
            finish_item(txn);
        end
    endtask
endclass

// =============================================================================
// Sequence 3 – Drain FIFO (read until empty)
// =============================================================================
class fifo_drain_seq #(parameter DATA_WIDTH = 8, parameter ADDR_WIDTH = 4)
    extends fifo_base_seq #(DATA_WIDTH);

    `uvm_object_param_utils(fifo_drain_seq #(DATA_WIDTH, ADDR_WIDTH))

    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;

    function new(string name = "fifo_drain_seq");
        super.new(name);
    endfunction

    task body();
        fifo_seq_item #(DATA_WIDTH) txn;
        txn = fifo_seq_item #(DATA_WIDTH)::type_id::create("txn");

        `uvm_info(get_name(), "Draining FIFO to EMPTY", UVM_MEDIUM)
        repeat (FIFO_DEPTH) begin
            start_item(txn);
            if (!txn.randomize() with {wr_en == 0; rd_en == 1;})
                `uvm_fatal("RAND_FAIL", "Randomize failed in fifo_drain_seq")
            finish_item(txn);
        end
    endtask
endclass

// =============================================================================
// Sequence 4 – Simultaneous Read + Write (corner case)
// =============================================================================
class fifo_sim_rw_seq #(parameter DATA_WIDTH = 8) extends fifo_base_seq #(DATA_WIDTH);
    `uvm_object_param_utils(fifo_sim_rw_seq #(DATA_WIDTH))

    int unsigned num_txns = 32;

    function new(string name = "fifo_sim_rw_seq");
        super.new(name);
    endfunction

    task body();
        fifo_seq_item #(DATA_WIDTH) txn;
        txn = fifo_seq_item #(DATA_WIDTH)::type_id::create("txn");

        `uvm_info(get_name(), "Running simultaneous R+W sequence", UVM_MEDIUM)
        repeat (num_txns) begin
            start_item(txn);
            if (!txn.randomize() with {wr_en == 1; rd_en == 1;})
                `uvm_fatal("RAND_FAIL", "Randomize failed in fifo_sim_rw_seq")
            finish_item(txn);
        end
    endtask
endclass

// =============================================================================
// Sequence 5 – Constrained Random (full coverage stimulus)
// =============================================================================
class fifo_rand_seq #(parameter DATA_WIDTH = 8) extends fifo_base_seq #(DATA_WIDTH);
    `uvm_object_param_utils(fifo_rand_seq #(DATA_WIDTH))

    int unsigned num_txns = 200;

    function new(string name = "fifo_rand_seq");
        super.new(name);
    endfunction

    task body();
        fifo_seq_item #(DATA_WIDTH) txn;
        `uvm_info(get_name(), $sformatf("Running %0d random transactions", num_txns), UVM_MEDIUM)
        repeat (num_txns) begin
            txn = fifo_seq_item #(DATA_WIDTH)::type_id::create("txn");
            start_item(txn);
            if (!txn.randomize())
                `uvm_fatal("RAND_FAIL", "Randomize failed in fifo_rand_seq")
            finish_item(txn);
        end
    endtask
endclass

// =============================================================================
// Sequence 6 – Stress (back-to-back fill-drain cycles)
// =============================================================================
class fifo_stress_seq #(parameter DATA_WIDTH = 8, parameter ADDR_WIDTH = 4)
    extends fifo_base_seq #(DATA_WIDTH);

    `uvm_object_param_utils(fifo_stress_seq #(DATA_WIDTH, ADDR_WIDTH))

    int unsigned num_cycles = 5;

    function new(string name = "fifo_stress_seq");
        super.new(name);
    endfunction

    task body();
        fifo_fill_seq  #(DATA_WIDTH, ADDR_WIDTH) fill_seq;
        fifo_drain_seq #(DATA_WIDTH, ADDR_WIDTH) drain_seq;
        fifo_sim_rw_seq #(DATA_WIDTH) rw_seq;

        `uvm_info(get_name(), $sformatf("Running %0d fill-drain stress cycles", num_cycles), UVM_MEDIUM)
        repeat (num_cycles) begin
            fill_seq  = fifo_fill_seq  #(DATA_WIDTH, ADDR_WIDTH)::type_id::create("fill_seq");
            drain_seq = fifo_drain_seq #(DATA_WIDTH, ADDR_WIDTH)::type_id::create("drain_seq");
            rw_seq    = fifo_sim_rw_seq #(DATA_WIDTH)::type_id::create("rw_seq");

            fill_seq.start(m_sequencer);
            rw_seq.start(m_sequencer);
            drain_seq.start(m_sequencer);
        end
    endtask
endclass

`endif // FIFO_SEQUENCES_SV
