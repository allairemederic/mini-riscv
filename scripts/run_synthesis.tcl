# Pour le rouler :
#   cd implementation
#   genus
#   source ../scripts/run_synthesis.tcl


# ---------------------------------------------------------------
# Configuration de Genus
# ---------------------------------------------------------------

set_db information_level 9
set_db hdl_vhdl_read_version 2008
set_db hdl_enable_real_support true
set_db init_hdl_search_path $::env(SRC_DIR)
set_db init_lib_search_path [list $::env(FE_TIM_LIB) $::env(BE_QRC_LIB) $::env(BE_LEF_LIB)]
read_libs -max_libs slow_vdd1v0_basicCells.lib -min_libs fast_vdd1v0_basicCells.lib
read_physical -lef [list gsclib045_tech.lef gsclib045_macro.lef]
read_qrc gpdk045.tch
set_db interconnect_mode ple


# ---------------------------------------------------------------
# Clock gating
# ---------------------------------------------------------------

set_db lp_insert_clock_gating true
set ::env(SYN_NET_DIR) $::env(SYN_CG_NET_DIR)
set ::env(SYN_REP_DIR) $::env(SYN_CG_REP_DIR)


# ---------------------------------------------------------------
# Elaboration
# ---------------------------------------------------------------

foreach name {
    riscv_pkg
    riscv_adder
    riscv_pc
    riscv_rf
    riscv_alu
} {
    read_hdl -vhdl -library work common/${name}.vhd
}

foreach name {
    riscv_pipeline_pkg
    riscv_fetch
    riscv_decode
    riscv_eswp_instruction
    riscv_execute
    riscv_memory_access
    riscv_write_back
    riscv_core
} {
    read_hdl -vhdl -library work core/${name}.vhd
}

elaborate riscv_core

check_design -unresolved


# ---------------------------------------------------------------
# Contraintes
# ---------------------------------------------------------------

# Apparait dans /implementation/syn/base_reports

read_sdc $::env(CONST_DIR)/timing.sdc
report_timing -lint > $::env(SYN_REP_DIR)/riscv_core.timing_lint.rpt
report_clocks > $::env(SYN_REP_DIR)/riscv_core.clk.rpt
report_clocks -generated > $::env(SYN_REP_DIR)/riscv_core.generated_clk.rpt


# ---------------------------------------------------------------
# Synthese
# ---------------------------------------------------------------

# Apparait dans /implementation/syn/base_netlist

set_db syn_generic_effort high
syn_generic riscv_core
write_hdl > $::env(SYN_NET_DIR)/riscv_core.syn_gen.v

set_db syn_map_effort high
syn_map riscv_core
write_hdl > $::env(SYN_NET_DIR)/riscv_core.syn_map.v

set_db syn_opt_effort high
syn_opt riscv_core
write_hdl > $::env(SYN_NET_DIR)/riscv_core.syn_opt.v


# ---------------------------------------------------------------
# Netlist
# ---------------------------------------------------------------

write_hdl > $::env(SYN_NET_DIR)/riscv_core.syn.v
write_sdf -nonegchecks -setuphold split -version 2.1 > $::env(SYN_NET_DIR)/riscv_core.syn.sdf
write_sdc > $::env(CONST_DIR)/riscv_core.syn.sdc


# ---------------------------------------------------------------
# Rapport
# ---------------------------------------------------------------

report_timing > $::env(SYN_REP_DIR)/riscv_core.syn.timing.rpt
report_area > $::env(SYN_REP_DIR)/riscv_core.syn.area.rpt
report_gates > $::env(SYN_REP_DIR)/riscv_core.syn.gates.rpt
report_power > $::env(SYN_REP_DIR)/riscv_core.syn.power.rpt