library ieee;
use ieee.std_logic_1164.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity tb_riscv_eswp_instruction is
end entity tb_riscv_eswp_instruction;

architecture sim of tb_riscv_eswp_instruction is

    signal clk          : std_logic := '0';
    signal funct3       : std_logic_vector(2 downto 0);
    signal imm          :  word:= x"12345678";
    signal rs1_value    :  word:= x"9ABCDEF0";
    signal eswp_res     :  word;
begin

    dut : entity work.riscv_eswp_instruction
    port map (
        i_funct3  => funct3,
        i_imm     => imm,
        i_rs1     => rs1_value,
        o_res     => eswp_res
    );

    stimulus : process

    begin

        -- TEST 1 : selection de imm, conversion big-endiam -> little-endian
        funct3 <= "101";

        wait for 1 ns;

        assert eswp_res = x"78563412"
            report "ECHEC TEST 1 : eswp doit produire 78563412"
            severity failure;



        -- TEST 2 : selection de imm, conversion little-endiam -> big-endian
        funct3 <= "100";
        imm <= x"78563412";

        wait for 1 ns;

        assert eswp_res = x"12345678"
            report "ECHEC TEST 2 : eswp doit 12345678"
            severity failure;

        -- TEST 3 : selection de rs1, conversion big-endiam -> little endian
        funct3 <= "001";

        wait for 1 ns;

        assert eswp_res = x"F0DEBC9A"
            report "ECHEC TEST 3 : eswp doit produire 0FDEBC9A"
            severity failure;

        -- TEST 4 : selection de RS1, conversion little-endiam -> big-endian
        funct3 <= "000";
        rs1_value <= x"F0DEBC9A";

        wait for 1 ns;

        assert eswp_res = x"9ABCDEF0"
            report "ECHEC TEST 4 : eswp doit produire 9ABCDEF0"
            severity failure;

        report "SUCCES : tous les tests d'ESWP ont passe." severity note;
        std.env.stop;
        wait;
    end process stimulus;

end architecture sim;