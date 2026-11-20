onerror {abort}

if {![info exists 1] || ![info exists 2]} {
    error "Usage : do ../scripts/run_timing.do syn|pnr basic|fibo"
}

set stage [set 1]
set test  [set 2]

# Choisir la netlist, le SDF et le dossier de simulation
switch -- $stage {
    syn {
        set net "../implementation/syn/cg_netlist/riscv_core.syn"
        set sim_dir "syn/cg"
    }
    pnr {
        set net "../implementation/pnr/cg_netlist/riscv_core.pnr"
        set sim_dir "pnr/cg"
    }
    default {
        error "Etape inconnue '$stage'. Choisir syn ou pnr."
    }
}

# Choisir le programme et les verifications du banc d'essai
switch -- $test {
    basic {
        set mem_file "../asm/riscv_basic.mem"
        set test_fibo false
    }
    fibo {
        set mem_file "../asm/riscv_fibo.mem"
        set test_fibo true
    }
    default {
        error "Test inconnu '$test'. Choisir basic ou fibo."
    }
}

# Charger les fonctions communes
source ../scripts/compile_sources.tcl

# Verifier les fichiers avant de compiler
check_mem_file $mem_file

foreach path [list "${net}.v" "${net}.sdf"] {
    if {![file isfile $path]} {
        error "Fichier introuvable : $path"
    }
}

# Separer les bibliotheques et les resultats des deux etapes.
prepare_work $sim_dir
set results "$sim_dir/$test"
file mkdir $results

# Associer la bibliotheque des cellules standards
vmap gsclib045 "$::env(KIT_SIMLIB)/gsclib045_slow"

# Compiler les packages et la memoire du banc d'essai
vcom -2008 -work work ../sources/common/riscv_pkg.vhd
vcom -2008 -work work ../sources/core/riscv_pipeline_pkg.vhd
vcom -2008 -work work ../sources/common/dpm.vhd

# Compiler le processeur synthetise et son banc d'essai
vlog -work work "${net}.v"
vcom -2008 -work work ../sources/core/verif/riscv_core_tb.vhd

# Lancer le test avec les delais SDF et une periode de 3 ns
run_tb riscv_core_tb "${results}/results" \
    -L gsclib045 \
    -voptargs=+acc \
    -sdfmax "/riscv_core_tb/DUT=${net}.sdf" \
    "-gMEM_FILE=$mem_file" \
    "-gTEST_FIBO=$test_fibo" \
    -gCLK_PERIOD=3ns \
    -gCHECK_INTERNAL=false

wave zoom full