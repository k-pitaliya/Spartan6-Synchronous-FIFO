# =============================================================================
# Makefile – Synchronous FIFO UVM Testbench
# Simulator  : QuestaSim / ModelSim (vlog / vsim)
# Author     : Kushal Pitaliya
# Usage      :
#   make all            – compile + run directed test
#   make sim TEST=fifo_rand_test    – run random test
#   make sim TEST=fifo_stress_test  – run stress test
#   make coverage       – run with functional + code coverage
#   make clean          – remove build artifacts
# =============================================================================

# --- Tool Configuration ---
VLOG    = vlog
VSIM    = vsim
VCOVER  = vcover

# --- Directories ---
SRC_DIR = ../src
TB_DIR  = .
OUT_DIR = work

# --- DUT Source ---
DUT_SRC = $(SRC_DIR)/fifo_sync.v

# --- UVM TB Sources (order matters) ---
TB_SRCS = \
    $(TB_DIR)/fifo_if.sv         \
    $(TB_DIR)/fifo_seq_item.sv   \
    $(TB_DIR)/fifo_sequences.sv  \
    $(TB_DIR)/fifo_driver.sv     \
    $(TB_DIR)/fifo_monitor.sv    \
    $(TB_DIR)/fifo_scoreboard.sv \
    $(TB_DIR)/fifo_coverage.sv   \
    $(TB_DIR)/fifo_agent.sv      \
    $(TB_DIR)/fifo_env.sv        \
    $(TB_DIR)/fifo_test.sv       \
    $(TB_DIR)/tb_top.sv

# --- Default Test ---
TEST ?= fifo_directed_test

# --- UVM Flags ---
UVM_HOME ?= $(MODEL_TECH)/../verilog_src/uvm-1.2
UVM_ARGS  = +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm_pkg.sv

# --- Compile Flags ---
VLOG_FLAGS = -sv -timescale 1ns/1ps \
             +define+UVM_NO_DEPRECATED \
             +define+UVM_OBJECT_MUST_BE_REGISTERED

# --- Simulation Flags ---
VSIM_FLAGS = -sv_seed random \
             +UVM_TESTNAME=$(TEST) \
             +UVM_VERBOSITY=UVM_MEDIUM \
             -do "run -all; quit"

# --- Coverage Flags ---
COV_FLAGS  = +cover=sbceft   # statement, branch, condition, expression, FSM, toggle

# =============================================================================
# Targets
# =============================================================================

.PHONY: all compile sim coverage report clean help

all: compile sim

## compile: Build the UVM library + DUT + TB
compile:
	@echo "======================================================"
	@echo "  COMPILING: DUT + UVM Testbench"
	@echo "======================================================"
	vlib $(OUT_DIR)
	vmap work $(OUT_DIR)
	$(VLOG) $(VLOG_FLAGS) $(UVM_ARGS) $(DUT_SRC) $(TB_SRCS)
	@echo "Compilation DONE."

## sim TEST=<name>: Run a specific UVM test
sim:
	@echo "======================================================"
	@echo "  RUNNING: $(TEST)"
	@echo "======================================================"
	$(VSIM) -c tb_top $(VSIM_FLAGS) | tee sim_$(TEST).log
	@echo "Simulation DONE. Log: sim_$(TEST).log"

## coverage: Compile with code + functional coverage enabled
coverage: clean
	@echo "======================================================"
	@echo "  COVERAGE RUN: $(TEST)"
	@echo "======================================================"
	vlib $(OUT_DIR)
	vmap work $(OUT_DIR)
	$(VLOG) $(VLOG_FLAGS) $(COV_FLAGS) $(UVM_ARGS) $(DUT_SRC) $(TB_SRCS)
	$(VSIM) -c tb_top $(VSIM_FLAGS) \
	    -coverage -do "coverage save -onexit cov_$(TEST).ucdb; run -all; quit"
	@echo "Coverage database: cov_$(TEST).ucdb"

## report: Generate HTML coverage report from last coverage run
report:
	@echo "Generating coverage report..."
	$(VCOVER) report -html cov_$(TEST).ucdb -output coverage_report/
	@echo "Open coverage_report/index.html in a browser."

## clean: Remove build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(OUT_DIR) transcript *.log *.wlf *.vcd *.ucdb vsim.wlf coverage_report/
	@echo "Clean complete."

## help: Show available targets
help:
	@echo ""
	@echo "FIFO UVM Testbench – Makefile Targets:"
	@echo "  make all                      – Compile + run directed test"
	@echo "  make sim TEST=fifo_rand_test  – Run random test"
	@echo "  make sim TEST=fifo_stress_test – Run stress test"
	@echo "  make coverage TEST=<name>     – Run with code + functional coverage"
	@echo "  make report                   – Generate HTML coverage report"
	@echo "  make clean                    – Remove all build artifacts"
	@echo ""
