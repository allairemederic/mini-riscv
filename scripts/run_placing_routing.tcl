# ---------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------

set ::env(PNR_NET_DIR) $::env(PNR_CG_NET_DIR)
set ::env(PNR_REP_DIR) $::env(PNR_CG_REP_DIR)
set ::env(PNR_SAVE_DIR) [file join $::env(PNR_DIR) save cg]
file mkdir $::env(PNR_SAVE_DIR)

set init_lef_file [list $::env(BE_LEF_LIB)/gsclib045_tech.lef $::env(BE_LEF_LIB)/gsclib045_macro.lef]
set init_verilog $::env(SYN_CG_NET_DIR)/riscv_core.syn.v
set init_design_settop 1
set init_top_cell riscv_core
set init_gnd_net VSS
set init_pwr_net VDD
set init_mmmc_file $::env(CONST_DIR)/mmmc.tcl

init_design


# ---------------------------------------------------------------
# Floorplan et alimentations
# ---------------------------------------------------------------

floorPlan -site CoreSite -r 0.9 0.6 1 1 1 1

globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override
globalNetConnect VDD -type tiehi -inst * -override
globalNetConnect VSS -type tielo -inst * -override

addStripe -nets VDD -layer Metal1 -direction vertical -width 0.6 -number_of_sets 1 -start_from left -start_offset -0.8
addStripe -nets VSS -layer Metal1 -direction vertical -width 0.6 -number_of_sets 1 -start_from right -start_offset -0.8

sroute -nets { VDD VSS } -connect { corePin floatingStripe }

setPinAssignMode -pinEditInBatch true

# Horloge et reset
editPin -pin {i_clk i_rstn} -edge 1 -layer 4 -spreadType SIDE \
    -offsetEnd 2 -offsetStart 2 -spreadDirection clockwise \
    -pinWidth 0.08 -pinDepth 0.335 -fixOverlap 1

# Interface de la memoire d'instructions
set imem_pins {o_imem_en}

for {set bit 0} {$bit < 9} {incr bit} {
    lappend imem_pins [format {o_imem_addr[%d]} $bit]
}

for {set bit 0} {$bit < 32} {incr bit} {
    lappend imem_pins [format {i_imem_read[%d]} $bit]
}

editPin -pin $imem_pins -edge 0 -layer 3 -spreadType SIDE \
    -offsetEnd 2 -offsetStart 2 -spreadDirection clockwise \
    -pinWidth 0.08 -pinDepth 0.335 -fixOverlap 1

# Interface de la memoire de donnees
set dmem_pins {o_dmem_en o_dmem_we}

for {set bit 0} {$bit < 9} {incr bit} {
    lappend dmem_pins [format {o_dmem_addr[%d]} $bit]
}

for {set bit 0} {$bit < 32} {incr bit} {
    lappend dmem_pins [format {i_dmem_read[%d]} $bit]
    lappend dmem_pins [format {o_dmem_write[%d]} $bit]
}

editPin -pin $dmem_pins -edge 3 -layer 4 -spreadType SIDE \
    -offsetEnd 2 -offsetStart 2 -spreadDirection counterclockwise \
    -pinWidth 0.08 -pinDepth 0.335 -fixOverlap 1

# Broches de test presentes dans l'interface du core
editPin -pin {i_scan_en i_test_mode i_tdi o_tdo} \
    -edge 2 -layer 3 -spreadType SIDE \
    -offsetEnd 2 -offsetStart 2 -spreadDirection clockwise \
    -pinWidth 0.08 -pinDepth 0.335 -fixOverlap 1

setPinAssignMode -pinEditInBatch false


# ---------------------------------------------------------------
# Placement
# ---------------------------------------------------------------

timeDesign -prePlace -outDir $::env(PNR_REP_DIR)/timing

setDesignMode -process 45 -flowEffort standard

# Mettre -place_global_reorder_scan true pour DFT
setPlaceMode -timingDriven true -place_global_cong_effort auto -place_global_reorder_scan false

# Seulement pour DFT
# setPlaceMode -place_global_reorder_scan false
# deleteAllScanCells
# setPlaceMode -place_global_reorder_scan true
# defIn $::env(SYN_NET_DIR)/riscv_core.syn.scandef
# setScanReorderMode -compLogic true

place_opt_design

# Seulement pour DFT
# defOutBySection $::env(PNR_NET_DIR)/compteur.place.scandef -noNets -noComps -scanChains


# ---------------------------------------------------------------
# Arbre d'horloge
# ---------------------------------------------------------------

set_ccopt_property buffer_cells [list CLKBUFX20 CLKBUFX16 CLKBUFX12 CLKBUFX8 CLKBUFX6 CLKBUFX4 CLKBUFX3 CLKBUFX2]
set_ccopt_property inverter_cells [list CLKINVX20 CLKINVX6 CLKINVX8 CLKINVX16 CLKINVX12 CLKINVX4 CLKINVX3 CLKINVX2 CLKINVX1]
set_ccopt_property use_inverters true
set_ccopt_property clock_gating_cells TLATNTSCA*

clock_opt_design

optDesign -postCTS

timeDesign -postCTS -outDir $::env(PNR_REP_DIR)/timing
timeDesign -hold -postCTS -outDir $::env(PNR_REP_DIR)/timing


# ---------------------------------------------------------------
# Routage
# ---------------------------------------------------------------

addFiller -cell FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1 -prefix FILLER

setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -routeWithSIDriven true

routeDesign -globalDetail


# ---------------------------------------------------------------
# Optimisations
# ---------------------------------------------------------------

setExtractRCMode -engine postRoute
extractRC

setAnalysisMode -analysisType onChipVariation
setAnalysisMode -cppr both

optDesign -postRoute -setup -hold -outDir $::env(PNR_REP_DIR)/opt


# ---------------------------------------------------------------
# Vérification DRC
# ---------------------------------------------------------------

set_verify_drc_mode -report $::env(PNR_REP_DIR)/riscv_core.drc.rpt
verify_drc

verifyConnectivity -type all -report $::env(PNR_REP_DIR)/riscv_core.con.rpt


# ---------------------------------------------------------------
# Vérification STA
# ---------------------------------------------------------------

timeDesign -postRoute -outDir $::env(PNR_REP_DIR)/timing
timeDesign -postRoute -hold -outDir $::env(PNR_REP_DIR)/timing
report_timing > $::env(PNR_REP_DIR)/riscv_core.tim.rpt


# ---------------------------------------------------------------
# Sauvegarde
# ---------------------------------------------------------------

file mkdir $::env(PNR_NET_DIR)
file mkdir $::env(PNR_REP_DIR)
file mkdir $::env(PNR_SAVE_DIR)
saveDesign $::env(PNR_SAVE_DIR)/riscv_core.enc


# ---------------------------------------------------------------
# Netlist
# ---------------------------------------------------------------

saveNetlist $::env(PNR_NET_DIR)/riscv_core.pnr.v
write_sdf -version 2.1 -target_application verilog -interconn noport $::env(PNR_NET_DIR)/riscv_core.pnr.sdf