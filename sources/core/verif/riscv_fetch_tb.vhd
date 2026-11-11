library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
use work.riscv_pkg.all;
 
entity tb_riscv_fetch is
end entity;
 
architecture sim of tb_riscv_fetch is
 
  constant DEPTH : integer := MEM_ADDR_WIDTH;
 
  -- Instruction NOP : addi x0, x0, 0
  constant NOP : std_logic_vector(XLEN-1 downto 0) := x"00000013";
 
  -- Contenu attendu de riscv_fibo.mem (mots 0 a 15)
  type t_programme is array (0 to 15) of std_logic_vector(XLEN-1 downto 0);
  constant PROGRAMME : t_programme := (
      x"00000113",
      x"04010263",
      x"DDDDE5B7",
      x"DDD58593",
      x"0100006F",
      x"EEEEF5B7",
      x"EEE58593",
      x"0040006F",
      x"7FC00113",
      x"F0F0F2B7",
      x"0F028293",
      x"0F0F1337",
      x"F0F30313",
      x"0055C5B3",
      x"0065F5B3",
      x"00B12023");
 
  signal clock          : std_logic := '0';
  signal reset_n        : std_logic := '0';
  signal stall          : std_logic := '0';
  signal flush          : std_logic := '0';
  signal transfer       : std_logic := '0';
  signal target_address : std_logic_vector(XLEN-1 downto 0) := (others => '0');
  signal instruction    : std_logic_vector(XLEN-1 downto 0);
  signal current_pc     : std_logic_vector(XLEN-1 downto 0);
  signal instr_valid    : std_logic;
 
  signal imem_enable    : std_logic;
  signal imem_address   : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
  signal imem_read      : std_logic_vector(31 downto 0);
 
