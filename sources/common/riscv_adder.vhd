-------------------------------------------------------------------------------
-- Project  ELE8304 : Circuits intégrés à très grande échelle
-- Polytechnique Montréal
-------------------------------------------------------------------------------
-- File     riscv_adder.vhd
-- Author   Théo Dupuis  <theo.dupuis@polymtl.ca>
-- Date     2022-08-27
-------------------------------------------------------------------------------
-- Description 	adder with ripple-carry
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity riscv_adder is
  generic (
    N : positive := 32
  );
  port (
    i_a    : in  std_logic_vector(N-1 downto 0);
    i_b    : in  std_logic_vector(N-1 downto 0);
    i_sign : in  std_logic;
    i_sub  : in  std_logic;
    o_sum  : out std_logic_vector(N downto 0)
  );
end entity riscv_adder;

architecture beh of riscv_adder is

  -- Ajouter un bit aux opérandes pour calculer sur N+1 bits
  signal a_with_extra_bit : std_logic_vector(N downto 0);
  signal b_with_extra_bit : std_logic_vector(N downto 0);

  -- B conservé pou l'addition OU inversé pour la soustraction
  signal selected_b : std_logic_vector(N downto 0);

  -- Retenues entre les étages
  signal carry_into_stage : std_logic_vector(N+1 downto 0);

  -- Sorties du premier half-adder
  signal sum_from_first_half_adder : std_logic_vector(N downto 0);
  signal carry_from_first_half_adder : std_logic_vector(N downto 0);

  -- Retenues du 2e half-adder
  signal carry_from_second_half_adder : std_logic_vector(N downto 0);

begin

  -- Ajouter un 0 en non-signé OU recopier le signe en signé
  a_with_extra_bit <= (i_a(N-1) and i_sign) & i_a;
  b_with_extra_bit <= (i_b(N-1) and i_sign) & i_b;

  -- Ajouter 1 en soustraction
  -- A - B = A + not(B) + 1
  carry_into_stage(0) <= i_sub;

  -- Construire un étage pour chaque bit du résultat
  -- Chaque étage comprend deux half-adder et une porte OR
  gen_bits : for k in 0 to N generate

    -- Si i_sub = 0 (addition), il faut conserver B
    -- Si i_sub = 1 (soustraction), il faut inverser B
    selected_b(k) <= b_with_extra_bit(k) xor i_sub;

    -- Premier half-adder
    -- Il faut additionner les bits de A et B
    sum_from_first_half_adder(k)   <= a_with_extra_bit(k) xor selected_b(k);
    carry_from_first_half_adder(k) <= b_with_extra_bit(k) and selected_b(k);

    -- Deuxième half-adder
    -- Il faut ajouter la retenue précédente
    o_sum(k) <= sum_from_first_half_adder(k) xor carry_into_stage(k);
    carry_from_second_half_adder(k) <= sum_from_first_half_adder(k) and carry_into_stage(k);

    -- Porte OR pour transmettre la retenue à l'étage suivant
    carry_into_stage(k+1)   <= carry_from_first_half_adder(k) or carry_from_second_half_adder(k);
    
  end generate gen_bits;

end architecture beh;
