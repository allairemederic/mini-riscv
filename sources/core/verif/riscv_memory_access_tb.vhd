library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity tb_riscv_memory_access is
end entity tb_riscv_memory_access;

architecture sim of tb_riscv_memory_access is

    signal clk      : std_logic := '0';
    signal reset_n  : std_logic := '0';
    signal me_stage : memory_state := EMPTY_MEMORY;

    signal me_rw : std_logic;
    signal me_we : std_logic;
    signal me_wb : std_logic;

    signal dmem_en    : std_logic;
    signal dmem_we    : std_logic;
    signal dmem_addr  : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
    signal dmem_write : word;
    signal dmem_read  : word := (others => '0');

    signal wb_load_data  : word;
    signal wb_alu_result : word;
    signal wb_rd_addr    : reg_index;
    signal wb_enable     : std_logic;
    signal wb_rw         : std_logic;

begin

    clk <= not clk after 5 ns;

    -- Reproduire le raccordement entre EX/MEM et Memory dans le core
    me_rw <= me_stage.valid and me_stage.is_load;
    me_we <= me_stage.valid and me_stage.is_store;
    me_wb <= me_stage.valid and me_stage.writes_rd when me_stage.rd /= REG_X0 else '0';

    dut : entity work.riscv_memory_access
        port map (
            i_clk        => clk,
            i_rstn       => reset_n,

            i_store_data => me_stage.store_value,
            i_rw         => me_rw,
            i_we         => me_we,
            i_alu_result => me_stage.result,
            i_wb         => me_wb,
            i_rd_addr    => me_stage.rd,

            o_dmem_en    => dmem_en,
            o_dmem_we    => dmem_we,
            o_dmem_addr  => dmem_addr,
            o_dmem_write => dmem_write,
            i_dmem_read  => dmem_read,

            o_load_data  => wb_load_data,
            o_alu_result => wb_alu_result,
            o_wb         => wb_enable,
            o_rd_addr    => wb_rd_addr,
            o_rw         => wb_rw
        );

    -- Simuler la lecture du mot 510 au front montant
    dpm_read_model : process(clk)
    begin

        if rising_edge(clk) then
            if dmem_en = '1' and dmem_we = '0'
               and unsigned(dmem_addr) = 510 then
                dmem_read <= x"CAFEBABE";
            end if;
        end if;

    end process dpm_read_model;

    stimulus : process
        variable entry : memory_state;
    begin

        -- TEST 1 : le reset bloque un SW valide et remet ME/WB a zero
        entry := EMPTY_MEMORY;
        entry.valid       := '1';
        entry.is_store    := '1';
        entry.result      := x"0000006C"; -- Adresse 108 en octets
        entry.store_value := x"0000002A"; -- Donnee 42
        me_stage <= entry;
        wait for 1 ns;

        assert dmem_en = '0' and dmem_we = '0'
            report "ECHEC TEST 1 : le reset doit bloquer l'acces"
            severity failure;

        assert wb_alu_result = x"00000000" and wb_rd_addr = REG_X0
            and wb_enable = '0' and wb_rw = '0'
            report "ECHEC TEST 1 : ME/WB doit etre remis a zero"
            severity failure;

        -- TEST 2 : SW demande une ecriture de 42 au mot 27
        wait until falling_edge(clk);
        reset_n <= '1';
        wait for 1 ns;

        assert dmem_en = '1' and dmem_we = '1'
            and unsigned(dmem_addr) = 27
            and dmem_write = x"0000002A"
            report "ECHEC TEST 2 : SW doit envoyer 42 au mot 27"
            severity failure;

        wait until rising_edge(clk);
        wait for 1 ns;

        assert wb_alu_result = x"0000006C"
            and wb_enable = '0' and wb_rw = '0'
            report "ECHEC TEST 2 : sorties ME/WB incorrectes pour SW"
            severity failure;

        -- TEST 3 : LW demande une lecture du mot 510 vers x5
        wait until falling_edge(clk);
        entry := EMPTY_MEMORY;
        entry.valid     := '1';
        entry.is_load   := '1';
        entry.writes_rd := '1';
        entry.rd        := "00101";
        entry.result    := x"000007F8";
        me_stage <= entry;
        wait for 1 ns;

        assert dmem_en = '1' and dmem_we = '0'
            and unsigned(dmem_addr) = 510
            report "ECHEC TEST 3 : LW doit lire le mot 510"
            severity failure;

        -- Avant le front, ME/WB contient encore le SW precedent
        assert wb_alu_result = x"0000006C" and wb_rw = '0'
            report "ECHEC TEST 3 : ME/WB a change avant le front montant"
            severity failure;

        wait until rising_edge(clk);
        wait for 1 ns;

        -- La donnee lue et les controles du LW arrivent ensemble a WB
        assert wb_load_data = x"CAFEBABE"
            and wb_alu_result = x"000007F8"
            and wb_rd_addr = "00101" and wb_enable = '1' and wb_rw = '1'
            report "ECHEC TEST 3 : donnee et controles du LW mal transmis"
            severity failure;

        -- TEST 4 : ADD laisse la memoire inactive et transmet son resultat
        wait until falling_edge(clk);
        entry := EMPTY_MEMORY;
        entry.valid     := '1';
        entry.writes_rd := '1';
        entry.rd        := "00011";
        entry.result    := x"0000002A";
        me_stage <= entry;
        wait for 1 ns;

        assert dmem_en = '0' and dmem_we = '0'
            report "ECHEC TEST 4 : ADD doit laisser la memoire inactive"
            severity failure;

        wait until rising_edge(clk);
        wait for 1 ns;

        assert wb_alu_result = x"0000002A"
            and wb_rd_addr = "00011" and wb_enable = '1' and wb_rw = '0'
            report "ECHEC TEST 4 : resultat ou controles de ADD incorrects"
            severity failure;

        -- TEST 5 : voir si le raccordement du core enlève la bulle
        wait until falling_edge(clk);
        entry.valid    := '0';
        entry.is_store := '1';
        me_stage <= entry;
        wait for 1 ns;

        assert dmem_en = '0' and dmem_we = '0'
            report "ECHEC TEST 5 : une bulle ne doit pas acceder a la memoire"
            severity failure;

        wait until rising_edge(clk);
        wait for 1 ns;

        assert wb_enable = '0' and wb_rw = '0'
            report "ECHEC TEST 5 : une bulle ne doit pas activer Write-Back"
            severity failure;

        report "SUCCES : tous les tests de Memory Access ont passe."
            severity note;

        std.env.stop;
        wait;
    end process stimulus;

end architecture sim;