begin
 
  -- Periode de 10 ns
  clock <= not clock after 5 ns;
 
  dut : entity work.riscv_fetch
    port map (
      i_clk       => clock,
      i_rstn      => reset_n,
      i_target    => target_address,
      i_transfert => transfer,
      i_stall     => stall,
      i_flush     => flush,
      o_instr     => instruction,
      o_pc        => current_pc,
      o_valid     => instr_valid,
      o_imem_en   => imem_enable,
      o_imem_addr => imem_address,
      i_imem_read => imem_read
    );
 
  mem : entity work.dpm

    generic map (
      WIDTH => XLEN,
      DEPTH => DEPTH,
      RESET => 16#00000000#,
      INIT  => "../asm/riscv_fibo.mem")

    port map (
        
      -- Le port A lit les instructions
      -- Fetch fournit déjà un indice de mot
      i_a_clk   => clock,
      i_a_rstn  => reset_n,
      i_a_en    => imem_enable,
      i_a_we    => '0',
      i_a_addr  => imem_address,
      i_a_write => (others => '0'),
      o_a_read  => imem_read,

      -- Le port B est inutilisé dans ce banc d'essai
      i_b_clk   => clock,
      i_b_rstn  => reset_n,
      i_b_en    => '0',
      i_b_we    => '0',
      i_b_addr  => (others => '0'),
      i_b_write => (others => '0'),
      o_b_read  => open
    );
 
  stimulus : process
  begin
 
    -- TEST 1: reset donne un NOP et l'adresse initiale.
    reset_n <= '0';
 
    wait for 2 ns;
 
    assert instruction = NOP and instr_valid = '0'
      report "ECHEC : l'instruction doit etre un NOP pendant le reset"
      severity failure;
 
    assert current_pc = RESET
      report "ECHEC : reset du PC de l'etage IF"
      severity failure;
 
    assert imem_address = "000000000"
      report "ECHEC : l'adresse envoyee a la memoire doit etre 0 pendant le reset"
      severity failure;
 
 
    -- TEST 2: la premiere instruction apparait une seule fois
    reset_n <= '1';
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(0) and instr_valid = '1'
      report "ECHEC : la premiere instruction (mot 0) est incorrecte"
      severity failure;
 
    assert current_pc = x"00000000"
      report "ECHEC : le PC de la premiere instruction doit valoir 0"
      severity failure;
 
    assert imem_address = std_logic_vector(to_unsigned(1, MEM_ADDR_WIDTH))
      report "ECHEC : l'indice de mot envoye a la memoire doit valoir 1"
      severity failure;
 
    assert imem_enable = '1'
      report "ECHEC : la memoire doit etre activee sans blocage"
      severity failure;
 
 
    -- TEST 3: les instructions suivantes arrivent dans l'ordre
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(1)
      report "ECHEC : l'instruction du mot 1 est incorrecte"
      severity failure;
 
    assert current_pc = x"00000004"
      report "ECHEC : le PC doit valoir 4"
      severity failure;
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(2)
      report "ECHEC : l'instruction du mot 2 est incorrecte"
      severity failure;
 
    assert current_pc = x"00000008"
      report "ECHEC : le PC doit valoir 8"
      severity failure;
 
 
    -- TEST 4: stall pendant 2 cycles, l'instruction et le PC sont conserves
    stall <= '1';
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(2)
      report "ECHEC : l'instruction a change pendant le premier cycle de blocage"
      severity failure;
 
    assert current_pc = x"00000008"
      report "ECHEC : le PC a change pendant le premier cycle de blocage"
      severity failure;
 
    assert imem_enable = '0'
      report "ECHEC : la memoire doit etre desactivee pendant le blocage"
      severity failure;
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(2)
      report "ECHEC : l'instruction a change pendant le deuxieme cycle de blocage"
      severity failure;
 
    assert current_pc = x"00000008"
      report "ECHEC : le PC a change pendant le deuxieme cycle de blocage"
      severity failure;
 
 
    -- TEST 5: reprise apres blocage, aucune instruction n'est perdue
    stall <= '0';
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(3)
      report "ECHEC : une instruction a ete perdue apres le blocage"
      severity failure;
 
    assert current_pc = x"0000000C"
      report "ECHEC : le PC doit valoir 12 apres le blocage"
      severity failure;
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(4)
      report "ECHEC : l'instruction du mot 4 est incorrecte"
      severity failure;
 
 
    -- TEST 6: saut pris (transfert + flush), l'instruction en cours est annulee
    transfer       <= '1';
    flush          <= '1';
    target_address <= x"00000020";
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = NOP and instr_valid = '0'
      report "ECHEC : l'instruction annulee par le flush doit etre un NOP"
      severity failure;
 
 
    -- TEST 7: l'instruction de destination du saut arrive juste apres
    transfer <= '0';
    flush    <= '0';
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(8) and instr_valid = '1'
      report "ECHEC : l'instruction de destination du saut est incorrecte"
      severity failure;
 
    assert current_pc = x"00000020"
      report "ECHEC : le PC doit valoir 0x20 apres le saut"
      severity failure;
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(9)
      report "ECHEC : incrementation apres le saut"
      severity failure;
 
    assert current_pc = x"00000024"
      report "ECHEC : le PC doit valoir 0x24 apres le saut"
      severity failure;
 
 
    -- TEST 8: un flush pendant un blocage garde l'instruction annulee
    stall <= '1';
    flush <= '1';
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = NOP and instr_valid = '0'
      report "ECHEC : flush pendant un blocage doit donner un NOP"
      severity failure;
 
    flush <= '0';
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = NOP and instr_valid = '0'
      report "ECHEC : le NOP doit rester pendant la suite du blocage"
      severity failure;
 
 
    -- TEST 9: fin du blocage, le fetch repart avec une instruction valide
    stall <= '0';
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert current_pc = x"00000028"
      report "ECHEC : le PC doit reprendre a 0x28 apres le blocage"
      severity failure;

    assert instruction = PROGRAMME(10) and instr_valid = '1'
      report "ECHEC : l'instruction ne correspond pas a la memoire a l'adresse du PC"
      severity failure;
 
 
    -- TEST 10: reset en plein programme, puis redemarrage propre
    reset_n  <= '0';
    stall    <= '0';
    flush    <= '0';
    transfer <= '0';
 
    wait for 1 ns;
 
    assert instruction = NOP and instr_valid = '0'
      report "ECHEC : l'instruction doit etre un NOP pendant le reset"
      severity failure;
 
    assert current_pc = RESET
      report "ECHEC : remise a zero du PC de l'etage IF"
      severity failure;
 
    reset_n <= '1';
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(0) and instr_valid = '1'
      report "ECHEC : redemarrage, le mot 0 doit sortir une seule fois"
      severity failure;
 
    wait until rising_edge(clock);
    wait for 1 ns;
 
    assert instruction = PROGRAMME(1)
      report "ECHEC : redemarrage, l'instruction du mot 1 est incorrecte"
      severity failure;
 
 
    report "SUCCES : les tests du fetch ont tous bien passe."
      severity note;
 
    std.env.stop;
    wait;
 
  end process;
 
end architecture;