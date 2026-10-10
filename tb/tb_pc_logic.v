`timescale 1ns/1ps

module tb_pc_logic;

    reg [31:0] pc;
    reg [31:0] rs1_data;
    reg [31:0] immediate;

    reg branch;
    reg zero;
    reg jump;
    reg jalr;

    wire [31:0] pc_plus_4;
    wire [31:0] branch_target;
    wire [31:0] jal_target;
    wire [31:0] jalr_target;
    wire [31:0] pc_next;

    pc_logic dut (
        .pc(pc),
        .rs1_data(rs1_data),
        .immediate(immediate),
        .branch(branch),
        .zero(zero),
        .jump(jump),
        .jalr(jalr),
        .pc_plus_4(pc_plus_4),
        .branch_target(branch_target),
        .jal_target(jal_target),
        .jalr_target(jalr_target),
        .pc_next(pc_next)
    );

    initial begin

        $monitor("Time=%0t | PC=%0d | rs1=%0d | imm=%0d | Branch=%b | Zero=%b | Jump=%b | JALR=%b | PC+4=%0d | BranchTarget=%0d | JALTarget=%0d | JALRTarget=%0d | PCNext=%0d",
                 $time,
                 pc,
                 rs1_data,
                 immediate,
                 branch,
                 zero,
                 jump,
                 jalr,
                 pc_plus_4,
                 branch_target,
                 jal_target,
                 jalr_target,
                 pc_next);

        // Initial values
        pc = 32'd100;
        rs1_data = 32'd200;
        immediate = 32'd8;
        branch = 1'b0;
        zero = 1'b0;
        jump = 1'b0;
        jalr = 1'b0;
        #10;

        // 1. Normal instruction -> PC + 4
        branch = 1'b0;
        jump = 1'b0;
        jalr = 1'b0;
        #10;

        // 2. Branch taken -> PC + immediate
        branch = 1'b1;
        zero = 1'b1;
        #10;

        // 3. Branch not taken -> PC + 4
        zero = 1'b0;
        #10;

        // 4. JAL -> PC + immediate
        branch = 1'b0;
        jump = 1'b1;
        jalr = 1'b0;
        #10;

        // 5. JALR -> rs1 + immediate
        jump = 1'b1;
        jalr = 1'b1;
        #10;

        // 6. JALR LSB clearing
        rs1_data = 32'd201;
        immediate = 32'd16;
        #10;

        $finish;
    end

endmodule
