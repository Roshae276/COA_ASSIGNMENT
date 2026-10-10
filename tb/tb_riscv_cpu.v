`timescale 1ns/1ps

module tb_riscv_cpu;

    // ==========================================
    // Testbench signals
    // ==========================================

    reg clk;
    reg reset;


    // ==========================================
    // Instantiate CPU
    // ==========================================

    riscv_cpu dut (
        .clk(clk),
        .reset(reset)
    );


    // ==========================================
    // Clock Generation
    // ==========================================

    always #5 clk = ~clk;


    // ==========================================
    // Monitor CPU every time PC changes
    // ==========================================

    initial begin
        $monitor(
    "Time=%0t | PC=%0d | Instruction=%h | x1=%0d | x2=%0d | x3=%0d | x4=%0d | x5=%0d | x6=%0d | x7=%0d",
    $time,
    dut.pc,
    dut.instruction,
    dut.rf.registers[1],
    dut.rf.registers[2],
    dut.rf.registers[3],
    dut.rf.registers[4],
    dut.rf.registers[5],
    dut.rf.registers[6],
    dut.rf.registers[7]
);
    end


    // ==========================================
    // Test
    // ==========================================

    initial begin
    clk = 1'b0;
    reset = 1'b1;

    #12;
    reset = 1'b0;

    #130;

    $display("");
    $display("======================================");
    $display("       FINAL REGISTER VALUES");
    $display("======================================");

    $display("x0 = %0d", dut.rf.registers[0]);
    $display("x1 = %0d", dut.rf.registers[1]);
    $display("x2 = %0d", dut.rf.registers[2]);
    $display("x3 = %0d", dut.rf.registers[3]);
    $display("x4 = %0d", dut.rf.registers[4]);
    $display("x5 = %0d", dut.rf.registers[5]);
    $display("x6 = %0d", dut.rf.registers[6]);
    $display("x7 = %0d", dut.rf.registers[7]);

    $display("======================================");

    $finish;

end

endmodule