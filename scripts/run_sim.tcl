set top     [lindex $argv 0]
set runtime [lindex $argv 1]

open_project vivado_proj/riscv_core.xpr

# regen BD sim products if needed (cheap if already done)
set bd [get_files axi_test.bd]
generate_target Simulation $bd

# point sim_1 at the requested top
set_property top $top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# hook a post-elab tcl that opens VCD before run
set_property -name {xsim.simulate.tcl.post} \
             -value [file normalize scripts/vcd_hook.tcl] \
             -objects [get_filesets sim_1]

# runtime: 'all' or explicit like '100us'
if {$runtime eq "all"} {
    set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
} else {
    set_property -name {xsim.simulate.runtime} -value $runtime -objects [get_filesets sim_1]
}

launch_simulation
