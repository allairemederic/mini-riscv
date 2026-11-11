library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_riscv_rf is
end entity;

architecture sim of tb_riscv_rf is

  signal clock        : std_logic := '0';
  signal reset_n      : std_logic := '0';
  signal write_enable : std_logic := '0';

  -- Adresses des registres à lire
  signal read_address_a : std_logic_vector(REG_WIDTH-1 downto 0) := (others => '0');
  signal read_address_b : std_logic_vector(REG_WIDTH-1 downto 0) := (others => '0');

  -- Valeurs lues
  signal read_data_a : std_logic_vector(XLEN-1 downto 0);
  signal read_data_b : std_logic_vector(XLEN-1 downto 0);

  -- Adresse et valeur à ecrire
  signal write_address : std_logic_vector(REG_WIDTH-1 downto 0) := (others => '0');
  signal write_data    : std_logic_vector(XLEN-1 downto 0) := (others => '0');

begin

  -- Période de 10 ns
  clock <= not clock after 5 ns;

  dut : entity work.riscv_rf
    port map (
      i_clk     => clock,
      i_rstn    => reset_n,
      i_we      => write_enable,
      i_addr_ra => read_address_a,
      o_data_ra => read_data_a,
      i_addr_rb => read_address_b,
      o_data_rb => read_data_b,
      i_addr_w  => write_address,
      i_data_w  => write_data
    );

  stimulus : process
  begin

    -- TEST 1: reset remet les sorties à 0
    reset_n <= '0';

    wait for 2 ns;

    assert read_data_a = x"00000000" and read_data_b = x"00000000"
      report "ECHEC : reset du banc de registres"
      severity failure;

    reset_n <= '1';


    -- TEST 2: Écrire 5 dans x1, puis relire x1
    write_enable <= '1';
    write_address <= std_logic_vector(to_unsigned(1, REG_WIDTH));
    write_data    <= x"00000005";

    -- Écriture au front montant
    wait until rising_edge(clock);
    wait for 1 ns;

    -- Arrêter écriture et demander lecture de x1
    write_enable   <= '0';
    read_address_a <= std_logic_vector(to_unsigned(1, REG_WIDTH));

    -- Lecture au front montant aussi
    wait until rising_edge(clock);
    wait for 1 ns;

    assert read_data_a = x"00000005"
      report "ECHEC : x1 devrait contenir 5"
      severity failure;


    -- TEST 3: Écrire 9 dans x2.
    write_enable  <= '1';
    write_address <= std_logic_vector(to_unsigned(2, REG_WIDTH));
    write_data    <= x"00000009";

    wait until rising_edge(clock);
    wait for 1 ns;

    -- Lire x1 sur le port A et x2 sur le port B
    write_enable   <= '0';
    read_address_a <= std_logic_vector(to_unsigned(1, REG_WIDTH));
    read_address_b <= std_logic_vector(to_unsigned(2, REG_WIDTH));

    wait until rising_edge(clock);
    wait for 1 ns;

    assert read_data_a = x"00000005"
      report "ECHEC : lecture de x1 sur le port A"
      severity failure;

    assert read_data_b = x"00000009"
      report "ECHEC : lecture de x2 sur le port B"
      severity failure;


    -- TEST 4: remplacer le contenu de x1 par 12
    write_enable  <= '1';
    write_address <= std_logic_vector(to_unsigned(1, REG_WIDTH));
    write_data    <= x"0000000C";

    wait until rising_edge(clock);
    wait for 1 ns;

    -- Lire x1 sur les deux ports
    write_enable   <= '0';
    read_address_a <= std_logic_vector(to_unsigned(1, REG_WIDTH));
    read_address_b <= std_logic_vector(to_unsigned(1, REG_WIDTH));

    wait until rising_edge(clock);
    wait for 1 ns;

    assert read_data_a = x"0000000C" and read_data_b = x"0000000C"
      report "ECHEC : les deux ports doivent lire 12 dans x1"
      severity failure;


    -- TEST 5: essayer de remplacer x1, mais écriture désactivée
    write_enable  <= '0';
    write_address <= std_logic_vector(to_unsigned(1, REG_WIDTH));
    write_data    <= x"00000063";

    wait until rising_edge(clock);
    wait for 1 ns;

    assert read_data_a = x"0000000C" and read_data_b = x"0000000C"
      report "ECHEC : ecriture effectuee avec write_enable a 0"
      severity failure;


    -- TEST 6: écrire et lire x1 au même front
    write_enable <= '1';
    write_data   <= x"0000002A";

    wait until rising_edge(clock);
    wait for 1 ns;

    assert read_data_a = x"0000002A"
      report "ECHEC : forwarding sur le port A"
      severity failure;

    assert read_data_b = x"0000002A"
      report "ECHEC : forwarding sur le port B"
      severity failure;


     -- TEST 7: Écrire puis relire le dernier registre (x31)
    write_address <= std_logic_vector(to_unsigned(31, REG_WIDTH));
    write_data    <= x"0000001F";

    wait until rising_edge(clock);
    wait for 1 ns;

    write_enable   <= '0';
    read_address_a <= std_logic_vector(to_unsigned(31, REG_WIDTH));

    wait until rising_edge(clock);
    wait for 1 ns;

    assert read_data_a = x"0000001F"
      report "ECHEC : lecture de x31"
      severity failure;


    -- TEST 8: changer l'adresse entre deux fronts montants
    wait until falling_edge(clock);
    read_address_a <= std_logic_vector(to_unsigned(1, REG_WIDTH));

    wait for 1 ns;

    assert read_data_a = x"0000001F"
      report "ECHEC : la lecture a change avant le front montant"
      severity failure;

    -- Au front montant suivant, la sortie doit montrer x1, soit 42
    wait until rising_edge(clock);
    wait for 1 ns;

    assert read_data_a = x"0000002A"
      report "ECHEC : lecture de x1 au front montant"
      severity failure;


    report "SUCCES : Tous les tests sur le banc de registres ont passé."
      severity note;

    std.env.stop;
    wait;

  end process;

end architecture;