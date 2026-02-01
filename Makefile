RTL_FILES := $(wildcard rtl/*.sv)
TB_FILES := $(wildcard tb/*.sv)
VERILATOR_FLAGS = -Wall -Wno-fatal --trace-fst --trace
TOP_MODULE_NAME = adder

build: 
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


# Much quicker
lint:
	@echo "Linting..."
	@verilator --lint-only $(VERILATOR_FLAGS) $(RTL_FILES)

clean:
	@echo "Cleaning up..."
	@rm -r build
	@echo "Cleaned"

.PHONY: build clean run lint