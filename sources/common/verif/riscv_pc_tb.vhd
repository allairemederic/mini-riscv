library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_riscv_pc is
end entity;

architecture sim of tb_riscv_pc is

  signal clock          : std_logic := '0';
  signal reset_n        : std_logic := '0';
  signal stall          : std_logic := '0';
  signal transfer       : std_logic := '0';
  signal target_address : std_logic_vector(XLEN-1 downto 0) := (others => '0');
  signal current_pc     : std_logic_vector(XLEN-1 downto 0);

begin

  -- Periode de 10 ns
  clock <= not clock after 5 ns;

  -- Relier le PC aux signaux du testbench
  dut : entity work.riscv_pc
    port map (
      i_clk       => clock,
      i_rstn      => reset_n,
      i_stall     => stall,
      i_transfert => transfer,
      i_target    => target_address,
      o_pc        => current_pc
    );

  stimulus : process
  begin

    -- TEST 1: reset charge l'adresse initiale.
    reset_n <= '0';

    wait for 2 ns;

    assert current_pc = RESET
      report "ECHEC : reset du PC"
      severity failure;


    -- TEST 2: PC augmente de 4 sans blocage ni saut
    reset_n <= '1';

    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = std_logic_vector(unsigned(RESET) + 4)
      report "ECHEC : incrementation du PC"
      severity failure;


    -- TEST 3: stall empeche le PC de changer
    stall <= '1';

    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = std_logic_vector(unsigned(RESET) + 4)
      report "ECHEC : le PC a change pendant le blocage"
      severity failure;


    -- TEST 4: charger l'adresse de saut 0x100.
    stall          <= '0';
    transfer       <= '1';
    target_address <= x"00000100";

    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = x"00000100"
      report "ECHEC : saut du PC"
      severity failure;


    -- TEST 5: repartir de 0 et désactiver les anciennes commandes
    reset_n  <= '0';
    stall    <= '0';
    transfer <= '0';

    wait for 1 ns;

    assert current_pc = x"00000000"
      report "ECHEC : remise a zero du PC"
      severity failure;

    reset_n <= '1';


    -- TEST 6: bloquer pendant 2 cycles
    -- Premier cycle apres le reset : PC = 4
    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = x"00000004"
      report "ECHEC : PC devrait valoir 4"
      severity failure;

    -- Deuxieme cycle : PC = 8
    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = x"00000008"
      report "ECHEC : PC devrait valoir 8"
      severity failure;

    -- Troisieme cycle : PC = 12
    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = x"0000000C"
      report "ECHEC : PC devrait valoir 12"
      severity failure;

    -- Bloquer le PC maintenant qu'il vaut 12
    stall <= '1';

    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = x"0000000C"
      report "ECHEC : premier cycle de blocage"
      severity failure;

    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = x"0000000C"
      report "ECHEC : deuxieme cycle de blocage"
      severity failure;


    -- TEST 7: un stall doit gagner over une demande de jump
    transfer       <= '1';
    target_address <= x"00000100";

    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = x"0000000C"
      report "ECHEC : le blocage doit empecher le saut"
      severity failure;


    -- TEST 8: reprendre l'incrémentation après un blocage
    stall    <= '0';
    transfer <= '0';

    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = x"00000010"
      report "ECHEC : reprise apres blocage"
      severity failure;


    -- TEST 9: faire un jump
    transfer       <= '1';
    target_address <= x"00000100";

    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = x"00000100"
      report "ECHEC : saut vers 0x100"
      severity failure;

    
    -- TEST 10: reprendre l'incrémentation après le jump
    transfer <= '0';

    wait until rising_edge(clock);
    wait for 1 ns;

    assert current_pc = x"00000104"
      report "ECHEC : incrementation apres le saut"
      severity failure;


    report "SUCCES : les tests du PC ont tous bien passé."
      severity note;

    std.env.stop;
    wait;

  end process;

end architecture;