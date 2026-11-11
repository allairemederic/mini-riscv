proc prepare_work {} {
    if {![file exists "modelsim.ini"]} {
        vmap -c
    }

    file mkdir beh
    if {![file isdirectory "beh/work"]} {
        vlib beh/work
    }

    vmap work beh/work
}

proc compile_rtl {} {
    foreach name {
        riscv_pkg
        riscv_adder
        riscv_pc
        riscv_rf
        riscv_alu
        dpm
    } {
        vcom -2008 -work work "../sources/common/${name}.vhd"
    }

    foreach name {
        riscv_pipeline_pkg
        riscv_fetch
        riscv_decode
        riscv_execute
        riscv_memory_access
        riscv_write_back
        riscv_core
    } {
        vcom -2008 -work work "../sources/core/${name}.vhd"
    }
}

proc check_mem_file {path} {
    if {![file isfile $path]} {
        error "Image memoire introuvable : [file normalize $path]"
    }
}

proc run_tb {entity result_name args} {
    vsim -t ps -wlf "${result_name}_results.wlf" {*}$args "work.$entity"

    add wave "sim:/${entity}/*"
    write format wave "${result_name}_wave.do"

    run -all
}