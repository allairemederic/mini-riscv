library ieee;
use ieee.std_logic_1164.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity riscv_core is
    port (
        i_rstn : in std_logic;
        i_clk  : in std_logic;

        -- Port de la mémoire d'instructions
        o_imem_en   : out std_logic;
        o_imem_addr : out std_logic_vector(8 downto 0);
        i_imem_read : in  std_logic_vector(31 downto 0);

        -- Port de la mémoire de données
        o_dmem_en    : out std_logic;
        o_dmem_we    : out std_logic;
        o_dmem_addr  : out std_logic_vector(8 downto 0);
        i_dmem_read  : in  std_logic_vector(31 downto 0);
        o_dmem_write : out std_logic_vector(31 downto 0);

        -- DFT.
        i_scan_en   : in  std_logic;
        i_test_mode : in  std_logic;
        i_tdi       : in  std_logic;
        o_tdo       : out std_logic
    );
end entity riscv_core;

architecture beh of riscv_core is

    -- Fetch vers Decode
    signal id_instr : word;
    signal id_pc    : word;
    signal id_valid : std_logic;

    -- Détection du stall et redirection vers Fetch
    signal decoded     : decode_state;
    signal stall       : std_logic;
    signal id_flush    : std_logic;
    signal redirect    : std_logic;
    signal redirect_pc : word;

    -- Decode vers Execute, après ID/EX
    signal ex_stage    : decode_state;
    signal ex_rs1_data : word;
    signal ex_rs2_data : word;
    signal ex_rd_addr  : reg_index;
    signal ex_pc       : word;
    signal ex_imm      : word;
    signal ex_jump     : std_logic;
    signal ex_branch   : std_logic;
    signal ex_src_imm  : std_logic;
    signal ex_rw       : std_logic;

    -- Execute vers Memory Access, après EX/ME
    signal me_store_data : word;
    signal me_alu_result : word;
    signal me_rd_addr    : reg_index;
    signal me_rw         : std_logic;
    signal me_we         : std_logic;
    signal me_wb         : std_logic;

    -- Memory Access vers Write-Back
    signal wb_load_data  : word;
    signal wb_alu_result : word;
    signal wb_rd_addr    : reg_index;
    signal wb_rw         : std_logic;
    signal wb_request    : std_logic;

    -- Write-Back vers le banc de registres et le forwarding d'Execute
    signal wb_rd     : reg_index;
    signal wb_value  : word;
    signal wb_enable : std_logic;

begin

    o_tdo <= '0';

    -- Fetch transmet l'instruction et le PC qui lui correspond
    fetch : entity work.riscv_fetch
        port map (
            i_clk       => i_clk,
            i_rstn      => i_rstn,
            i_stall     => stall,
            i_transfert => redirect,
            i_flush     => redirect,
            i_target    => redirect_pc,
            o_instr     => id_instr,
            o_pc        => id_pc,
            o_valid     => id_valid,
            o_imem_en   => o_imem_en,
            o_imem_addr => o_imem_addr,
            i_imem_read => i_imem_read
        );

    -- Decode lit les registres sources et capture les commandes dans ID/EX
    decode : entity work.riscv_decode
        port map (
            i_clk       => i_clk,
            i_rstn      => i_rstn,
            i_flush     => id_flush,
            i_valid     => id_valid,
            i_instr     => id_instr,
            i_pc        => id_pc,
            i_wb_enable => wb_enable,
            i_wb_value  => wb_value,
            i_wb_rd     => wb_rd,

            o_decoded   => decoded,
            o_ex_stage  => ex_stage,
            o_rs1_data  => ex_rs1_data,
            o_rs2_data  => ex_rs2_data,
            o_rd_addr   => ex_rd_addr,
            o_pc        => ex_pc,
            o_branch    => ex_branch,
            o_jump      => ex_jump,
            o_rw        => ex_rw,
            o_we        => open,
            o_wb        => open,
            o_arith     => open,
            o_sign      => open,
            o_imm       => ex_imm,
            o_src_imm   => ex_src_imm,
            o_alu_op    => open
        );

    -- Execute calcule le résultat et le capture dans EX/ME
    -- La redirection et sa cible vont directement à Fetch
    execute : entity work.riscv_execute
        port map (
            i_clk          => i_clk,
            i_rstn         => i_rstn,
            i_jump         => ex_jump,
            i_branch       => ex_branch,
            i_src_imm      => ex_src_imm,
            i_rs1_data     => ex_rs1_data,
            i_rs2_data     => ex_rs2_data,
            i_imm          => ex_imm,
            i_pc           => ex_pc,
            i_ex_stage     => ex_stage,

            i_wb_data      => wb_value,
            i_wb_rd        => wb_rd,
            i_wb_enable    => wb_enable,

            o_pc_transfert => redirect,
            o_pc_target    => redirect_pc,
            o_alu_result   => me_alu_result,
            o_store_data   => me_store_data,
            o_rd_addr      => me_rd_addr,
            o_rw           => me_rw,
            o_we           => me_we,
            o_wb           => me_wb
        );

    -- Memory commande la DPM et capture le résultat et les commandes dans ME/WB
    memory_access : entity work.riscv_memory_access
        port map (
            i_clk        => i_clk,
            i_rstn       => i_rstn,
            i_store_data => me_store_data,
            i_rw         => me_rw,
            i_we         => me_we,
            i_alu_result => me_alu_result,
            i_wb         => me_wb,
            i_rd_addr    => me_rd_addr,

            o_dmem_en    => o_dmem_en,
            o_dmem_we    => o_dmem_we,
            o_dmem_addr  => o_dmem_addr,
            o_dmem_write => o_dmem_write,
            i_dmem_read  => i_dmem_read,

            o_load_data  => wb_load_data,
            o_alu_result => wb_alu_result,
            o_wb         => wb_request,
            o_rd_addr    => wb_rd_addr,
            o_rw         => wb_rw
        );

    -- Write-Back transmet la donnée, la destination et l'autorisation d'écrire
    write_back : entity work.riscv_write_back
        port map (
            i_rd_addr    => wb_rd_addr,
            i_rw         => wb_rw,
            i_load_data  => wb_load_data,
            i_alu_result => wb_alu_result,
            i_wb         => wb_request,

            o_rd_addr    => wb_rd,
            o_rd_data    => wb_value,
            o_wb         => wb_enable
        );

    -- Si l'instruction en ID a besoin du résultat du LW en EX, bloquer Fetch un cycle pour garder cette instruction en ID
    stall <= '1'
        when (decoded.valid = '1')
         and (ex_rw = '1')
         and (ex_rd_addr /= REG_X0)
         and (
              ((decoded.uses_rs1 = '1') and (decoded.rs1 = ex_rd_addr))
           or ((decoded.uses_rs2 = '1') and (decoded.rs2 = ex_rd_addr))
         )
        else '0';

    -- Stall    : garder l'instruction en ID et laisser le LW avancer
    -- Redirect : annuler l'instruction en ID et changer le PC
    id_flush <= stall or redirect;

end architecture beh;