proc prepare_work {{directory "beh"}} {
    if {![file exists "modelsim.ini"]} {
        vmap -c
    }

    file mkdir $directory
    set library "$directory/work"

    if {![file isdirectory $library]} {
        vlib $library
    }

    vmap work $library
}

proc compile_rtl {} {
    foreach name {
        riscv_pkg
        riscv_adder
        riscv_pc
        riscv_rf
        riscv_alu
    } {
        vcom -2008 -work work "../sources/common/${name}.vhd"
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