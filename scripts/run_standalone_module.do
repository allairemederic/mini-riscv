onerror {abort}
source ../scripts/compile_sources.tcl

if {![info exists 1]} {
    error "Usage : do run_module.do <module>"
}

set module [set 1]
regsub {^riscv_} $module {} module

switch -- $module {
    adder - alu - pc - rf {
        set verif_dir "../sources/common/verif"
    }

    fetch - decode - execute - memory_access - write_back {
        set verif_dir "../sources/core/verif"
    }

    default {
        error "Module inconnu : $module"
    }
}

# Le banc Fetch charge l'image Fibo avec la DPM
if {$module eq "fetch"} {
    check_mem_file "../asm/riscv_fibo.mem"
}

prepare_work
compile_rtl
vcom -2008 -work work "$verif_dir/riscv_${module}_tb.vhd"

run_tb "tb_riscv_${module}" $module