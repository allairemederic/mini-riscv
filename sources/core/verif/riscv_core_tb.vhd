-------------------------------------------------------------------------------
-- Project    : ELE8304 : Circuits intégrés à très grande échelle
-- Polytechnique Montreal
-------------------------------------------------------------------------------
-- File       : riscv_core_tb.vhd
-- Author     : Theo Dupuis
-- Created    : 2022-11-22
-------------------------------------------------------------------------------
-- Description : TestBench for riscv_core
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Commentaire : 
--						Le mémoire simulee MEM0 n'est adressable que par mot de 32b, 
--						le compteur de programme (adresse de l'instruction suivante) 
--						doit donc etre divise par 4 (ou srl 2) avant d'etre connecte
--						a la memoire.
--						Bien que le bus d'adressage presente une largeur de 16b,
--						seul les 9 bits de poids faible de l'adresse sont conserve 
--						en accord avec la documentation.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity riscv_core_tb is
    generic (
        MEM_FILE  : string  := "../asm/riscv_basic.mem";
        TEST_FIBO : boolean := false
    );
end entity riscv_core_tb;

architecture tb of riscv_core_tb is

    constant DEPTH  : integer := MEM_ADDR_WIDTH;
    constant PERIOD : time := 100 ns;

    constant FINAL_LOOP_WORD : natural := 16#D4# / 4;  -- Indice de mot 53

    signal clk  : std_logic := '0';
    signal rstn : std_logic := '0';

    signal imem_en   : std_logic;
    signal imem_addr : std_logic_vector(DEPTH-1 downto 0);
    signal imem_read : std_logic_vector(XLEN-1 downto 0);

    signal dmem_en    : std_logic;
    signal dmem_we    : std_logic;
    signal dmem_addr  : std_logic_vector(DEPTH-1 downto 0);
    signal dmem_read  : std_logic_vector(XLEN-1 downto 0);
    signal dmem_write : std_logic_vector(XLEN-1 downto 0);

    signal stores_seen : natural := 0;
    signal loads_seen  : natural := 0;
    signal loop_hits   : natural := 0;

    -- Compteurs pour stalls et flush
    signal stalls_seen    : natural := 0;
    signal redirects_seen : natural := 0;

begin

    clk <= not clk after PERIOD / 2;
    rstn <= '1' after 2 * PERIOD;

    MEM0 : entity work.dpm
        generic map (
            WIDTH => XLEN,
            DEPTH => DEPTH,
            RESET => 16#00000000#,
            INIT  => MEM_FILE
        )
        port map (
            -- Port A : lecture des instructions
            -- Le core fournit deja un indice de mot
            i_a_clk   => clk,
            i_a_rstn  => rstn,
            i_a_en    => imem_en,
            i_a_we    => '0',
            i_a_addr  => imem_addr,
            i_a_write => (others => '0'),
            o_a_read  => imem_read,

            -- Port B : lectures et ecritures de donnees
            -- Le core fournit aussi un indice de mot sur ce port
            i_b_clk   => clk,
            i_b_rstn  => rstn,
            i_b_en    => dmem_en,
            i_b_we    => dmem_we,
            i_b_addr  => dmem_addr,
            i_b_write => dmem_write,
            o_b_read  => dmem_read
        );

    DUT : entity work.riscv_core
        port map (
            i_rstn       => rstn,
            i_clk        => clk,
            o_imem_en    => imem_en,
            o_imem_addr  => imem_addr,
            i_imem_read  => imem_read,
            o_dmem_en    => dmem_en,
            o_dmem_we    => dmem_we,
            o_dmem_addr  => dmem_addr,
            i_dmem_read  => dmem_read,
            o_dmem_write => dmem_write,
            i_scan_en    => '0',
            i_test_mode  => '0',
            i_tdi        => '0',
            o_tdo        => open
        );

    -- TEST 1
    -- Vérifie que le core ne lit aucune instruction et ne lit ni écrit de donnee en memoire pendant que le reset est actif
    check_reset : process
    begin
        wait for 1 ns;

        assert imem_en = '0' and dmem_en = '0' and dmem_we = '0'
            report "ECHEC TEST 1 : acces memoire pendant le reset"
            severity failure;

        wait;
    end process;

    basic_checks : if not TEST_FIBO generate
    begin


        -- Observer les commandes que la DPM capture au front montant
        check_memory : process
            variable word_index : natural;
        begin
            wait until rising_edge(clk);

            if rstn = '1' then

                -- TEST 2 : verifier l'adresse et la donnee de chaque SW
                -- On verifie les deux ecritures de BASIC
                -- Si 3e ecriture = fail
                if dmem_en = '1' and dmem_we = '1' then
                    word_index := to_integer(unsigned(dmem_addr));

                    case stores_seen is
                        when 0 =>
                            assert word_index = 16#7F8# / 4
                                and dmem_write = x"0FFF80F0"
                                report "ECHEC TEST 2 : premier SW incorrect"
                                severity failure;

                        when 1 =>
                            assert word_index = 16#7F4# / 4
                                and dmem_write = x"000007F4"
                                report "ECHEC TEST 2 : deuxieme SW incorrect"
                                severity failure;

                        when others =>
                            assert false
                                report "ECHEC TEST 2 : ecriture supplementaire"
                                severity failure;
                    end case;

                    stores_seen <= stores_seen + 1;
                end if;

                -- TEST 3 : verifier chaque LW, dont le chargement dependant
                -- Le dernier LW utilise comme adresse la valeur du LW precedent
                if dmem_en = '1' and dmem_we = '0' then
                    word_index := to_integer(unsigned(dmem_addr));

                    -- Laisser la DPM mettre a jour sa sortie apres le front
                    wait for 1 ns;

                    case loads_seen is
                        when 0 =>
                            assert word_index = 16#7F8# / 4
                                and dmem_read = x"0FFF80F0"
                                report "ECHEC TEST 3 : premier LW incorrect"
                                severity failure;

                        when 1 | 2 =>
                            assert word_index = 16#7F4# / 4
                                and dmem_read = x"000007F4"
                                report "ECHEC TEST 3 : chargement de la section forwarding incorrect"
                                severity failure;

                        when others =>
                            assert false
                                report "ECHEC TEST 3 : lecture supplementaire"
                                severity failure;
                    end case;

                    loads_seen <= loads_seen + 1;
                end if;
            end if;
        end process;

        -- TEST 4 : le core doit revenir plusieurs fois a la boucle finale
        -- Basic doit atteindre cette adresse trois fois en moins de 20 us
        check_loop : process(clk)
        begin
            if rising_edge(clk) then
                if rstn = '1' and imem_en = '1' then
                    if unsigned(imem_addr) = FINAL_LOOP_WORD then
                        loop_hits <= loop_hits + 1;
                    end if;
                end if;
            end if;
        end process;


        check_hazards : process

            alias dut_stall is
                << signal .riscv_core_tb.DUT.stall : std_logic >>;
            alias dut_redirect is
                << signal .riscv_core_tb.DUT.redirect : std_logic >>;
            alias dut_ex_stage is
                << signal .riscv_core_tb.DUT.ex_stage : decode_state >>;

            alias dut_id_valid is
                << signal .riscv_core_tb.DUT.id_valid : std_logic >>;
            alias dut_id_instr is
                << signal .riscv_core_tb.DUT.id_instr : word >>;
            alias dut_id_pc is
                << signal .riscv_core_tb.DUT.id_pc : word >>;

            alias dut_me_rw is
                << signal .riscv_core_tb.DUT.me_rw : std_logic >>;
            alias dut_me_rd_addr is
                << signal .riscv_core_tb.DUT.me_rd_addr : reg_index >>;

            variable stall_at_edge    : std_logic;
            variable redirect_at_edge : std_logic;
            variable id_instr_at_edge : word;
            variable id_pc_at_edge    : word;
            variable load_rd_at_edge  : reg_index;

        begin
            wait until rising_edge(clk);

            if rstn = '1' then
                -- Relever les commandes avant la mise a jour des etages
                stall_at_edge    := dut_stall;
                redirect_at_edge := dut_redirect;

                -- TEST 5 : Fetch ne lance pas de lecture pendant le stall
                -- Decode doit garder la meme instruction et meme PC
                -- Basic doit bloquer pendant un seul cycle
                if stall_at_edge = '1' then
                    assert imem_en = '0'
                        report "ECHEC TEST 5 : Fetch lit pendant le stall"
                        severity failure;

                    id_instr_at_edge := dut_id_instr;
                    id_pc_at_edge    := dut_id_pc;
                    load_rd_at_edge  := dut_ex_stage.rd;

                    stalls_seen <= stalls_seen + 1;
                end if;

                -- TEST 6 : Fetch ne lit pas sur le mauvais chemin
                -- L'instruction en Decode doit avoir ete remplace par une bubble dans Execute
                -- Doit avoir une redirection
                if redirect_at_edge = '1' then
                    assert imem_en = '0'
                        report "ECHEC TEST 6 : Fetch lit pendant la redirection"
                        severity failure;

                    redirects_seen <= redirects_seen + 1;
                end if;

                -- Laisser les sorties des registres se mettre a jour
                wait for 1 ns;

                if stall_at_edge = '1' then
                    assert dut_ex_stage.valid = '0'
                        report "ECHEC TEST 5 : aucune bulle apres le stall"
                        severity failure;

                    assert dut_id_valid = '1'
                        and dut_id_instr = id_instr_at_edge
                        and dut_id_pc = id_pc_at_edge
                        report "ECHEC TEST 5 : instruction perdue ou modifiee en ID"
                        severity failure;

                    assert dut_me_rw = '1' and dut_me_rd_addr = load_rd_at_edge
                        report "ECHEC TEST 5 : le LW n'a pas avance vers Memory"
                        severity failure;
                end if;

                if redirect_at_edge = '1' then
                    assert dut_ex_stage.valid = '0'
                        report "ECHEC TEST 6 : Decode avance malgre le flush"
                        severity failure;
                end if;
            end if;
        end process check_hazards;

        finish_test : process
        begin
            wait until loop_hits = 3 for 20 us;

            assert loop_hits = 3
                report "ECHEC TEST 4 : la boucle finale n'a pas ete atteinte"
                severity failure;

            assert stores_seen = 2 and loads_seen = 3
                report "ECHEC : le nombre de lectures ou d'ecritures est incorrect"
                severity failure;

            assert stalls_seen = 1
                report "ECHEC TEST 5 : Basic doit bloquer pendant un seul cycle"
                severity failure;

            assert redirects_seen > 0
                report "ECHEC TEST 6 : aucune redirection observee"
                severity failure;

            report "SUCCES : riscv_basic a termine les acces attendus et atteint sa boucle finale."
                severity note;

            std.env.stop;
            wait;
        end process;

    end generate basic_checks;

    fibo_checks : if TEST_FIBO generate
    begin
        check_fibo : process
        begin
            wait until rstn = '1';

            -- Attendre au plus 1000 cycles pour le resultat final
            for cycle in 1 to 1000 loop
                wait until rising_edge(clk);

                -- Le programme ecrit son resultat a l'adresse 0x7FC
                -- Le port de la DPM recoit l'indice de mot 511
                if dmem_en = '1' and dmem_we = '1'
                   and unsigned(dmem_addr) = 16#7FC# / 4 then

                    assert dmem_write = x"0E0E0E0E"
                        report "ECHEC FIBO : resultat final incorrect"
                        severity failure;

                    report "SUCCES : Fibo a ecrit 0E0E0E0E."
                        severity note;
                    std.env.stop;
                    wait;
                end if;
            end loop;

            assert false
                report "ECHEC FIBO : aucun resultat final apres 1000 cycles"
                severity failure;
            wait;
        end process;
    end generate fibo_checks;

end architecture tb;