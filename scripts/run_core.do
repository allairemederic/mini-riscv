onerror {abort}

if {![info exists 1]} {
    error "Usage : do ../scripts/run_core.do basic|fibo"
}

set test [set 1]

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

source ../scripts/compile_sources.tcl

check_mem_file $mem_file
prepare_work
compile_rtl

vcom -2008 -work work "../sources/core/verif/riscv_core_tb.vhd"

run_tb riscv_core_tb $test "-gMEM_FILE=$mem_file" "-gTEST_FIBO=$test_fibo"