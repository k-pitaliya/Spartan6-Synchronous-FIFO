// fifo_sequences.sv  -  Kushal Pitaliya
// All sequences used in the FIFO testbench.
// 1. fifo_fill_seq    - writes until FIFO is full
// 2. fifo_drain_seq   - reads until FIFO is empty
// 3. fifo_rw_seq      - simultaneous read+write (the corner case that found the NBA bug)
// 4. fifo_rand_seq    - constrained random for coverage closure
`ifndef FIFO_SEQUENCES_SV
`define FIFO_SEQUENCES_SV

// fill FIFO to full (16 writes)
class fifo_fill_seq extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_fill_seq)
    function new(string name = "fifo_fill_seq"); super.new(name); endfunction

    task body();
        fifo_seq_item t;
        `uvm_info(get_name(), "filling FIFO to full...", UVM_MEDIUM)
        repeat (16) begin
            t = fifo_seq_item::type_id::create("t");  // Create new object each iteration
            start_item(t);
            void'(t.randomize() with { wr_en == 1; rd_en == 0; });
            finish_item(t);
        end
    endtask
endclass

// read everything out
class fifo_drain_seq extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_drain_seq)
    function new(string name = "fifo_drain_seq"); super.new(name); endfunction

    task body();
        fifo_seq_item t;
        `uvm_info(get_name(), "draining FIFO to empty...", UVM_MEDIUM)
        repeat (16) begin
            t = fifo_seq_item::type_id::create("t");  // Create new object each iteration
            start_item(t);
            void'(t.randomize() with { wr_en == 0; rd_en == 1; });
            finish_item(t);
        end
    endtask
endclass

// simultaneous read + write
// this is the sequence that caught the item_count NBA bug in the original RTL
class fifo_rw_seq extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_rw_seq)
    int unsigned num_txns = 16;
    function new(string name = "fifo_rw_seq"); super.new(name); endfunction

    task body();
        fifo_seq_item t;
        `uvm_info(get_name(), "running simultaneous R+W...", UVM_MEDIUM)
        repeat (num_txns) begin
            t = fifo_seq_item::type_id::create("t");  // Create new object each iteration
            start_item(t);
            void'(t.randomize() with { wr_en == 1; rd_en == 1; });
            finish_item(t);
        end
    endtask
endclass

// constrained random - uses the default constraint from fifo_seq_item
class fifo_rand_seq extends uvm_sequence #(fifo_seq_item);
    `uvm_object_utils(fifo_rand_seq)
    int unsigned num_txns = 200;
    function new(string name = "fifo_rand_seq"); super.new(name); endfunction

    task body();
        fifo_seq_item t;
        `uvm_info(get_name(), $sformatf("running %0d random transactions", num_txns), UVM_MEDIUM)
        repeat (num_txns) begin
            t = fifo_seq_item::type_id::create("t");
            start_item(t);
            void'(t.randomize());
            finish_item(t);
        end
    endtask
endclass

`endif
