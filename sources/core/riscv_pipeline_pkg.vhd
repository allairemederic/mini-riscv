library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv_pkg.all;

package riscv_pipeline is

  -- Mot de données
  subtype word is std_logic_vector(XLEN-1 downto 0);

  -- Numéro de registre
  subtype reg_index is std_logic_vector(REG_WIDTH-1 downto 0);

  -- Catégories d'opérations utilisées par Execute
  type operation is (
    alu_op,
    lui_op,
    auipc_op,
    load_op,
    store_op,
    beq_op,
    jal_op,
    jalr_op,
    eswp_op
  );

  -- Informations sur l'instruction transmises de Decode à Execute
  type decode_state is record
    valid     : std_logic;
    writes_rd : std_logic;
    uses_rs1  : std_logic;
    uses_rs2  : std_logic;
    use_imm   : std_logic;
    arith     : std_logic;
    sign_mode : std_logic;
    op        : operation;
    alu_code  : std_logic_vector(ALUOP_WIDTH-1 downto 0);
    funct3    : std_logic_vector(2 downto 0);
    rs1       : reg_index;
    rs2       : reg_index;
    rd        : reg_index;
    pc        : word;
    imm       : word;
  end record;

  -- Entrée vide utilisée au reset ou pour insérer une bulle
  constant EMPTY_DECODE : decode_state := (

    -- Validité, écriture et utilisation des registres sources
    valid     => '0',
    writes_rd => '0',
    uses_rs1  => '0',
    uses_rs2  => '0',

    -- Sélection des opérandes et commandes de l'ALU
    use_imm   => '0',
    arith     => '0',
    sign_mode => '0',
    op        => alu_op,
    alu_code  => ALUOP_ADD,
    funct3    => "000",

    -- Registres sources et destination, PC et immédiat
    rs1       => REG_X0,
    rs2       => REG_X0,
    rd        => REG_X0,
    pc        => (others => '0'),
    imm       => (others => '0')
  );

  -- Informations sur l'instruction qui traversent Memory et Write Back
  type memory_state is record
    valid       : std_logic;
    writes_rd   : std_logic;
    is_load     : std_logic;
    is_store    : std_logic;
    rd          : reg_index;

    -- Pour ADD, result contient la valeur à écrire dans rd
    -- Pour LW et SW, result contient l'adresse en octets calculée par Execute
    -- is_load et is_store indiquent comment utiliser result
    result      : word;

    -- Pour SW, valeur à écrire en mémoire
    store_value : word;
  end record;

  -- Entrée vide qui ne déclenche aucune écriture de registre ni aucun accès mémoire
  constant EMPTY_MEMORY : memory_state := (
    valid       => '0',
    writes_rd   => '0',
    is_load     => '0',
    is_store    => '0',
    rd          => REG_X0,
    result      => (others => '0'),
    store_value => (others => '0')
  );

end package riscv_pipeline;