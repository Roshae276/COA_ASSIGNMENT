module main_control (
    input  wire [31:0] instruction,

    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg [1:0]  result_src,
    output reg        alu_src,
    output reg [1:0]  alu_src_a,
    output reg [1:0]  alu_op,
    output reg        branch,
    output reg        jump,
    output reg        jalr
);

    wire [6:0] opcode;

    assign opcode = instruction[6:0];

    always @(*) begin

        // Default values
        reg_write = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        result_src = 2'b00;
        alu_src   = 1'b0;
        alu_src_a = 2'b00;
        alu_op    = 2'b00;
        branch    = 1'b0;
        jump      = 1'b0;
        jalr      = 1'b0;

        case (opcode)

            // ------------------------------------------------
            // R-type instructions
            // ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
            // ------------------------------------------------
            7'b0110011: begin
                reg_write = 1'b1;
                result_src = 2'b00;   // ALU result
                alu_src   = 1'b0;     // rs2
                alu_src_a = 2'b00;    // rs1
                alu_op    = 2'b10;    // R-type ALU control
            end


            // ------------------------------------------------
            // I-type arithmetic instructions
            // ADDI, ANDI, ORI, XORI, SLTI, etc.
            // ------------------------------------------------
            7'b0010011: begin
                reg_write = 1'b1;
                result_src = 2'b00;   // ALU result
                alu_src   = 1'b1;     // immediate
                alu_src_a = 2'b00;    // rs1
                alu_op    = 2'b11;    // I-type ALU control
            end


            // ------------------------------------------------
            // LW - Load Word
            // ------------------------------------------------
            7'b0000011: begin
                reg_write = 1'b1;
                mem_read  = 1'b1;
                result_src = 2'b01;   // Memory data
                alu_src   = 1'b1;     // immediate
                alu_src_a = 2'b00;    // rs1
                alu_op    = 2'b00;    // ADD for address
            end


            // ------------------------------------------------
            // SW - Store Word
            // ------------------------------------------------
            7'b0100011: begin
                reg_write = 1'b0;
                mem_write = 1'b1;
                result_src = 2'b00;   // Not used
                alu_src   = 1'b1;     // immediate
                alu_src_a = 2'b00;    // rs1
                alu_op    = 2'b00;    // ADD for address
            end


            // ------------------------------------------------
            // BEQ - Branch if Equal
            // ------------------------------------------------
            7'b1100011: begin
                reg_write = 1'b0;
                result_src = 2'b00;   // Not used
                alu_src   = 1'b0;     // rs2
                alu_src_a = 2'b00;    // rs1
                alu_op    = 2'b01;    // SUB for comparison
                branch    = 1'b1;
            end


            // ------------------------------------------------
            // JAL - Jump and Link
            // ------------------------------------------------
            7'b1101111: begin
                reg_write = 1'b1;
                result_src = 2'b10;   // PC + 4
                alu_src   = 1'b1;     // immediate
                alu_src_a = 2'b01;    // PC
                alu_op    = 2'b00;    // ADD
                jump      = 1'b1;
            end


            // ------------------------------------------------
            // JALR - Jump and Link Register
            // ------------------------------------------------
            7'b1100111: begin
                reg_write = 1'b1;
                result_src = 2'b10;   // PC + 4
                alu_src   = 1'b1;     // immediate
                alu_src_a = 2'b00;    // rs1
                alu_op    = 2'b00;    // ADD
                jump      = 1'b1;
                jalr      = 1'b1;
            end


            // ------------------------------------------------
            // LUI - Load Upper Immediate
            // ------------------------------------------------
            7'b0110111: begin
                reg_write = 1'b1;
                result_src = 2'b11;   // Immediate
                alu_src   = 1'b1;     // immediate
                alu_src_a = 2'b10;    // 0
                alu_op    = 2'b00;    // ADD
            end


            // ------------------------------------------------
            // AUIPC - Add Upper Immediate to PC
            // ------------------------------------------------
            7'b0010111: begin
                reg_write = 1'b1;
                result_src = 2'b00;   // ALU result
                alu_src   = 1'b1;     // immediate
                alu_src_a = 2'b01;    // PC
                alu_op    = 2'b00;    // ADD
            end


            // ------------------------------------------------
            // Unsupported instruction
            // ------------------------------------------------
            default: begin
                reg_write = 1'b0;
                mem_read  = 1'b0;
                mem_write = 1'b0;
                result_src = 2'b00;
                alu_src   = 1'b0;
                alu_src_a = 2'b00;
                alu_op    = 2'b00;
                branch    = 1'b0;
                jump      = 1'b0;
                jalr      = 1'b0;
            end

        endcase
    end

endmodule