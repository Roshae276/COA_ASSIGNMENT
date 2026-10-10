`timescale 1ns/1ps

module tb_datapath_muxes;

    reg [31:0] rs1_data;
    reg [31:0] rs2_data;
    reg [31:0] pc;
    reg [31:0] immediate;
    reg [31:0] alu_result;
    reg [31:0] memory_data;
    reg [31:0] pc_plus_4;

    reg [1:0] alu_src_a;
    reg       alu_src;
    reg [1:0] result_src;

    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] write_back_data;

    datapath_muxes dut (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .pc(pc),
        .immediate(immediate),
        .alu_result(alu_result),
        .memory_data(memory_data),
        .pc_plus_4(pc_plus_4),
        .alu_src_a(alu_src_a),
        .alu_src(alu_src),
        .result_src(result_src),
        .alu_a(alu_a),
        .alu_b(alu_b),
        .write_back_data(write_back_data)
    );

    initial begin

        $monitor("Time=%0t | ALUSrcA=%b | ALUSrc=%b | ResultSrc=%b | ALU_A=%0d | ALU_B=%0d | WB=%0d",
                 $time,
                 alu_src_a,
                 alu_src,
                 result_src,
                 alu_a,
                 alu_b,
                 write_back_data);

        rs1_data   = 32'd10;
        rs2_data   = 32'd20;
        pc         = 32'd100;
        immediate  = 32'd8;
        alu_result = 32'd30;
        memory_data = 32'd999;
        pc_plus_4  = 32'd104;

        // 1. R-type: A=rs1, B=rs2, WB=ALU
        alu_src_a = 2'b00;
        alu_src   = 1'b0;
        result_src = 2'b00;
        #10;

        // 2. I-type: A=rs1, B=imm, WB=ALU
        alu_src_a = 2'b00;
        alu_src   = 1'b1;
        result_src = 2'b00;
        #10;

        // 3. AUIPC: A=PC, B=imm, WB=ALU
        alu_src_a = 2'b01;
        alu_src   = 1'b1;
        result_src = 2'b00;
        #10;

        // 4. LUI-style: A=0, B=imm, WB=immediate
        alu_src_a = 2'b10;
        alu_src   = 1'b1;
        result_src = 2'b11;
        #10;

        // 5. LW write-back: memory data
        alu_src_a = 2'b00;
        alu_src   = 1'b1;
        result_src = 2'b01;
        #10;

        // 6. JAL/JALR write-back: PC+4
        alu_src_a = 2'b00;
        alu_src   = 1'b1;
        result_src = 2'b10;
        #10;

        $finish;
    end

endmodule
