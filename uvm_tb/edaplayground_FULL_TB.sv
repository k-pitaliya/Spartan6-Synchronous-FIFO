// =============================================================================
// File        : fifo_if.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : SystemVerilog Interface for fifo_sync DUT
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_IF_SV
`define FIFO_IF_SV

interface fifo_if #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(input logic clk);

    // -------------------------------------------------------------------
    // DUT Ports
    // -------------------------------------------------------------------
    logic                   rst_n;
    logic                   wr_en;
    logic [DATA_WIDTH-1:0]  w_data;
    logic                   full;
    logic                   rd_en;
    logic [DATA_WIDTH-1:0]  r_data;
    logic                   empty;

    // -------------------------------------------------------------------
    // Clocking Block – Driver (active)
    // -------------------------------------------------------------------
    clocking driver_cb @(posedge clk);
        default input  #1step;
        default output #1;
        output rst_n;
        output wr_en;
        output w_data;
        output rd_en;
        input  full;
        input  empty;
        input  r_data;
    endclocking

    // -------------------------------------------------------------------
    // Clocking Block – Monitor (passive)
    // -------------------------------------------------------------------
    clocking monitor_cb @(posedge clk);
        default input #1step;
        input rst_n;
        input wr_en;
        input w_data;
        input full;
        input rd_en;
        input r_data;
        input empty;
    endclocking

    // -------------------------------------------------------------------
    // Modports
    // -------------------------------------------------------------------
    modport DRIVER  (clocking driver_cb,  input clk);
    modport MONITOR (clocking monitor_cb, input clk);

    // -------------------------------------------------------------------
    // Assertions – Flag Protocol Checks
    // -------------------------------------------------------------------
    // FULL flag: item_count == FIFO_DEPTH  →  no write should increment further
    property p_no_write_when_full;
        @(posedge clk) disable iff (!rst_n)
        (full && wr_en) |=> full;
    endproperty
    assert_no_write_when_full: assert property (p_no_write_when_full)
        else $error("[ASSERT] Write attempted when FIFO is FULL at time %0t", $time);

    // EMPTY flag: item_count == 0  →  no read should decrement further
    property p_no_read_when_empty;
        @(posedge clk) disable iff (!rst_n)
        (empty && rd_en) |=> empty;
    endproperty
    assert_no_read_when_empty: assert property (p_no_read_when_empty)
        else $error("[ASSERT] Read attempted when FIFO is EMPTY at time %0t", $time);

    // After reset, both full and empty must be in known state
    property p_reset_state;
        @(posedge clk)
        $fell(rst_n) |=> (!full && empty);
    endproperty
    assert_reset_state: assert property (p_reset_state)
        else $error("[ASSERT] Post-reset state invalid: full=%0b empty=%0b", full, empty);

endinterface : fifo_if

`endif // FIFO_IF_SV
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
// =============================================================================
// File        : fifo_coverage.sv
// Project     : Synchronous FIFO UVM Testbench
// Description : UVM Coverage Collector – functional coverage groups for FIFO
// Author      : Kushal Pitaliya
// =============================================================================
`ifndef FIFO_COVERAGE_SV
`define FIFO_COVERAGE_SV

