# Recreate the Vivado project without launching synthesis.
# Target: Digilent Genesys ZU-5EV (XCZU5EV-SFVC784-1-E).
set project_name aes256_genesys_zu5ev
set project_dir [file normalize "./vivado_${project_name}"]
set part_name xczu5ev-sfvc784-1-e

create_project $project_name $project_dir -part $part_name -force

add_files -fileset sources_1 [list \
    [file normalize "src/aes_sbox.v"] \
    [file normalize "src/aes_subbytes.v"] \
    [file normalize "src/aes_shiftrows.v"] \
    [file normalize "src/aes_mixcolumns.v"] \
    [file normalize "src/aes256_keyexp_step.v"] \
    [file normalize "src/aes256_pipeline_dynamic_key.v"] \
]

add_files -fileset constrs_1 [file normalize "src/dynamic_core_clock.xdc"]

add_files -fileset sim_1 [list \
    [file normalize "src/aes_keyschedule.v"] \
    [file normalize "src/aes_top.v"] \
    [file normalize "tb/tb_aes256_keyexp_rounds.v"] \
    [file normalize "tb/tb_aes256_dynamic_key.v"] \
    [file normalize "tb/tb_aes256_dynamic_key_stress.v"] \
    [file normalize "tb/tb_aes256_pipeline_dynamic_100keys.v"] \
    [file normalize "tb/tb_aes256_pipeline_dynamic_100keys_log.v"] \
]

set_property top aes256_pipeline_dynamic_key [current_fileset]
set_property top tb_aes256_pipeline_dynamic_100keys_log [get_filesets sim_1]
set_property simulator_language Verilog [current_project]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property target_simulator xsim [current_project]
save_project

puts "Vivado project created: $project_dir/$project_name.xpr"
puts "Synthesis top: aes256_pipeline_dynamic_key"
puts "Simulation top: tb_aes256_pipeline_dynamic_100keys_log"
