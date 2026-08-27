# Vivado synthesis/timing for the new dynamic-key core.
# Target: Digilent Genesys ZU-5EV, XCZU5EV-SFVC784-1-E.
# This is synthesis only; no board pins are assigned because this top is a
# crypto engine, not a board I/O wrapper.
set proj_name aes256_dynamic_genesys_zu5ev
set part_name xczu5ev-sfvc784-1-e

create_project $proj_name ./vivado_${proj_name} -part $part_name -force
add_files [list \
    src/aes_sbox.v \
    src/aes_subbytes.v \
    src/aes_shiftrows.v \
    src/aes_mixcolumns.v \
    src/aes256_keyexp_step.v \
    src/aes256_pipeline_dynamic_key.v \
]
add_files -fileset constrs_1 src/dynamic_core_clock.xdc
set_property top aes256_pipeline_dynamic_key [current_fileset]
update_compile_order -fileset sources_1
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
launch_runs synth_1 -jobs 6
wait_on_run synth_1

open_run synth_1 -name synth_1
report_utilization -file ./dynamic_utilization.rpt
report_timing_summary -delay_type max -max_paths 20 -file ./dynamic_timing_summary.rpt

set timing_paths [get_timing_paths -delay_type max -max_paths 1]
if {[llength $timing_paths] == 0} {
    error "No timing path found; check clock constraint and top-level ports"
}
set wns [get_property SLACK [lindex $timing_paths 0]]
set required 20.0
set actual_period [expr {$required - $wns}]
set fmax [expr {1000.0 / $actual_period}]
puts "DYNAMIC_CORE_WNS_NS=$wns"
puts "DYNAMIC_CORE_EST_FMAX_MHZ=$fmax"
puts "Reports: dynamic_utilization.rpt dynamic_timing_summary.rpt"