class fifo_coverage #(parameter DATA_WIDTH = 8) extends uvm_subscriber #(fifo_seq_item #(DATA_WIDTH));

    `uvm_component_param_utils(fifo_coverage #(DATA_WIDTH))

    fifo_seq_item #(DATA_WIDTH) txn;

    // -------------------------------------------------------------------
    // Covergroup – Operation Types
    // -------------------------------------------------------------------
    covergroup cg_operations;
        cp_op_type: coverpoint txn.op_type {
            bins write_only = {fifo_seq_item#(DATA_WIDTH)::WRITE_ONLY};
            bins read_only  = {fifo_seq_item#(DATA_WIDTH)::READ_ONLY};
            bins read_write = {fifo_seq_item#(DATA_WIDTH)::READ_WRITE};
            bins idle       = {fifo_seq_item#(DATA_WIDTH)::IDLE};
        }

        cp_full: coverpoint txn.full {
            bins full_asserted    = {1'b1};
            bins full_deasserted  = {1'b0};
        }

        cp_empty: coverpoint txn.empty {
            bins empty_asserted   = {1'b1};
            bins empty_deasserted = {1'b0};
        }

        // Cross coverage: operation while full/empty
        cx_op_full:  cross cp_op_type, cp_full;
        cx_op_empty: cross cp_op_type, cp_empty;
    endgroup

    // -------------------------------------------------------------------
    // Covergroup – Data Boundary Coverage
    // -------------------------------------------------------------------
    covergroup cg_data_values;
        cp_wdata_boundaries: coverpoint txn.w_data {
            bins zero      = {8'h00};
            bins max_val   = {8'hFF};
            bins low_range = {[8'h01 : 8'h3F]};
            bins mid_range = {[8'h40 : 8'hBF]};
            bins hi_range  = {[8'hC0 : 8'hFE]};
        }
    endgroup

    // -------------------------------------------------------------------
    // Covergroup – Flag Transitions
    // -------------------------------------------------------------------
    // Track consecutive flag changes (fill, drain edge detection)
    logic prev_full  = 0;
    logic prev_empty = 1;

    covergroup cg_flag_transitions;
        cp_full_rise:  coverpoint (prev_full  == 0 && txn.full  == 1) { bins full_rise  = {1}; }
        cp_full_fall:  coverpoint (prev_full  == 1 && txn.full  == 0) { bins full_fall  = {1}; }
        cp_empty_rise: coverpoint (prev_empty == 0 && txn.empty == 1) { bins empty_rise = {1}; }
        cp_empty_fall: coverpoint (prev_empty == 1 && txn.empty == 0) { bins empty_fall = {1}; }
    endgroup

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------
    function new(string name = "fifo_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_operations       = new();
        cg_data_values      = new();
        cg_flag_transitions = new();
    endfunction

    // -------------------------------------------------------------------
    // write() – called every time monitor sends a transaction
    // -------------------------------------------------------------------
    function void write(fifo_seq_item #(DATA_WIDTH) t);
        txn = t;
        cg_operations.sample();
        cg_data_values.sample();
        cg_flag_transitions.sample();
        prev_full  = txn.full;
        prev_empty = txn.empty;
    endfunction

    // -------------------------------------------------------------------
    // Report Phase – Print Coverage Results
    // -------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("COVERAGE", "============================================", UVM_NONE)
        `uvm_info("COVERAGE", "       FUNCTIONAL COVERAGE SUMMARY          ", UVM_NONE)
        `uvm_info("COVERAGE", "============================================", UVM_NONE)
        `uvm_info("COVERAGE",
            $sformatf("cg_operations       : %.2f%%", cg_operations.get_coverage()),       UVM_NONE)
        `uvm_info("COVERAGE",
            $sformatf("cg_data_values      : %.2f%%", cg_data_values.get_coverage()),      UVM_NONE)
        `uvm_info("COVERAGE",
            $sformatf("cg_flag_transitions : %.2f%%", cg_flag_transitions.get_coverage()), UVM_NONE)
        `uvm_info("COVERAGE",
            $sformatf("TOTAL FUNCTIONAL COV: %.2f%%",
                (cg_operations.get_coverage() +
                 cg_data_values.get_coverage() +
                 cg_flag_transitions.get_coverage()) / 3.0),
            UVM_NONE)
        `uvm_info("COVERAGE", "============================================", UVM_NONE)
    endfunction

endclass : fifo_coverage

`endif // FIFO_COVERAGE_SV
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
// =============================================================================
// EDA Playground Top-Level Testbench
// Paste THIS file into the Testbench (right) panel on edaplayground.com
// Paste fifo_sync.v into the Design (left) panel
//
// Settings in EDA Playground:
//   Simulator : Aldec Riviera-PRO  (or Mentor Questa)
//   UVM/OVM   : UVM 1.2
//   Language  : SystemVerilog
// =============================================================================
`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

// ---- All UVM TB classes are pasted above this line in the same panel ----
// (EDA Playground compiles the entire right-panel as one file)

module tb_top;

    // -------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;

    // -------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    // -------------------------------------------------------------------
    // Interface
    // -------------------------------------------------------------------
    fifo_if #(.DATA_WIDTH(DATA_WIDTH)) dut_if (.clk(clk));

    // -------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------
    fifo_sync #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) DUT (
        .clk    (clk),
        .rst_n  (dut_if.rst_n),
        .wr_en  (dut_if.wr_en),
        .w_data (dut_if.w_data),
        .full   (dut_if.full),
        .rd_en  (dut_if.rd_en),
        .r_data (dut_if.r_data),
        .empty  (dut_if.empty)
    );

    // -------------------------------------------------------------------
    // UVM config_db + test launch
    // -------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual fifo_if #(.DATA_WIDTH(DATA_WIDTH)))::set(
            null, "uvm_test_top.*", "vif", dut_if
        );
        // Change "fifo_directed_test" to "fifo_rand_test" or "fifo_stress_test"
        run_test("fifo_directed_test");
    end

    // -------------------------------------------------------------------
    // Timeout Watchdog
    // -------------------------------------------------------------------
    initial begin
        #500000;
        `uvm_fatal("TIMEOUT", "Simulation exceeded 500us!")
    end

endmodule : tb_top
