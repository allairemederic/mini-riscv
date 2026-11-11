library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity riscv_write_back is

  port (
    i_rd_addr    : in reg_index;
    i_rw         : in std_logic;
    i_load_data  : in word;
    i_alu_result : in word;
    i_wb         : in std_logic;

    o_rd_addr    : out reg_index;
    o_rd_data    : out word;
    o_wb         : out std_logic
  );

end entity riscv_write_back;

architecture beh of riscv_write_back is

begin

  -- Transmettre l'adresse du registre de destination
  o_rd_addr <= i_rd_addr;

  -- Pour un LW, choisir la donnee lue en memoire
  -- Sinon, choisir le resultat produit par Execute
  o_rd_data <= i_load_data when i_rw = '1' else i_alu_result;

  -- Transmettre l'autorisation d'ecriture au RF
  o_wb <= i_wb;

end architecture beh;