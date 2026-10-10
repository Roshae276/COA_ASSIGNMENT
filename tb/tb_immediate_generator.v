`timescale 1ns/1ps

module tb_immediate_generator;

    reg  [31:0] instruction;
    wire [31:0] immediate;

    // Intermediate signed signal
    wire signed [31:0] signed_immediate;

    assign signed_immediate = $signed(immediate);

    immediate_generator dut (
        .instruction(instruction),
        .immediate(immediate)
    );

    initial begin

        $monitor("Time=%0t | Instruction=%h | Opcode=%b | Immediate=%h | Signed=%0d",
                 $time,
                 instruction,
                 instruction[6:0],
                 immediate,
                 signed_immediate);

        // TEST 1: I-type positive
        // ADDI x1, x0, 5
        instruction = 32'h00500093;
        #10;

        // TEST 2: I-type negative
        // ADDI x1, x0, -5
        instruction = 32'hFFB00093;
        #10;

        // TEST 3: S-type
        // SW x5, 8(x2)
        instruction = 32'h00512423;
        #10;

        // TEST 4: U-type LUI
        // LUI x10, 0x87654
        instruction = 32'h87654537;
        #10;

        // TEST 5: U-type AUIPC
        // AUIPC x1, 0x12345
        instruction = 32'h12345097;
        #10;

        // TEST 6: I-type JALR
        // JALR x1, x2, 16
        instruction = 32'h010100E7;
        #10;

        // TEST 7: SB-type
        // BEQ x1, x2, 8
        instruction = 32'h00208463;
        #10;

        // TEST 8: UJ-type
        // JAL x1, 8
        instruction = 32'h008000EF;
        #10;

        // TEST 9: Unsupported opcode
        instruction = 32'h00000000;
        #10;

        $finish;
    end

endmodule