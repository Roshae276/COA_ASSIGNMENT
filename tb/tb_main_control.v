`timescale 1ns/1ps

module tb_main_control;

    reg [31:0] instruction;

    wire       reg_write;
    wire       mem_read;
    wire       mem_write;
    wire [1:0] result_src;
    wire       alu_src;
    wire [1:0] alu_src_a;
    wire [1:0] alu_op;
    wire       branch;
    wire       jump;
    wire       jalr;

    main_control dut (
        .instruction(instruction),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .result_src(result_src),
        .alu_src(alu_src),
        .alu_src_a(alu_src_a),
        .alu_op(alu_op),
        .branch(branch),
        .jump(jump),
        .jalr(jalr)
    );

    initial begin

        $monitor(
            "Time=%0t | Instruction=%h | RegWrite=%b | MemRead=%b | MemWrite=%b | ResultSrc=%b | ALUSrc=%b | ALUSrcA=%b | ALUOp=%b | Branch=%b | Jump=%b | JALR=%b",
            $time,
            instruction,
            reg_write,
            mem_read,
            mem_write,
            result_src,
            alu_src,
            alu_src_a,
            alu_op,
            branch,
            jump,
            jalr
        );

        // ------------------------------------------------
        // 1. R-type ADD
        // ------------------------------------------------
        instruction = 32'h002081B3;
        #10;

        // ------------------------------------------------
        // 2. I-type ADDI
        // ------------------------------------------------
        instruction = 32'h00500093;
        #10;

        // ------------------------------------------------
        // 3. LW
        // ------------------------------------------------
        instruction = 32'h0080A183;
        #10;

        // ------------------------------------------------
        // 4. SW
        // ------------------------------------------------
        instruction = 32'h0030A423;
        #10;

        // ------------------------------------------------
        // 5. BEQ
        // ------------------------------------------------
        instruction = 32'h00208663;
        #10;

        // ------------------------------------------------
        // 6. JAL
        // ------------------------------------------------
        instruction = 32'h008000EF;
        #10;

        // ------------------------------------------------
        // 7. JALR
        // ------------------------------------------------
        instruction = 32'h010080E7;
        #10;

        // ------------------------------------------------
        // 8. LUI
        // ------------------------------------------------
        instruction = 32'h123450B7;
        #10;

        // ------------------------------------------------
        // 9. AUIPC
        // ------------------------------------------------
        instruction = 32'h12345097;
        #10;

        $finish;
    end

endmodule