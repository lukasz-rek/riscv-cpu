# This should strip comments from the file and give us a nice list
RTL_FILES := $(shell grep -v '^\s*\(//\|$$\)' files.f | grep '\.s\?v$$')
TB_FILES := $(wildcard tb/*.sv)
VERILATOR_FLAGS = -Wall -Wno-fatal --trace-fst --trace
TOP_MODULE_NAME = top

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

code:
	@$(MAKE) -C code all

format:
	@echo "Formating..."
	verible-verilog-format --inplace $(RTL_FILES)

# Much quicker
lint:
	@echo "Linting..."
	@verilator --lint-only $(VERILATOR_FLAGS) $(RTL_FILES) --top-module $(TOP_MODULE_NAME)

wave:
	@echo "Opening waveform"
	@gtkwave logs/top_tb.fst

clean:
	@echo "Cleaning up..."
	@rm -r build
	@echo "Cleaned"

.PHONY: build clean run lint code wave