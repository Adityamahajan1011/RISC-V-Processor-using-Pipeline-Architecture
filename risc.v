module process (
    input            clk1, clk2,
    input      [4:0] num,
    output     [4:0] result
);

    reg [31:0] instructions[7:0];   // 8 slots now
    reg [31:0] r[31:0];
    reg [2:0]  pro_count;

    reg [31:0] IFID_instr;
    reg [2:0]  IFID_PC;

    reg [5:0]  IDEX_opcode;
    reg [5:0]  IDEX_funct;
    reg [31:0] IDEX_a, IDEX_b, IDEX_imm;
    reg [4:0]  IDEX_dest;
    reg [2:0]  IDEX_PC;

    reg [31:0] EXMEM_AluOut;
    reg [4:0]  EXMEM_dest;
    reg [5:0]  EXMEM_opcode;
    reg        EXMEM_branch_taken;
    reg [2:0]  EXMEM_branch_target;

    reg [31:0] MEMWB_AluOut;
    reg [4:0]  MEMWB_dest;

    reg [31:0] alu_result_wire;
    reg [4:0]  alu_dest_wire;
    reg        branch_taken_wire;
    reg [2:0]  branch_target_wire;
    reg [31:0] branch_full;

    localparam ADDI      = 6'b001000;
    localparam RTYP      = 6'b000000;
    localparam BEQ       = 6'b000100;
    localparam FUNCT_MUL = 6'b011000;
    localparam FUNCT_ADD = 6'b100000;

    // -------------------------------------------------------
    // Program:
    // R1 = num (input)
    // R2 = guess (counts up from 1)
    // R3 = guess * guess
    // R4 = scratch (copy of R2 before MUL settles)
    //
    // [0] ADDI R2, R0, 1       R2 = 1
    // [1] ADDI R2, R0, 1       R2 = 1  (duplicate to fill pipeline)
    // [2] MUL  R3, R2, R2      R3 = R2 * R2
    // [3] NOP                  wait for MUL writeback
    // [4] NOP                  wait for MUL writeback
    // [5] BEQ  R3, R1, +1      if R3 == num, jump to [7]
    // [6] ADDI R2, R2, 1       guess++, then jump back to [2]
    //     BEQ  R0, R0, -5      back to [2]
    // -------------------------------------------------------
    // Simpler: unroll into a checked loop with NOPs as delay slots
    // -------------------------------------------------------
    // [0] ADDI R2, R0, 1       guess = 1
    // [1] MUL  R3, R2, R2      R3 = guess²
    // [2] NOP
    // [3] NOP
    // [4] BEQ  R3, R1, +2      if R3==num goto [7]
    // [5] ADDI R2, R2, 1       guess++
    // [6] BEQ  R0, R0, -6      goto [1]
    // [7] NOP  (result in R2)
    // -------------------------------------------------------

    initial begin
        // [0] ADDI R2, R0, 1
        instructions[0] = 32'b001000_00000_00010_0000000000000001;
        // [1] MUL R3, R2, R2
        instructions[1] = 32'b000000_00010_00010_00011_00000_011000;
        // [2] NOP
        instructions[2] = 32'b000000_00000_00000_00000_00000_100000;
        // [3] NOP
        instructions[3] = 32'b000000_00000_00000_00000_00000_100000;
        // [4] BEQ R3, R1, +2   →  target = 4+1+2 = 7
        instructions[4] = 32'b000100_00011_00001_0000000000000010;
        // [5] ADDI R2, R2, 1
        instructions[5] = 32'b001000_00010_00010_0000000000000001;
        // [6] BEQ R0, R0, -6   →  target = 6+1-6 = 1
        instructions[6] = 32'b000100_00000_00000_1111111111111010;
        // [7] NOP (done, result in R2)
        instructions[7] = 32'b000000_00000_00000_00000_00000_100000;
    end

    integer idx;
    always @(num) begin
        for (idx = 0; idx < 32; idx = idx + 1)
            r[idx] = 32'b0;
        r[1]                = {27'b0, num};
        pro_count           = 0;
        IFID_instr          = 0;
        IFID_PC             = 0;
        IDEX_opcode         = 0;
        IDEX_funct          = 0;
        IDEX_a              = 0;
        IDEX_b              = 0;
        IDEX_imm            = 0;
        IDEX_dest           = 0;
        IDEX_PC             = 0;
        EXMEM_AluOut        = 0;
        EXMEM_dest          = 0;
        EXMEM_opcode        = 0;
        EXMEM_branch_taken  = 0;
        EXMEM_branch_target = 0;
        MEMWB_AluOut        = 0;
        MEMWB_dest          = 0;
    end

    // IF (clk1)
    always @(posedge clk1) begin
        if (EXMEM_branch_taken) begin
            IFID_instr <= 32'b0;
            IFID_PC    <= 0;
            pro_count  <= EXMEM_branch_target;
        end else if (pro_count <= 7) begin
            IFID_instr <= instructions[pro_count];
            IFID_PC    <= pro_count;
            pro_count  <= pro_count + 1;
        end
    end

    // ID (clk2)
    always @(posedge clk2) begin
        IDEX_opcode <= IFID_instr[31:26];
        IDEX_funct  <= IFID_instr[5:0];
        IDEX_imm    <= {{16{IFID_instr[15]}}, IFID_instr[15:0]};
        IDEX_PC     <= IFID_PC;

        if      (EXMEM_dest != 0 && EXMEM_dest == IFID_instr[25:21])
            IDEX_a <= EXMEM_AluOut;
        else if (MEMWB_dest != 0 && MEMWB_dest == IFID_instr[25:21])
            IDEX_a <= MEMWB_AluOut;
        else
            IDEX_a <= r[IFID_instr[25:21]];

        if      (EXMEM_dest != 0 && EXMEM_dest == IFID_instr[20:16])
            IDEX_b <= EXMEM_AluOut;
        else if (MEMWB_dest != 0 && MEMWB_dest == IFID_instr[20:16])
            IDEX_b <= MEMWB_AluOut;
        else
            IDEX_b <= r[IFID_instr[20:16]];

        if (IFID_instr[31:26] == RTYP)
            IDEX_dest <= IFID_instr[15:11];
        else
            IDEX_dest <= IFID_instr[20:16];
    end

    // EX combinational
    always @(*) begin
        alu_result_wire    = 0;
        alu_dest_wire      = 0;
        branch_taken_wire  = 0;
        branch_target_wire = 0;
        branch_full        = 0;

        case (IDEX_opcode)
            RTYP: begin
                if (IDEX_funct == FUNCT_MUL)
                    alu_result_wire = IDEX_a * IDEX_b;
                else
                    alu_result_wire = IDEX_a + IDEX_b;
                alu_dest_wire = IDEX_dest;
            end
            ADDI: begin
                alu_result_wire = IDEX_a + IDEX_imm;
                alu_dest_wire   = IDEX_dest;
            end
            BEQ: begin
                if (IDEX_a == IDEX_b) begin
                    branch_full        = IDEX_PC + 1 + IDEX_imm;
                    branch_taken_wire  = 1;
                    branch_target_wire = branch_full[2:0];
                end
            end
            default: begin
                alu_result_wire = 0;
                alu_dest_wire   = 0;
            end
        endcase
    end

    // EX register (clk2)
    always @(posedge clk2) begin
        EXMEM_AluOut        <= alu_result_wire;
        EXMEM_dest          <= alu_dest_wire;
        EXMEM_opcode        <= IDEX_opcode;
        EXMEM_branch_taken  <= branch_taken_wire;
        EXMEM_branch_target <= branch_target_wire;
    end

    // MEM (clk1)
    always @(posedge clk1) begin
        MEMWB_AluOut <= EXMEM_AluOut;
        MEMWB_dest   <= EXMEM_dest;
    end

    // WB (clk2)
    always @(posedge clk2) begin
        if (MEMWB_dest != 0)
            r[MEMWB_dest] <= MEMWB_AluOut;
    end

    assign result = r[2][4:0];

endmodule