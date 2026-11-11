library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity tb_riscv_alu is
end entity;

architecture sim of tb_riscv_alu is

  signal arithmetic_mode : std_logic := '0';
  signal signed_mode     : std_logic := '0';

  -- Opération choisie et nombre de bits à décaler
  signal operation : std_logic_vector(ALUOP_WIDTH-1 downto 0) := ALUOP_ADD;
  signal shift_amount : std_logic_vector(SHAMT_WIDTH-1 downto 0) := (others => '0');

  -- Opérandes du ALU
  signal operand_a : std_logic_vector(XLEN-1 downto 0) := (others => '0');
  signal operand_b : std_logic_vector(XLEN-1 downto 0) := (others => '0');

  -- Résultat du ALU
  signal actual_result : std_logic_vector(XLEN-1 downto 0);

begin

  dut : entity work.riscv_alu
    port map (
      i_arith  => arithmetic_mode,
      i_sign   => signed_mode,
      i_opcode => operation,
      i_shamt  => shift_amount,
      i_src1   => operand_a,
      i_src2   => operand_b,
      o_res    => actual_result
    );

  stimulus : process
  begin

    -- TEST 1: Addition
    operation       <= ALUOP_ADD;
    arithmetic_mode <= '0';
    operand_a       <= x"00000005";
    operand_b       <= x"00000003";

    wait for 10 ns;

    assert actual_result = x"00000008"
      report "ECHEC : addition 5 + 3"
      severity failure;

    -- TEST 2: Soustraction
    -- Garder ALUOP_ADD, mais mettre i_arith à 1
    arithmetic_mode <= '1';

    wait for 10 ns;

    assert actual_result = x"00000002"
      report "ECHEC : soustraction 5 - 3"
      severity failure;


    -- TEST 3: AND
    operation       <= ALUOP_AND;
    arithmetic_mode <= '0';
    operand_a       <= x"0000000C";
    operand_b       <= x"0000000A";

    wait for 10 ns;

    assert actual_result = x"00000008"
      report "ECHEC : opération AND"
      severity failure;


    -- TEST 4 : Décaler 1 de deux bits à gauche
    operation    <= ALUOP_SL;
    operand_a    <= x"00000001";
    shift_amount <= std_logic_vector(to_unsigned(2, SHAMT_WIDTH));

    wait for 10 ns;

    assert actual_result = x"00000004"
      report "ECHEC : décalage à gauche"
      severity failure;


    -- TEST 5: OR
    operation       <= ALUOP_OR;
    arithmetic_mode <= '0';
    signed_mode     <= '0';
    operand_a       <= x"0000000C";
    operand_b       <= x"0000000A";

    wait for 10 ns;

    assert actual_result = x"0000000E"
      report "ECHEC : OR"
      severity failure;

    -- TEST 6: XOR
    operation <= ALUOP_XOR;

    wait for 10 ns;

    assert actual_result = x"00000006"
      report "ECHEC : XOR"
      severity failure;

    
    -- TEST 7: Décalage à droite logique
    -- Le bit ajouté à gauche doit être 0
    operation       <= ALUOP_SR;
    arithmetic_mode <= '0';
    operand_a       <= x"80000000";
    shift_amount    <= std_logic_vector(to_unsigned(1, SHAMT_WIDTH));

    wait for 10 ns;

    assert actual_result = x"40000000"
      report "ECHEC : decalage a droite logique"
      severity failure;


    -- TEST 8: Décalage à droite arithmétique
    -- Le bit de signe droit être recopié à gauche
    arithmetic_mode <= '1';

    wait for 10 ns;

    assert actual_result = x"C0000000"
      report "ECHEC : decalage a droite arithmetique"
      severity failure;

    
    -- TEST 9: comparaison signée (-1 < 1)
    -- Pour comparer, l'additionneur doit faire une soustraction
    operation       <= ALUOP_SLT;
    arithmetic_mode <= '1';
    signed_mode     <= '1';
    operand_a       <= x"FFFFFFFF";
    operand_b       <= x"00000001";

    wait for 10 ns;

    assert actual_result = x"00000001"
      report "ECHEC : comparaison signee"
      severity failure;

    
    -- TEST 10: comparaison non signée
    signed_mode <= '0';

    wait for 10 ns;

    assert actual_result = x"00000000"
      report "ECHEC : comparaison non signee"
      severity failure;


    -- TEST 11: 5 < 5 est faux
    operand_a <= x"00000005";
    operand_b <= x"00000005";

    wait for 10 ns;

    assert actual_result = x"00000000"
      report "ECHEC : comparaison de valeurs egales"
      severity failure;

     -- TEST 12: décalage de 0 conserve la valeur
    operation    <= ALUOP_SL;
    operand_a    <= x"00000001";
    shift_amount <= std_logic_vector(to_unsigned(0, SHAMT_WIDTH));

    wait for 10 ns;

    assert actual_result = x"00000001"
      report "ECHEC : decalage de 0"
      severity failure;


    report "SUCCES : tous les tests de l'ALU ont passé."
      severity note;

    std.env.stop;
    wait;

  end process;

end architecture;