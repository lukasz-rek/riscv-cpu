set top      [lindex $argv 0]
set runtime  [lindex $argv 1]
set plusargs [lindex $argv 2]

open_project vivado_proj/riscv_core.xpr

generate_target Simulation [get_files axi_test.bd]

set_property top     $top           [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# No VCD for arch tests — speed matters
set_property -name {xsim.simulate.tcl.post} -value {} -objects [get_filesets sim_1]

if {$runtime eq "all"} {
    set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
} else {
    set_property -name {xsim.simulate.runtime} -value $runtime -objects [get_filesets sim_1]
}

# Convert "+FOO=bar +BAZ=qux" -> "-testplusarg FOO=bar -testplusarg BAZ=qux"
set more_opts ""
foreach arg [split $plusargs " "] {
    if {$arg ne ""} {
        append more_opts " -testplusarg [string trimleft $arg +]"
    }
}
if {$more_opts ne ""} {
    set_property -name {xsim.simulate.xsim.more_options} \
                 -value $more_opts -objects [get_filesets sim_1]
}

launch_simulation
close_project