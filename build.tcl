set design_name "riscv_core"
set top_module "top"
set part "xck26-sfvc784-2LV-c"
set board_part "xilinx.com:kv260_som:part0:1.4"

# Directories
set rtl_dir "./rtl"
set constr_dir "./constraints"
set output_dir "./fpga_build"
set reports_dir "./fpga_reports"


file delete -force $output_dir
file delete -force $reports_dir
file mkdir $output_dir
file mkdir $reports_dir



read_verilog -sv [glob -nocomplain ${rtl_dir}/*.sv]
read_verilog -sv [glob -nocomplain ${rtl_dir}/core/*.sv]


read_xdc ${constr_dir}/timing.xdc


synth_design -top $top_module -part $part

write_checkpoint -force ${output_dir}/post_synth.dcp
report_utilization -file ${reports_dir}/post_synth_utilization.rpt
report_timing_summary -file ${reports_dir}/post_synth_timing.rpt

# Implementation
opt_design
write_checkpoint -force ${output_dir}/post_opt.dcp
report_utilization -file ${reports_dir}/post_opt_utilization.rpt

place_design
write_checkpoint -force ${output_dir}/post_place.dcp
report_utilization -file ${reports_dir}/post_place_utilization.rpt
report_timing_summary -file ${reports_dir}/post_place_timing.rpt

phys_opt_design
write_checkpoint -force ${output_dir}/post_phys_opt.dcp

route_design
write_checkpoint -force ${output_dir}/post_route.dcp
report_utilization -file ${reports_dir}/post_route_utilization.rpt
report_timing_summary -file ${reports_dir}/post_route_timing.rpt
report_drc -file ${reports_dir}/drc.rpt