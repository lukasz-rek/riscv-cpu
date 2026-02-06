set_device GW5AST-LV138PG484AC1/I0 -device_version C
set_option -verilog_std sysv2017

# Add RTL files
add_file rtl/core_pkg.sv
add_file rtl/core/alu.sv
add_file rtl/core/register_file.sv
add_file rtl/core/core.sv
add_file rtl/memory.sv
add_file rtl/top.sv

# Add constraints file
add_file constraints.sdc

# Set top module
set_option -top_module top

# Run synthesis and PNR
run all