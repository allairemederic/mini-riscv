library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity riscv_eswp_instruction is

  port (
    i_funct3    : in std_logic_vector(2 downto 0);
    i_imm       : in word;
    i_rs1       : in word;

    o_res       : out word

  );

end entity riscv_eswp_instruction;

architecture beh of riscv_eswp_instruction is

  signal operande : word;

begin

  -- Selection de l'operande selon funct3
  operande <= i_imm when i_funct3(2)='1' else i_rs1 ;

  -- Inversion des 4 octets
  o_res <=  operande(7 downto 0) &
            operande(15 downto 8) &
            operande(23 downto 16) &
            operande(31 downto 24);


end architecture beh;