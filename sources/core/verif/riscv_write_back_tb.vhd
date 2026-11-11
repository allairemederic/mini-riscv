library ieee;
use ieee.std_logic_1164.all;

use work.riscv_pipeline.all;

entity tb_riscv_write_back is
end entity tb_riscv_write_back;

architecture sim of tb_riscv_write_back is

    signal rd_addr_in : reg_index := (others => '0');
    signal rw         : std_logic := '0';
    signal load_data  : word := x"CAFEBABE";
    signal alu_result : word := (others => '0');
    signal wb_in      : std_logic := '0';

    signal rd_addr_out : reg_index;
    signal rd_data     : word;
    signal wb_out      : std_logic;

begin

    dut : entity work.riscv_write_back
        port map (
            i_rd_addr    => rd_addr_in,
            i_rw         => rw,
            i_load_data  => load_data,
            i_alu_result => alu_result,
            i_wb         => wb_in,

            o_rd_addr    => rd_addr_out,
            o_rd_data    => rd_data,
            o_wb         => wb_out
        );

    stimulus : process
    begin

        -- TEST 1 : ADD transmet le resultat d'Execute vers x3
        rd_addr_in <= "00011";
        rw         <= '0';
        alu_result <= x"0000002A";
        wb_in      <= '1';
        wait for 10 ns;

        assert rd_data = x"0000002A"
            report "ECHEC TEST 1 : resultat d'Execute incorrect"
            severity failure;

        assert rd_addr_out = "00011" and wb_out = '1'
            report "ECHEC TEST 1 : adresse ou autorisation incorrecte"
            severity failure;

        -- TEST 2 : LW transmet la donnee lue en memoire vers x5
        rd_addr_in <= "00101";
        rw         <= '1';
        alu_result <= x"0000006C";
        wb_in      <= '1';
        wait for 10 ns;

        assert rd_data = x"CAFEBABE"
            report "ECHEC TEST 2 : la donnee lue en memoire doit etre selectionnee"
            severity failure;

        assert rd_addr_out = "00101" and wb_out = '1'
            report "ECHEC TEST 2 : adresse ou autorisation incorrecte"
            severity failure;

        -- TEST 3 : pour un SW, le core fournit une autorisation a 0
        rw    <= '0';
        wb_in <= '0';
        wait for 10 ns;

        assert wb_out = '0'
            report "ECHEC TEST 3 : l'autorisation a 0 doit etre transmise"
            severity failure;

        report "SUCCES : tous les tests de Write Back ont passe."
            severity note;

        std.env.stop;
        wait;
    end process stimulus;

end architecture sim;