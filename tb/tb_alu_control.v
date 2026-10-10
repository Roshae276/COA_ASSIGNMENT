`timescale 1ns/1ps

module tb_alu_control;

    reg  [31:0] instruction;
    reg  [1:0]  alu_op;

    wire [3:0] alu_control;

    alu_control dut (
        .instruction(instruction),
        .alu_op(alu_op),
        .alu_control(alu_control)
    );

    initial begin

        $monitor("Time=%0t | Instruction=%h | ALUOp=%b | funct7=%b | funct3=%b | ALUControl=%b",
                 $time,
                 instruction,
                 alu_op,
                 instruction[31:25],
                 instruction[14:12],
                 alu_control);

        // R-type ADD
        // ADD x3, x1, x2
        instruction = 32'h002081B3;
        alu_op = 2'b10;
        #10;

        // R-type SUB
        // SUB x3, x1, x2
        instruction = 32'h402081B3;
        alu_op = 2'b10;
        #10;

        // R-type AND
        // AND x3, x1, x2
        instruction = 32'h0020F1B3;
        alu_op = 2'b10;
        #10;

        // R-type OR
        // OR x3, x1, x2
        instruction = 32'h0020E1B3;
        alu_op = 2'b10;
        #10;

        // R-type XOR
        // XOR x3, x1, x2
        instruction = 32'h0020C1B3;
        alu_op = 2'b10;
        #10;

        // R-type SLT
        // SLT x3, x1, x2
        instruction = 32'h0020A1B3;
        alu_op = 2'b10;
        #10;

        // R-type SLTU
        // SLTU x3, x1, x2
        instruction = 32'h0020B1B3;
        alu_op = 2'b10;
        #10;

        // R-type SLL
        // SLL x3, x1, x2
        instruction = 32'h002091B3;
        alu_op = 2'b10;
        #10;

        // R-type SRL
        // SRL x3, x1, x2
        instruction = 32'h0020D1B3;
        alu_op = 2'b10;
        #10;

        // R-type SRA
        // SRA x3, x1, x2
        instruction = 32'h4020D1B3;
        alu_op = 2'b10;
        #10;

        // I-type ADDI
        // ADDI x1, x0, 5
        instruction = 32'h00500093;
        alu_op = 2'b11;
        #10;

        // I-type SLTI
        // SLTI x1, x0, 5
        instruction = 32'h00502093;
        alu_op = 2'b11;
        #10;

        // I-type SRLI
        // SRLI x1, x2, 2
        instruction = 32'h00215093;
        alu_op = 2'b11;
        #10;

        // I-type SRAI
        // SRAI x1, x2, 2
        instruction = 32'h40215093;
        alu_op = 2'b11;
        #10;

        // I-type ANDI
        // ANDI x1, x2, 3
        instruction = 32'h00317093;
        alu_op = 2'b11;
        #10;

        // Address calculation
        // LW
        instruction = 32'h00812283;
        alu_op = 2'b00;
        #10;

        // Address calculation
        // SW
        instruction = 32'h00512423;
        alu_op = 2'b00;
        #10;

        // Branch comparison
        // BEQ
        instruction = 32'h00208463;
        alu_op = 2'b01;
        #10;

        $finish;
    end

endmodule
