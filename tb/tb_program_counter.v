`timescale 1ns/1ps

module tb_program_counter;

    reg clk;
    reg reset;
    reg [31:0] pc_next;

    wire [31:0] pc;

    program_counter dut (
        .clk(clk),
        .reset(reset),
        .pc_next(pc_next),
        .pc(pc)
    );

    always #5 clk = ~clk;

    initial begin
        $monitor("Time=%0t | reset=%b | pc_next=%0d | pc=%0d",
                 $time, reset, pc_next, pc);

        clk = 1'b0;
        reset = 1'b1;
        pc_next = 32'd0;

        #12;

        reset = 1'b0;

        pc_next = 32'd4;
        #10;

        pc_next = 32'd8;
        #10;

        pc_next = 32'd12;
        #10;

        pc_next = 32'd100;
        #10;

        $finish;

    end

endmodule