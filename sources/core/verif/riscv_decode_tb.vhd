library ieee;
use ieee.std_logic_1164.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity tb_riscv_decode is
end entity tb_riscv_decode;

architecture sim of tb_riscv_decode is
    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal flush   : std_logic := '0';
    signal valid   : std_logic := '0';
    signal instr   : word := x"00000013";
    signal pc      : word := x"00000040";

    signal wb_enable : std_logic := '0';
    signal wb_value  : word := (others => '0');
    signal wb_rd     : reg_index := REG_X0;

    signal decoded     : decode_state;
    signal ex_stage    : decode_state;
    signal ex_rs1_data : word;
    signal ex_rs2_data : word;
    signal ex_rd_addr  : reg_index;
    signal ex_pc       : word;
    signal ex_branch   : std_logic;
    signal ex_jump     : std_logic;
    signal ex_rw       : std_logic;
    signal ex_we       : std_logic;
    signal ex_wb       : std_logic;
    signal ex_arith    : std_logic;
    signal ex_sign     : std_logic;
    signal ex_imm      : word;
    signal ex_src_imm  : std_logic;
    signal ex_alu_op   : std_logic_vector(ALUOP_WIDTH-1 downto 0);

begin

    clk <= not clk after 5 ns;

    dut : entity work.riscv_decode
        port map (
            i_clk       => clk,
            i_rstn      => reset_n,
            i_flush     => flush,
            i_valid     => valid,
            i_instr     => instr,
            i_pc        => pc,
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
            o_we        => ex_we,
            o_wb        => ex_wb,
            o_arith     => ex_arith,
            o_sign      => ex_sign,
            o_imm       => ex_imm,
            o_src_imm   => ex_src_imm,
            o_alu_op    => ex_alu_op
        );

    stimulus : process
        procedure advance_id_ex is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure advance_id_ex;

    begin
        -- Garder le reset actif pendant le premier front montant
        wait until falling_edge(clk);
        reset_n <= '1';
        valid   <= '1';

        -- TEST 1 : ADDI x3, x1, -4 utilise un immediat signe
        instr <= x"FFC08193";
        wait for 1 ns;

        assert decoded.valid = '1'
            and decoded.op = alu_op
            and decoded.alu_code = ALUOP_ADD
            and decoded.pc = x"00000040"
            and decoded.rd = "00011" and decoded.rs1 = "00001"
            and decoded.uses_rs1 = '1' and decoded.uses_rs2 = '0'
            and decoded.use_imm = '1' and decoded.imm = x"FFFFFFFC"
            and decoded.writes_rd = '1'
            report "ECHEC TEST 1 : decodage de ADDI"
            severity failure;

        assert ex_stage.valid = '0'
            report "ECHEC TEST 1 : ID/EX a change avant le front"
            severity failure;

        advance_id_ex;

        assert ex_stage.valid = '1'
            and ex_rd_addr = "00011" and ex_pc = x"00000040"
            and ex_src_imm = '1' and ex_imm = x"FFFFFFFC"
            and ex_alu_op = ALUOP_ADD and ex_arith = '0'
            and ex_wb = '1' and ex_rw = '0' and ex_we = '0'
            report "ECHEC TEST 1 : sorties ID/EX incorrectes pour ADDI"
            severity failure;

        -- TEST 2 : ADD x3, x1, x2 utilise deux registres
        instr <= x"002081B3";
        wait for 1 ns;

        assert decoded.valid = '1'
            and decoded.alu_code = ALUOP_ADD
            and decoded.rs2 = "00010" and decoded.uses_rs2 = '1'
            and decoded.use_imm = '0'
            report "ECHEC TEST 2 : decodage de ADD"
            severity failure;

        advance_id_ex;

        assert ex_stage.valid = '1' and ex_src_imm = '0'
            and ex_alu_op = ALUOP_ADD and ex_arith = '0'
            report "ECHEC TEST 2 : commandes ID/EX incorrectes pour ADD"
            severity failure;

        -- TEST 3 : LW x3, 8(x1) demande une lecture et une ecriture dans x3
        instr <= x"0080A183";
        advance_id_ex;

        assert ex_stage.valid = '1' and ex_stage.op = load_op
            and ex_stage.uses_rs1 = '1' and ex_stage.uses_rs2 = '0'
            and ex_rw = '1' and ex_we = '0' and ex_wb = '1'
            and ex_rd_addr = "00011"
            and ex_src_imm = '1' and ex_imm = x"00000008"
            report "ECHEC TEST 3 : decodage de LW"
            severity failure;

        -- TEST 4 : SW x2, -4(x1) combine les deux parties de l'immediat
        instr <= x"FE20AE23";
        advance_id_ex;

        assert ex_stage.valid = '1' and ex_stage.op = store_op
            and ex_stage.uses_rs1 = '1' and ex_stage.uses_rs2 = '1'
            and ex_rw = '0' and ex_we = '1' and ex_wb = '0'
            and ex_src_imm = '1' and ex_imm = x"FFFFFFFC"
            report "ECHEC TEST 4 : decodage de SW"
            severity failure;

        -- TEST 5 : BEQ x1, x2, +8 active branch et transmet le deplacement
        instr <= x"00208463";
        advance_id_ex;

        assert ex_stage.valid = '1' and ex_stage.op = beq_op
            and ex_stage.uses_rs1 = '1' and ex_stage.uses_rs2 = '1'
            and ex_branch = '1' and ex_jump = '0' and ex_wb = '0'
            and ex_imm = x"00000008"
            report "ECHEC TEST 5 : decodage de BEQ"
            severity failure;

        -- TEST 6 : une instruction invalidee par Fetch reste invalide
        valid <= '0';
        wait for 1 ns;

        assert decoded.valid = '0' and ex_branch = '1'
            report "ECHEC TEST 6 : l'invalidite doit atteindre ID/EX au front"
            severity failure;

        advance_id_ex;

        assert ex_stage.valid = '0' and ex_branch = '0' and ex_wb = '0'
            report "ECHEC TEST 6 : le BEQ invalide est encore actif"
            severity failure;

        -- TEST 7 : un opcode inconnu ne produit aucune commande active
        valid <= '1';
        instr <= x"FFFFFFFF";
        advance_id_ex;

        assert ex_stage.valid = '0'
            and ex_branch = '0' and ex_jump = '0'
            and ex_rw = '0' and ex_we = '0' and ex_wb = '0'
            report "ECHEC TEST 7 : opcode inconnu accepte"
            severity failure;

        -- TEST 8 : lire x1 et x2 au meme front qui charge ADD dans ID/EX
        valid     <= '0';
        wb_enable <= '1';
        wb_rd     <= "00001";
        wb_value  <= x"0000000A"; -- x1 = 10
        advance_id_ex;

        wb_rd    <= "00010";
        wb_value <= x"00000014"; -- x2 = 20
        advance_id_ex;

        wb_enable <= '0';
        valid     <= '1';
        instr     <= x"002081B3"; -- ADD x3, x1, x2
        advance_id_ex;

        assert ex_stage.valid = '1' and ex_rd_addr = "00011"
            and ex_rs1_data = x"0000000A" and ex_rs2_data = x"00000014"
            report "ECHEC TEST 8 : les operandes ne correspondent pas a ADD"
            severity failure;

        -- TEST 9 : SUB demande le funct7 complet 0100000
        instr <= x"402081B3"; -- SUB x3, x1, x2
        advance_id_ex;

        assert ex_stage.valid = '1' and ex_alu_op = ALUOP_ADD
            and ex_arith = '1' and ex_sign = '0' and ex_wb = '1'
            report "ECHEC TEST 9 : SUB doit selectionner la soustraction"
            severity failure;

        -- Le bit 30 reste a 1, mais funct7 vaut maintenant 0100001
        instr <= x"422081B3";
        advance_id_ex;

        assert ex_stage.valid = '0' and ex_wb = '0'
            report "ECHEC TEST 9 : funct7 illegal accepte"
            severity failure;

        -- TEST 10 : le flush laisse JAL visible en ID et envoit une bubble en EX
        instr <= x"008000EF"; -- JAL x1, +8
        flush <= '1';
        advance_id_ex;

        assert decoded.valid = '1' and decoded.op = jal_op
            and ex_stage.valid = '0' and ex_jump = '0' and ex_wb = '0'
            report "ECHEC TEST 10 : le flush doit neutraliser ID/EX"
            severity failure;

        -- Une fois le flush leve, JAL peut traverser ID/EX
        flush <= '0';
        advance_id_ex;

        assert ex_stage.valid = '1' and ex_stage.op = jal_op
            and ex_jump = '1' and ex_branch = '0' and ex_wb = '1'
            and ex_rd_addr = "00001" and ex_imm = x"00000008"
            report "ECHEC TEST 10 : JAL doit passer apres le flush"
            severity failure;

        report "SUCCES : tous les tests de Decode ont passe." severity note;
        std.env.stop;
        wait;
    end process stimulus;

end architecture sim;