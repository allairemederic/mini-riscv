library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv_pkg.all;

entity riscv_fetch is

  port (

    i_clk           : in  std_logic;
    i_rstn          : in std_logic;
    i_transfert     : in  std_logic;
    i_stall         : in  std_logic;
    i_flush         : in  std_logic;
    i_target        : in  std_logic_vector(XLEN-1 downto 0);

    o_instr         : out std_logic_vector(XLEN-1 downto 0);
    o_pc            : out std_logic_vector(XLEN-1 downto 0);
    o_valid         : out std_logic;
    o_imem_en       : out std_logic;
    o_imem_addr     : out std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
    i_imem_read     : in std_logic_vector(XLEN-1 downto 0)

  );
end entity riscv_fetch;

architecture beh of riscv_fetch is

    signal fetch_pc    : std_logic_vector(XLEN-1 downto 0);
    signal decode_pc   : std_logic_vector(XLEN-1 downto 0);
    signal read_enable : std_logic;
    signal hold_pc     : std_logic;
    signal valid       : std_logic;

begin

    -- Garder le PC en cas de blocage ou de flush sans jump
    hold_pc <= i_stall or (i_flush and not i_transfert);

    pc : entity work.riscv_pc
        port map (
            i_clk       => i_clk,
            i_rstn      => i_rstn,
            i_stall     => hold_pc,
            i_transfert => i_transfert,
            i_target    => i_target,
            o_pc        => fetch_pc
        );
    
    -- Convertir l'adresse en octets du PC en indice de mot pour la mémoire
    o_imem_addr <= fetch_pc(MEM_ADDR_WIDTH+LSB-1 downto LSB);

    -- Lire la mémoire seulement quand Fetch peut avancer
    read_enable <= i_rstn and not i_stall and not i_flush and not i_transfert;
    o_imem_en <= read_enable;

    process(i_clk, i_rstn)
    begin
        if i_rstn = '0' then
            decode_pc <= RESET;
            valid <= '0';
        
        elsif rising_edge(i_clk) then

            if i_flush = '1' or i_transfert = '1' then
                -- Invalider l'instruction en cas de flush ou de jump
                valid <= '0';
            
            elsif read_enable = '1' then
                -- Mémoriser le PC au même front que l'adresse de lecture
                decode_pc <= fetch_pc;
                valid <= '1';
            end if;

        end if;
    end process;

    -- Envoyer un NOP quand aucune instruction n'est valide
    o_instr <= i_imem_read when valid = '1' else x"00000013";
    o_pc    <= decode_pc;
    o_valid <= valid;

end architecture;