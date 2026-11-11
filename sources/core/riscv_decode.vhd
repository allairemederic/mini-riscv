library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;
use work.riscv_pipeline.all;

entity riscv_decode is
    port (
        i_clk   : in std_logic;
        i_rstn  : in std_logic;
        i_flush : in std_logic;

        -- Instruction et PC de IF/ID
        i_valid : in std_logic;
        i_instr : in word;
        i_pc    : in word;

        -- Ecriture dans le RF depuis Write-Back
        i_wb_enable : in std_logic;
        i_wb_value  : in word;
        i_wb_rd     : in reg_index;

        -- Instruction en ID pour la detection du stall dans le core
        o_decoded  : out decode_state;

        -- Instruction et signaux transmis a Execute
        o_ex_stage : out decode_state;
        o_rs1_data : out word;
        o_rs2_data : out word;
        o_rd_addr  : out reg_index;
        o_pc       : out word;
        o_branch   : out std_logic;
        o_jump     : out std_logic;
        o_rw       : out std_logic;
        o_we       : out std_logic;
        o_wb       : out std_logic;
        o_arith    : out std_logic;
        o_sign     : out std_logic;
        o_imm      : out word;
        o_src_imm  : out std_logic;
        o_alu_op   : out std_logic_vector(ALUOP_WIDTH-1 downto 0)
    );
end entity riscv_decode;

architecture beh of riscv_decode is

    constant OPCODE_ALU_REG : std_logic_vector(6 downto 0) := "0110011";
    constant OPCODE_ALU_IMM : std_logic_vector(6 downto 0) := "0010011";
    constant FUNCT7_NORMAL : std_logic_vector(6 downto 0) := "0000000";
    constant FUNCT7_ALT    : std_logic_vector(6 downto 0) := "0100000";

    -- Champs produits par le predecodeur
    signal opcode   : std_logic_vector(6 downto 0);
    signal funct3   : std_logic_vector(2 downto 0);
    signal funct7   : std_logic_vector(6 downto 0);
    signal rs1_addr : reg_index;
    signal rs2_addr : reg_index;
    signal rd_addr  : reg_index;

    signal decoded_instruction : decode_state;
    signal id_ex                : decode_state;

    -- Etendre l'immediat en recopiant son bit de signe
    function sign_extend_immediate(bits : std_logic_vector) return word is
    begin
        return std_logic_vector(resize(signed(bits), XLEN));
    end function;

