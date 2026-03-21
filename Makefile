# This should strip comments from the file and give us a nice list
RTL_FILES := $(shell grep -v '^\s*\(//\|$$\)' files.f | grep '\.s\?v$$')
TB_FILES := $(wildcard tb/*.sv)
VERILATOR_FLAGS = -Wall -Wno-fatal --x-assign fast --x-initial fast
# Note to myself, never use threads, even 2 seem to kill perf
VERILATOR_FLAGS += -CFLAGS "-O3 -march=native"
# VERILATOR_FLAGS +=  --trace-structs --trace-fst --trace
TOP_MODULE_NAME = top

# Stuff for copying over bitstream
VIVADO_IMPL_DIR := $(HOME)/Projekty/cpu/vivado_proj/riscv_core.runs/impl_1
BIT_FILE := $(VIVADO_IMPL_DIR)/system_wrapper.bit
BIN_FILE := $(VIVADO_IMPL_DIR)/system_wrapper.bit.bin
BIF_FILE := $(VIVADO_IMPL_DIR)/bitstream.bif

build: code
	@echo "Compiling all modules..."

	@echo "===== Found rtl source files: "
	@echo "$(RTL_FILES)"

	@echo "===== Found tb files: "
	@echo "$(TB_FILES)"

	@echo "Compiling..."
	@mkdir -p build
	@verilator $(VERILATOR_FLAGS) --cc $(RTL_FILES) $(TB_FILES) --exe --build -j 0 -Mdir build --timing --main --top-module $(TOP_MODULE_NAME)_tb
	@echo "Done"

run:
	@echo "Running simulation..."
	@./build/V$(TOP_MODULE_NAME)_tb

vivado:
	# TODO: I gotta revise the build.tcl
	@echo "Removing vivado project"
	@rm -r vivado_proj/
	@echo "Starting build"
	@vivado_batch build.tcl

code:
	@$(MAKE) -C code all

coremark:
	@$(MAKE) -C code/coremark clean
	@$(MAKE) -C code/coremark

format:
	@echo "Formating..."
	verible-verilog-format --inplace $(RTL_FILES) --indentation_spaces 4

# Much quicker
lint:
	@echo "Linting..."
	@verilator --lint-only $(VERILATOR_FLAGS) $(RTL_FILES) --top-module $(TOP_MODULE_NAME)

wave:
	@echo "Opening waveform"
	@surfer logs/top_tb.fst -s logs/signals

bitstream: $(BIN_FILE)
	scp $(BIN_FILE) kria:~/bitstreams/bitstream.bit.bin

$(BIN_FILE): $(BIT_FILE)
	source ~/Apps/vivado/2025.2/Vivado/settings64.sh && \
	cd $(VIVADO_IMPL_DIR) && \
	echo 'the_ROM_image: { [destination_device=pl] system_wrapper.bit }' > $(BIF_FILE) && \
	bootgen -image $(BIF_FILE) -arch zynqmp -o $(BIN_FILE) -w


clean:
	@echo "Cleaning up..."
	@rm -r build
	@echo "Cleaned"

.PHONY: build clean run lint code wave
