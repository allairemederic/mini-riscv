library ieee;
use ieee.std_logic_1164.all;

entity tb_riscv_adder is
end entity tb_riscv_adder;

architecture sim of tb_riscv_adder is
  constant N : positive := 32;

  -- Signaux envoyés au adder
  signal operand_a : std_logic_vector(N-1 downto 0) := (others => '0');
  signal operand_b : std_logic_vector(N-1 downto 0) := (others => '0');
  signal signed_mode : std_logic := '0';
  signal subtract_mode : std_logic := '0';

  -- Résultat du adder 
  signal actual_result : std_logic_vector(N downto 0);
begin

  -- Instande du adder
  dut : entity work.riscv_adder
    generic map (N => N)

    -- Relier les signaux du TB aux ports du adder
    port map (
      i_a    => operand_a,
      i_b    => operand_b,
      i_sign => signed_mode,
      i_sub  => subtract_mode,
      o_sum  => actual_result
    );

  stimulus : process

    -- Applique les tests les uns après les autres
    -- Aucume horloge, car adder est combinatoire
    procedure check_result (
      constant test_name       : in string;
      constant input_a         : in std_logic_vector(N-1 downto 0);
      constant input_b         : in std_logic_vector(N-1 downto 0);
      constant use_signed      : in std_logic;
      constant use_subtraction : in std_logic;
      constant expected_result : in std_logic_vector(N downto 0)
    ) is
    begin

      -- Appliquer les deux nombres au adder
      operand_a     <= input_a;
      operand_b     <= input_b;

      -- Choisir le mode
      -- use_signed = 0 est pour non-signé, alors que use_signed = 1 est signé
      -- use_subtraction = 0 pour une addition, alors que use_subtraction = 1 pour soustraction
      signed_mode   <= use_signed;
      subtract_mode <= use_subtraction;

      -- Pour laisser le résultat se stabiliser avant de le vérifier
      wait for 10 ns;

      -- Comparaison du résultat attendu
      assert actual_result = expected_result
        report "ECHEC : " & test_name
        severity failure;

    end procedure check_result;

  begin

    -- TEST 1: 0 + 0 = 0
    check_result("0 + 0", x"00000000", x"00000000", '0', '0', '0' & x"00000000");

    -- TEST 2: addition simple 5 + 3 = 8
    check_result("5 + 3", x"00000005", x"00000003", '0', '0', '0' & x"00000008");

    -- TEST 3: retenue doit traverser plusieurs bits
    check_result("Propagation de retenue : 65535 + 1", x"0000FFFF", x"00000001", '0', '0', '0' & x"00010000");
    
    -- TEST 4: résultat dépasse 32 bits
    check_result("Maximum non signe + 1", x"FFFFFFFF", x"00000001", '0', '0', '1' & x"00000000");
    
    -- TEST 5: addition des maximums
    check_result("Deux maximums non signes", x"FFFFFFFF", x"FFFFFFFF", '0', '0', '1' & x"FFFFFFFE");

    -- TEST 6: Soustraction qui donne un résultat positif
    check_result("7 - 3", x"00000007", x"00000003", '0', '1', '0' & x"00000004");

    -- TEST 7: Soustraction qui donne un négatif
    check_result("3 - 7 = -4", x"00000003", x"00000007", '0', '1', '1' & x"FFFFFFFC");

    -- TEST 8: A - A = 0
    check_result("A - A = 0", x"89ABCDEF", x"89ABCDEF", '0', '1', '0' & x"00000000");

    -- TEST 9: vérifier -1
    check_result("0 - 1 = -1", x"00000000", x"00000001", '0', '1', '1' & x"FFFFFFFF");

    -- TEST 10: Addition de deux nombres positifs signés
    check_result("5 + 3 signe", x"00000005", x"00000003", '1', '0', '0' & x"00000008");

    -- TEST 11: Addition de deux nombres négatifs
    check_result("-5 + (-3) = -8", x"FFFFFFFB", x"FFFFFFFD", '1', '0', '1' & x"FFFFFFF8");
    
    -- TEST 12: -1 + 1 = 0
    check_result("-1 + 1 = 0", x"FFFFFFFF", x"00000001", '1', '0', '0' & x"00000000");
    
    -- TEST 13: Soustraire deux nombres positifs, avec résultat positif
    check_result("7 - 3 signe", x"00000007", x"00000003", '1', '1', '0' & x"00000004");
    
    -- TEST 14: Soustaire deux nombres positifs, mais résultat négatif
    check_result("3 - 7 signe = -4", x"00000003", x"00000007", '1', '1', '1' & x"FFFFFFFC");
    
    -- TEST 15: Soustraire un négatif
    check_result("5 - (-3) = 8", x"00000005", x"FFFFFFFD", '1', '1', '0' & x"00000008");
    
    -- TEST 16: Soustraire deux négatifs
    check_result("-5 - (-3) = -2", x"FFFFFFFB", x"FFFFFFFD", '1', '1', '1' & x"FFFFFFFE");
    
    -- TEST 17: Résultat plus petit que le minimum signé
    check_result("Minimum signe - 1", x"80000000", x"00000001", '1', '1', '1' & x"7FFFFFFF");

    report "SUCCES : tous les tests ont passe."
      severity note;

    wait;
  end process stimulus;

end architecture sim;