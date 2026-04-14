// Packages first
rtl/core_pkg.sv
rtl/axi/axi_if.sv

// Actual rtl files then
// First core
rtl/core/alu/alu.sv
rtl/core/alu/division_alu.sv
rtl/core/register_file.sv
rtl/axi/axi_master.sv


rtl/core/core.sv
rtl/core/stages/fetch.sv
rtl/core/stages/decode.sv
rtl/core/stages/exec.sv
rtl/core/stages/mem.sv
rtl/core/stages/rf_writeback.sv

rtl/memory.sv
rtl/uart_tx.sv

rtl/top.sv
rtl/top_wrapper.v
