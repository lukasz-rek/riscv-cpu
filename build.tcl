set design_name "riscv_core"
set top_module "top"
set part "xck26-sfvc784-2LV-c"
set board_part "xilinx.com:kv260_som:part0:1.4"

# Directories
set rtl_dir "./rtl"
set constr_dir "./constraints"
set output_dir "./fpga_build"
set reports_dir "./fpga_reports"
set proj_dir "./vivado_proj"

file delete -force $output_dir
file delete -force $reports_dir
file mkdir $output_dir
file mkdir $reports_dir

# ── Try opening existing project, create fresh if not found ──
set proj_file "${proj_dir}/${design_name}.xpr"
if {[file exists $proj_file]} {
    puts "INFO: Opening existing project..."
    open_project $proj_file
    reset_run synth_1
} else {
    puts "INFO: Creating new project..."
    create_project $design_name $proj_dir -part $part -force
    set_property board_part $board_part [current_project]

    # Add RTL sources (recursive) and constraints
    add_files -scan_for_includes [glob -nocomplain ${rtl_dir}/*.sv ${rtl_dir}/*.v ${rtl_dir}/**/*.sv ${rtl_dir}/**/*.v]
    set_property file_type SystemVerilog [get_files *.sv]
    add_files -fileset constrs_1 -norecurse ${constr_dir}/timing.xdc

    # Automatic compile order (required for module references)
    set_property source_mgmt_mode All [current_project]
    update_compile_order -fileset sources_1

    # ── Block design: Zynq PS provides clock + reset ──
    create_bd_design "system"

    # Add Zynq UltraScale+ MPSoC and apply K26 board preset
    create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ps
    apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} [get_bd_cells zynq_ps]

    # Set PL clock frequency (MHz) - adjust to meet timing
    set_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ 95 [get_bd_cells zynq_ps]

    # Disable AXI master ports (we don't need PS-PL AXI for now)
    set_property -dict [list \
        CONFIG.PSU__USE__M_AXI_GP0 {0} \
        CONFIG.PSU__USE__M_AXI_GP1 {0} \
        CONFIG.PSU__USE__M_AXI_GP2 {0} \
    ] [get_bd_cells zynq_ps]

    # Add our RTL top module as a module reference
    create_bd_cell -type module -reference top_wrapper top_wrapper_0

    # Connect clock: PS FCLK_CLK0 -> top.clk
    connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins top_wrapper_0/clk]

    # Add processor system reset for clean reset
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 ps_reset
    connect_bd_net [get_bd_pins zynq_ps/pl_clk0]      [get_bd_pins ps_reset/slowest_sync_clk]
    connect_bd_net [get_bd_pins zynq_ps/pl_resetn0]    [get_bd_pins ps_reset/ext_reset_in]
    connect_bd_net [get_bd_pins ps_reset/peripheral_aresetn] [get_bd_pins top_wrapper_0/rst_n]

    # Expose UART TX as external port
    create_bd_port -dir O uart_tx
    connect_bd_net [get_bd_pins top_wrapper_0/uart_tx] [get_bd_ports uart_tx]

    # Validate and save
    validate_bd_design
    save_bd_design

    # Generate block design outputs
    generate_target all [get_files system.bd]

    # Create HDL wrapper and set as top
    make_wrapper -files [get_files system.bd] -top
    add_files -norecurse ${proj_dir}/${design_name}.gen/sources_1/bd/system/hdl/system_wrapper.v
    set_property top system_wrapper [current_fileset]
    update_compile_order -fileset sources_1
}

# ── Synthesis (sequential to avoid parallel process hangs) ──
launch_runs synth_1 -jobs 1
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    error "Synthesis failed — check vivado_proj/riscv_core.runs/synth_1/runme.log"
}

# ── Implementation ──
launch_runs impl_1 -to_step write_bitstream -jobs 1
wait_on_run impl_1

open_run impl_1
report_utilization -file ${reports_dir}/post_route_utilization.rpt
report_timing_summary -file ${reports_dir}/post_route_timing.rpt
report_drc -file ${reports_dir}/drc.rpt
write_checkpoint -force ${output_dir}/post_route.dcp

# ── Move Vivado log/journal files and clockInfo into logs dir ──
set logs_dir "./fpga_logs"
file mkdir $logs_dir
foreach f [glob -nocomplain vivado*.log vivado*.jou clockInfo.txt] {
    file rename -force $f ${logs_dir}/[file tail $f]
}
