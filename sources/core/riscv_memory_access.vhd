library ieee;
use ieee.std_logic_1164.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity riscv_memory_access is
  port (
    i_clk        : in std_logic;
    i_rstn       : in std_logic;

    -- Signaux du registre EX/MEM
    i_store_data : in word;
    i_rw         : in std_logic;  -- 1 pour un LW valide
    i_we         : in std_logic;  -- 1 pour un SW valide
    i_alu_result : in word;
    i_wb         : in std_logic;  -- Autorisation d'ecrire dans rd
    i_rd_addr    : in reg_index;

    -- Interface avec le port B de la DPM
    o_dmem_en    : out std_logic;
    o_dmem_we    : out std_logic;
    o_dmem_addr  : out std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
    o_dmem_write : out word;
    i_dmem_read  : in word;

    -- Signaux transmis a Write-Back
    o_load_data  : out word;
    o_alu_result : out word;
    o_wb         : out std_logic;
    o_rd_addr    : out reg_index;
    o_rw         : out std_logic
  );
end entity riscv_memory_access;

architecture beh of riscv_memory_access is
begin

  -- Activer la DPM pour un LW ou un SW (hors reset)
  o_dmem_en <= i_rstn and (i_rw or i_we);
  o_dmem_we <= i_rstn and i_we;

  -- Utiliser le resultat d'Execute comme adresse pour LW et SW
  o_dmem_addr  <= i_alu_result(MEM_ADDR_WIDTH+LSB-1 downto LSB);
  o_dmem_write <= i_store_data;

  -- Transmettre directement la donnee lue par la DPM
  o_load_data <= i_dmem_read;

  -- Registre ME/WB
  process(i_clk, i_rstn)
  begin

    if i_rstn = '0' then
      o_alu_result <= (others => '0');
      o_wb         <= '0';
      o_rd_addr    <= REG_X0;
      o_rw         <= '0';

    elsif rising_edge(i_clk) then
      o_alu_result <= i_alu_result;
      o_wb         <= i_wb;
      o_rd_addr    <= i_rd_addr;
      o_rw         <= i_rw;
    end if;
    
  end process;

end architecture beh;