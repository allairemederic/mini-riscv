library ieee;
use ieee.std_logic_1164.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity tb_riscv_execute is
end entity tb_riscv_execute;

architecture sim of tb_riscv_execute is

    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';

    signal ex_stage   : decode_state := EMPTY_DECODE;
    signal ex_jump    : std_logic;
    signal ex_branch  : std_logic;
    signal ex_src_imm : std_logic;

    signal rf_a      : word := (others => '0');
    signal rf_b      : word := (others => '0');
    signal wb_data   : word := (others => '0');
    signal wb_rd     : reg_index := REG_X0;
    signal wb_enable : std_logic := '0';

    signal pc_transfert : std_logic;
    signal pc_target    : word;

    signal me_alu_result : word;
    signal me_store_data : word;
    signal me_rd_addr    : reg_index;
    signal me_rw         : std_logic;
    signal me_we         : std_logic;
    signal me_wb         : std_logic;

begin

    clk <= not clk after 5 ns;

    -- Reproduire les signaux issus de ID/EX dans le core
    ex_jump <= '1' when (ex_stage.op = jal_op) or (ex_stage.op = jalr_op) else '0';
    ex_branch  <= '1' when ex_stage.op = beq_op else '0';
    ex_src_imm <= ex_stage.use_imm;

    dut : entity work.riscv_execute
        port map (
            i_clk          => clk,
            i_rstn         => reset_n,

            i_jump         => ex_jump,
            i_branch       => ex_branch,
            i_src_imm      => ex_src_imm,
            i_rs1_data     => rf_a,
            i_rs2_data     => rf_b,
            i_imm          => ex_stage.imm,
            i_pc           => ex_stage.pc,
            i_ex_stage     => ex_stage,

            i_wb_data      => wb_data,
            i_wb_rd        => wb_rd,
            i_wb_enable    => wb_enable,

            o_pc_transfert => pc_transfert,
            o_pc_target    => pc_target,

            o_alu_result   => me_alu_result,
            o_store_data   => me_store_data,
            o_rd_addr      => me_rd_addr,
            o_rw           => me_rw,
            o_we           => me_we,
            o_wb           => me_wb
        );

    stimulus : process
        variable instruction : decode_state;
        variable add_x3      : decode_state;
        variable producer    : decode_state;

        procedure advance_ex_me is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure advance_ex_me;

    begin

        wait until falling_edge(clk);
        reset_n <= '1';

        -- TEST 1 : ADD utilise les valeurs lues dans le RF
        add_x3 := EMPTY_DECODE;
        add_x3.valid     := '1';
        add_x3.writes_rd := '1';
        add_x3.uses_rs1  := '1';
        add_x3.uses_rs2  := '1';
        add_x3.rs1       := "00001";
        add_x3.rs2       := "00010";
        add_x3.rd        := "00011";

        ex_stage <= add_x3;
        rf_a     <= x"0000000A"; -- 10
        rf_b     <= x"00000003"; -- 3
        advance_ex_me;

        assert me_alu_result = x"0000000D"
            and me_rd_addr = "00011"
            and me_wb = '1' and me_rw = '0' and me_we = '0'
            and pc_transfert = '0'
            report "ECHEC TEST 1 : ADD doit produire 13 pour x3"
            severity failure;

        -- TEST 2 : Memory a la priorite sur Write-Back pour x1
        -- Executer ADDI x1, x0, 20 pour placer 20 dans EX/ME
        producer := EMPTY_DECODE;
        producer.valid     := '1';
        producer.writes_rd := '1';
        producer.uses_rs1  := '1';
        producer.use_imm   := '1';
        producer.rs1       := REG_X0;
        producer.rd        := "00001";
        producer.imm       := x"00000014";

        ex_stage <= producer;
        rf_a     <= (others => '0');
        advance_ex_me;

        assert me_alu_result = x"00000014" and me_rd_addr = "00001"
            and me_wb = '1'
            report "ECHEC TEST 2 : EX/ME doit contenir 20 pour x1"
            severity failure;

        -- Banc : x1 = 10. Write-Back : x1 = 30. Memory : x1 = 20
        ex_stage  <= add_x3;
        rf_a      <= x"0000000A";
        rf_b      <= x"00000003";
        wb_rd     <= "00001";
        wb_data   <= x"0000001E";
        wb_enable <= '1';
        advance_ex_me;

        assert me_alu_result = x"00000017"
            report "ECHEC TEST 2 : le forwarding doit choisir 20 en Memory"
            severity failure;

        -- TEST 3 : EX/ME contient maintenant x3, donc x1 vient de WB
        -- Reexecuter le meme ADD avec les memes entrees
        advance_ex_me;

        assert me_alu_result = x"00000021"
            report "ECHEC TEST 3 : le forwarding doit choisir 30 en Write-Back"
            severity failure;

        -- TEST 4 : SW calcule 100 + 8 et transmet 42 comme donnee
        -- Executer d'abord ADDI x2, x0, 42 pour le forwarding
        producer.rd  := "00010";
        producer.imm := x"0000002A";

        ex_stage  <= producer;
        rf_a      <= (others => '0');
        wb_enable <= '0';
        advance_ex_me;

        instruction := EMPTY_DECODE;
        instruction.valid    := '1';
        instruction.op       := store_op;
        instruction.uses_rs1 := '1';
        instruction.uses_rs2 := '1';
        instruction.use_imm  := '1';
        instruction.rs1      := "00001";
        instruction.rs2      := "00010";
        instruction.imm      := x"00000008";

        ex_stage <= instruction;
        rf_a     <= x"00000064"; -- 100
        rf_b     <= x"00000009"; -- Ancienne valeur de x2
        advance_ex_me;

        assert me_we = '1' and me_rw = '0' and me_wb = '0'
            and me_alu_result = x"0000006C"
            and me_store_data = x"0000002A"
            report "ECHEC TEST 4 : SW doit produire l'adresse 108 et la donnee 42"
            severity failure;

        -- TEST 5 : BEQ redirige Fetch si les deux valeurs sont egales
        instruction := EMPTY_DECODE;
        instruction.valid    := '1';
        instruction.op       := beq_op;
        instruction.uses_rs1 := '1';
        instruction.uses_rs2 := '1';
        instruction.rs1      := "00001";
        instruction.rs2      := "00010";
        instruction.pc       := x"00000064";
        instruction.imm      := x"00000008";

        ex_stage <= instruction;
        rf_a     <= x"00000007";
        rf_b     <= x"00000007";
        wait for 1 ns;

        assert pc_transfert = '1' and pc_target = x"0000006C"
            report "ECHEC TEST 5 : BEQ doit sauter a PC + 8"
            severity failure;

        rf_b <= x"00000008";
        wait for 1 ns;

        assert pc_transfert = '0'
            report "ECHEC TEST 5 : BEQ doit continuer si les valeurs different"
            severity failure;

        -- TEST 6 : JAL redirige vers 140 et enregistre le retour a 104
        instruction := EMPTY_DECODE;
        instruction.valid     := '1';
        instruction.writes_rd := '1';
        instruction.op        := jal_op;
        instruction.rd        := "00001";
        instruction.pc        := x"00000064"; -- 100
        instruction.imm       := x"00000028"; -- 40

        ex_stage <= instruction;
        wait for 1 ns;

        assert pc_transfert = '1' and pc_target = x"0000008C"
            report "ECHEC TEST 6 : JAL doit rediriger vers 140 avant le front"
            severity failure;

        advance_ex_me;

        assert me_alu_result = x"00000068"
            and me_rd_addr = "00001" and me_wb = '1'
            report "ECHEC TEST 6 : JAL doit enregistrer l'adresse de retour 104"
            severity failure;

        -- TEST 7 : JALR calcule 129 + 4 puis efface le bit 0
        instruction.op       := jalr_op;
        instruction.uses_rs1 := '1';
        instruction.use_imm  := '1';
        instruction.rs1      := "00010";
        instruction.rd       := "00100";
        instruction.pc       := x"000000C8"; -- 200
        instruction.imm      := x"00000004";

        ex_stage <= instruction;
        rf_a     <= x"00000081"; -- 129
        wait for 1 ns;

        assert pc_transfert = '1' and pc_target = x"00000084"
            report "ECHEC TEST 7 : JALR doit rediriger vers 132"
            severity failure;

        advance_ex_me;

        assert me_alu_result = x"000000CC"
            and me_rd_addr = "00100" and me_wb = '1'
            report "ECHEC TEST 7 : JALR doit enregistrer l'adresse de retour 204"
            severity failure;

        -- TEST 8 : un saut invalide ne redirige pas Fetch et n'ecrit pas
        instruction.valid := '0';
        ex_stage <= instruction;
        wait for 1 ns;

        assert pc_transfert = '0'
            report "ECHEC TEST 8 : une bulle ne doit pas declencher de saut"
            severity failure;

        advance_ex_me;

        assert me_wb = '0' and me_rw = '0' and me_we = '0'
            report "ECHEC TEST 8 : une bulle ne doit activer ni ME ni WB"
            severity failure;

        report "SUCCES : tous les tests d'Execute ont passe." severity note;
        std.env.stop;
        wait;
    end process stimulus;

end architecture sim;