begin

    opcode   <= i_instr(6 downto 0);
    funct3   <= i_instr(14 downto 12);
    funct7   <= i_instr(31 downto 25);
    rs1_addr <= i_instr(19 downto 15);
    rs2_addr <= i_instr(24 downto 20);
    rd_addr  <= i_instr(11 downto 7);

    -- Decoder les controles et reconstruire l'immediat en combinatoire
    process(all)
        variable d : decode_state;
    begin
        d := EMPTY_DECODE;
        d.valid  := i_valid;
        d.pc     := i_pc;
        d.rs1    := rs1_addr;
        d.rs2    := rs2_addr;
        d.rd     := rd_addr;
        d.funct3 := funct3;

        -- Valeur par defaut pour les instructions au format I
        d.imm := sign_extend_immediate(i_instr(31 downto 20));

        case opcode is

            when OPCODE_ALU_REG | OPCODE_ALU_IMM =>
                d.writes_rd := '1';
                d.uses_rs1  := '1';

                if opcode = OPCODE_ALU_IMM then
                    d.use_imm := '1';
                else
                    d.uses_rs2 := '1';
                end if;

                -- Verifier funct7 pour le format R et les decalages immediats
                -- L'encodage alternatif correspond a SUB ou a SRA/SRAI
                if (opcode = OPCODE_ALU_REG) or (funct3 = "001") or (funct3 = "101") then

                    if funct7 /= FUNCT7_NORMAL then

                        if (funct7 /= FUNCT7_ALT) or
                           ((funct3 /= "101") and ((opcode /= OPCODE_ALU_REG) or (funct3 /= "000"))) then
                            d.valid := '0';
                        end if;
                    end if;
                end if;

                case funct3 is
                    when "000" => -- ADD, ADDI, SUB
                        if (opcode = OPCODE_ALU_REG) and (funct7 = FUNCT7_ALT) then
                            d.arith := '1';
                        end if;

                    when "001" => -- SLL, SLLI
                        d.alu_code := ALUOP_SL;

                    when "010" => -- SLT, SLTI
                        d.alu_code  := ALUOP_SLT;
                        d.arith     := '1';
                        d.sign_mode := '1';

                    when "011" => -- SLTU, SLTIU
                        d.alu_code := ALUOP_SLT;
                        d.arith    := '1';

                    when "100" => -- XOR, XORI
                        d.alu_code := ALUOP_XOR;

                    when "101" => -- SRL, SRLI, SRA, SRAI
                        d.alu_code := ALUOP_SR;
                        if funct7 = FUNCT7_ALT then
                            d.arith := '1';
                        end if;

                    when "110" => -- OR, ORI
                        d.alu_code := ALUOP_OR;

                    when "111" => -- AND, ANDI
                        d.alu_code := ALUOP_AND;

                    when others =>
                        d.valid := '0';
                end case;

            when "0110111" => -- LUI
                d.op        := lui_op;
                d.writes_rd := '1';
                d.imm       := i_instr(31 downto 12) & x"000";

            when "0010111" => -- AUIPC
                d.op        := auipc_op;
                d.writes_rd := '1';
                d.imm       := i_instr(31 downto 12) & x"000";

            when "0000011" => -- LW
                d.op        := load_op;
                d.writes_rd := '1';
                d.uses_rs1  := '1';
                d.use_imm   := '1';

                if funct3 /= "010" then
                    d.valid := '0';
                end if;

            when "0100011" => -- SW
                d.op       := store_op;
                d.uses_rs1 := '1';
                d.uses_rs2 := '1';
                d.use_imm  := '1';

                -- Reconstruire l'immediat du format S
                d.imm := sign_extend_immediate(i_instr(31 downto 25) & i_instr(11 downto 7));

                if funct3 /= "010" then
                    d.valid := '0';
                end if;

            when "1100011" => -- BEQ
                d.op       := beq_op;
                d.uses_rs1 := '1';
                d.uses_rs2 := '1';

                -- Reconstruire le deplacement B avec un zero au bit 0
                d.imm := sign_extend_immediate(
                    i_instr(31) & i_instr(7) & i_instr(30 downto 25) & i_instr(11 downto 8) & '0'
                );

                if funct3 /= "000" then
                    d.valid := '0';
                end if;

            when "1101111" => -- JAL
                d.op        := jal_op;
                d.writes_rd := '1';

                -- Reconstruire le deplacement J avec un zero au bit 0
                d.imm := sign_extend_immediate(
                    i_instr(31) & i_instr(19 downto 12) & i_instr(20) &
                    i_instr(30 downto 21) & '0'
                );

            when "1100111" => -- JALR
                d.op        := jalr_op;
                d.writes_rd := '1';
                d.uses_rs1  := '1';
                d.use_imm   := '1';

                if funct3 /= "000" then
                    d.valid := '0';
                end if;

            when "1010101" => -- ESWP
                d.op        := eswp_op;
                d.writes_rd := '1';
                d.uses_rs1  := not funct3(2);

            when others =>
                d.valid := '0';

        end case;

        decoded_instruction <= d;
    end process;

    -- Le RF lit rs1 et rs2 au front montant
    -- Les operandes et les controles ID/EX arrivent ensemble en Execute
    register_file : entity work.riscv_rf
        port map (
            i_clk     => i_clk,
            i_rstn    => i_rstn,
            i_we      => i_wb_enable,
            i_addr_ra => rs1_addr,
            o_data_ra => o_rs1_data,
            i_addr_rb => rs2_addr,
            o_data_rb => o_rs2_data,
            i_addr_w  => i_wb_rd,
            i_data_w  => i_wb_value
        );

    -- Mettre une bubble dans ID/EX lors d'un flush ou d'un stall
    process(i_clk, i_rstn)
    begin
        if i_rstn = '0' then
            id_ex <= EMPTY_DECODE;
        elsif rising_edge(i_clk) then
            if i_flush = '1' then
                id_ex <= EMPTY_DECODE;
            else
                id_ex <= decoded_instruction;
            end if;
        end if;
    end process;

    o_decoded  <= decoded_instruction;
    o_ex_stage <= id_ex;

    -- Signaux qui sortent de ID/EX
    o_rd_addr <= id_ex.rd;
    o_pc      <= id_ex.pc;
    o_branch  <= id_ex.valid when id_ex.op = beq_op else '0';
    o_jump    <= id_ex.valid when (id_ex.op = jal_op) or (id_ex.op = jalr_op)
                 else '0';
    o_rw      <= id_ex.valid when id_ex.op = load_op else '0';
    o_we      <= id_ex.valid when id_ex.op = store_op else '0';
    o_wb      <= id_ex.valid and id_ex.writes_rd;
    o_arith   <= id_ex.arith;
    o_sign    <= id_ex.sign_mode;
    o_imm     <= id_ex.imm;
    o_src_imm <= id_ex.use_imm;
    o_alu_op  <= id_ex.alu_code;

end architecture beh;