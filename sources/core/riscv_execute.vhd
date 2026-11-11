library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity riscv_execute is
    port (
        i_clk  : in std_logic;
        i_rstn : in std_logic;

        -- Signaux de ID/EX.
        i_jump     : in std_logic;
        i_branch   : in std_logic;
        i_src_imm  : in std_logic;
        i_rs1_data : in word;
        i_rs2_data : in word;
        i_imm      : in word;
        i_pc       : in word;

        i_ex_stage : in decode_state;

        -- Donnee et destination pour le forwarding depuis Write-Back
        i_wb_data   : in word;
        i_wb_rd     : in reg_index;
        i_wb_enable : in std_logic;

        -- Redirection vers Fetch
        o_pc_transfert : out std_logic;
        o_pc_target    : out word;

        -- Sorties du registre EX/ME vers Memory
        o_alu_result : out word;
        o_store_data : out word;
        o_rd_addr    : out reg_index;
        o_rw         : out std_logic;
        o_we         : out std_logic;
        o_wb         : out std_logic
    );
end entity riscv_execute;

architecture beh of riscv_execute is

    signal can_forward_from_memory : boolean;

    signal rs1_value       : word;
    signal rs2_value       : word;
    signal alu_operand_b   : word;
    signal alu_result      : word;
    signal execute_result  : word;
    signal byte_swap_input : word;

    signal pc_plus_imm_sum : std_logic_vector(XLEN downto 0);
    signal pc_plus_imm     : word;

    -- Signaux memorises dans le registre EX/ME
    signal me_alu_result : word;
    signal me_store_data : word;
    signal me_rd_addr    : reg_index;
    signal me_rw         : std_logic;
    signal me_we         : std_logic;
    signal me_wb         : std_logic;

begin

    -- Le forwarding fournit une valeur recente avant son ecriture dans le RF
    -- Memory peut fournir un resultat si l'instruction ecrit dans rd.
    -- Pour un LW, EX/ME contient l'adresse de lecture
    -- La donnee lue devient disponible en Write-Back
    can_forward_from_memory <= (me_wb = '1') and (me_rw = '0');

    -- Comparer rs1 aux destinations de Memory et de Write-Back
    -- Si les deux correspondent, Memory a le resultat le plus recent
    -- Si aucune ne correspond, prendre la valeur du RF
    rs1_value <=
        me_alu_result
            when can_forward_from_memory and (me_rd_addr = i_ex_stage.rs1)
        else i_wb_data
            when (i_wb_enable = '1') and (i_wb_rd = i_ex_stage.rs1)
        else i_rs1_data;

    -- Appliquer la meme priorite pour rs2 : Memory, Write-Back, puis RF
    -- Pour un SW, cette valeur est la donnee a ecrire en memoire
    rs2_value <=
        me_alu_result
            when can_forward_from_memory and (me_rd_addr = i_ex_stage.rs2)
        else i_wb_data
            when (i_wb_enable = '1') and (i_wb_rd = i_ex_stage.rs2)
        else i_rs2_data;

    -- src_imm choisit le deuxieme operande de l'ALU
    -- Pour un SW, l'ALU utilise l'immediat pour calculer l'adresse tandis que rs2_value est transmis a Memory comme donnee a ecrire.
    alu_operand_b <= i_imm when i_src_imm = '1' else rs2_value;

    alu : entity work.riscv_alu
        port map (
            i_arith  => i_ex_stage.arith,
            i_sign   => i_ex_stage.sign_mode,
            i_opcode => i_ex_stage.alu_code,
            i_shamt  => alu_operand_b(SHAMT_WIDTH-1 downto 0),
            i_src1   => rs1_value,
            i_src2   => alu_operand_b,
            o_res    => alu_result
        );

    -- Additionneur pour PC + immediat
    target_adder : entity work.riscv_adder
        generic map (
            N => XLEN
        )
        port map (
            i_a    => i_pc,
            i_b    => i_imm,
            i_sign => '0',
            i_sub  => '0',
            o_sum  => pc_plus_imm_sum
        );

    pc_plus_imm <= pc_plus_imm_sum(XLEN-1 downto 0);

    -- Un JAL ou un JALR valide redirige Fetch
    -- Un BEQ valide redirige Fetch si les deux valeurs sont egales
    o_pc_transfert <= i_ex_stage.valid
        when (i_jump = '1') or ((i_branch = '1') and (rs1_value = rs2_value))
        else '0';

    -- BEQ et JAL utilisent PC + immediat
    -- JALR utilise rs1 + immediat et efface le bit 0
    o_pc_target <= (alu_result and JUMP_MASK) when (i_jump = '1') and (i_ex_stage.op = jalr_op) else pc_plus_imm;

    -- ESWP prend son operande dans rs1 ou dans l'immediat
    byte_swap_input <= i_imm when i_ex_stage.funct3(2) = '1' else rs1_value;

    -- Choisir la valeur a enregistrer dans EX/ME
    process(all)
    begin
        execute_result <= alu_result;

        case i_ex_stage.op is
            when lui_op =>
                execute_result <= i_imm;

            when auipc_op =>
                execute_result <= pc_plus_imm;

            when jal_op | jalr_op =>
                -- Transmettre PC + 4 a Write-Back comme adresse de retour
                execute_result <= std_logic_vector(
                    unsigned(i_pc) + to_unsigned(ADDR_INCR, XLEN)
                );

            when eswp_op =>
                -- Inverser l'ordre des quatre octets
                -- TODO: ajouter la bonne version
                execute_result <= byte_swap_input(7 downto 0) &
                                  byte_swap_input(15 downto 8) &
                                  byte_swap_input(23 downto 16) &
                                  byte_swap_input(31 downto 24);

            when others =>
                null;
        end case;
    end process;

    -- Registre EX/ME
    process(i_clk, i_rstn)
    begin
        if i_rstn = '0' then
            me_alu_result <= (others => '0');
            me_store_data <= (others => '0');
            me_rd_addr    <= REG_X0;
            me_rw         <= '0';
            me_we         <= '0';
            me_wb         <= '0';

        elsif rising_edge(i_clk) then
            me_alu_result <= execute_result;
            me_store_data <= rs2_value;
            me_rd_addr    <= i_ex_stage.rd;

            -- Une bulle ne doit activer ni Memory ni Write-Back
            me_rw <= i_ex_stage.valid when i_ex_stage.op = load_op else '0';
            me_we <= i_ex_stage.valid when i_ex_stage.op = store_op else '0';
            me_wb <= (i_ex_stage.valid and i_ex_stage.writes_rd) when i_ex_stage.rd /= REG_X0 else '0';
        end if;
        
    end process;

    o_alu_result <= me_alu_result;
    o_store_data <= me_store_data;
    o_rd_addr    <= me_rd_addr;
    o_rw         <= me_rw;
    o_we         <= me_we;
    o_wb         <= me_wb;

end architecture beh;