// =============================================================================
// File        : fifo_seq_item.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : UVM Sequence Item (Transaction) for FIFO
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_SEQ_ITEM_SV
`define FIFO_SEQ_ITEM_SV

class fifo_seq_item #(parameter DATA_WIDTH = 8) extends uvm_sequence_item;

    `uvm_object_param_utils(fifo_seq_item #(DATA_WIDTH))

    // -------------------------------------------------------------------
    // Randomizable Fields
    // -------------------------------------------------------------------
    rand logic                  wr_en;
    rand logic                  rd_en;
    rand logic [DATA_WIDTH-1:0] w_data;

    // -------------------------------------------------------------------
    // Observed Output Fields (not randomized)
    // -------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] r_data;
    logic                  full;
    logic                  empty;

    // -------------------------------------------------------------------
    // Operation Type (for scoreboard and coverage)
    // -------------------------------------------------------------------
    typedef enum logic [1:0] {
        WRITE_ONLY = 2'b10,
        READ_ONLY  = 2'b01,
        READ_WRITE = 2'b11,
        IDLE       = 2'b00
    } op_type_e;

    op_type_e op_type;

    // -------------------------------------------------------------------
    // Constraints
    // -------------------------------------------------------------------
    // Distribute operation types: 35% write, 35% read, 20% R+W, 10% idle
    constraint c_op_dist {
        {wr_en, rd_en} dist {
            2'b10 := 35,
            2'b01 := 35,
            2'b11 := 20,
            2'b00 := 10
        };
    }

    // Valid data range – full data width utilization
    constraint c_data_range {
        w_data inside {[0 : (2**DATA_WIDTH)-1]};
    }

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------
    function new(string name = "fifo_seq_item");
        super.new(name);
    endfunction

    // -------------------------------------------------------------------
    // Post-Randomize: Set op_type
    // -------------------------------------------------------------------
    function void post_randomize();
        case ({wr_en, rd_en})
            2'b10: op_type = WRITE_ONLY;
            2'b01: op_type = READ_ONLY;
            2'b11: op_type = READ_WRITE;
            2'b00: op_type = IDLE;
        endcase
    endfunction

    // -------------------------------------------------------------------
    // do_copy / do_compare / convert2string
    // -------------------------------------------------------------------
    function void do_copy(uvm_object rhs);
        fifo_seq_item #(DATA_WIDTH) rhs_;
        if (!$cast(rhs_, rhs))
            `uvm_fatal("CAST_ERR", "do_copy: cast failed")
        super.do_copy(rhs);
        wr_en  = rhs_.wr_en;
        rd_en  = rhs_.rd_en;
        w_data = rhs_.w_data;
        r_data = rhs_.r_data;
        full   = rhs_.full;
        empty  = rhs_.empty;
        op_type = rhs_.op_type;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        fifo_seq_item #(DATA_WIDTH) rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (super.do_compare(rhs, comparer) &&
                (wr_en  == rhs_.wr_en)  &&
                (rd_en  == rhs_.rd_en)  &&
                (w_data == rhs_.w_data));
    endfunction

    function string convert2string();
        return $sformatf(
            "[FIFO_TXN] op=%s wr_en=%0b rd_en=%0b w_data=0x%02h r_data=0x%02h full=%0b empty=%0b",
            op_type.name(), wr_en, rd_en, w_data, r_data, full, empty
        );
    endfunction

endclass : fifo_seq_item

`endif // FIFO_SEQ_ITEM_SV
