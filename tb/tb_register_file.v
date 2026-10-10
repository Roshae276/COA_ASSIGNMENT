`timescale 1ns/1ps

module tb_register_file;

    reg clk;
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;
    reg [31:0] write_data;
    reg reg_write;

    wire [31:0] read_data1;
    wire [31:0] read_data2;

    register_file dut (
        .clk(clk),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(write_data),
        .reg_write(reg_write),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // Clock: positive edges at 5ns, 15ns, 25ns, ...
    always #5 clk = ~clk;

    initial begin

        $monitor("Time=%0t | clk=%b | rs1=%0d | rs2=%0d | read1=%0d | read2=%0d | rd=%0d | write_data=%0d | reg_write=%b",
                 $time, clk, rs1, rs2, read_data1, read_data2,
                 rd, write_data, reg_write);

        // Initial values
        clk = 1'b0;
        rs1 = 5'd0;
        rs2 = 5'd0;
        rd = 5'd0;
        write_data = 32'd0;
        reg_write = 1'b0;

        // --------------------------------
        // TEST 1: Read x0
        // --------------------------------
        #2;
        rs1 = 5'd0;
        rs2 = 5'd0;

        // --------------------------------
        // TEST 2: Write 10 into x1
        // --------------------------------
        #3;                  // Time = 5ns
        rd = 5'd1;
        write_data = 32'd10;
        reg_write = 1'b1;

        #10;                 // Keep write enabled through next posedge
        reg_write = 1'b0;

        // --------------------------------
        // TEST 3: Read x1
        // --------------------------------
        rs1 = 5'd1;
        rs2 = 5'd1;

        #5;

        // --------------------------------
        // TEST 4: Write 20 into x2
        // --------------------------------
        rd = 5'd2;
        write_data = 32'd20;
        reg_write = 1'b1;

        #10;
        reg_write = 1'b0;

        // --------------------------------
        // TEST 5: Read x1 and x2 together
        // --------------------------------
        rs1 = 5'd1;
        rs2 = 5'd2;

        #5;

        // --------------------------------
        // TEST 6: Try writing 99 into x0
        // --------------------------------
        rd = 5'd0;
        write_data = 32'd99;
        reg_write = 1'b1;

        #10;
        reg_write = 1'b0;

        // --------------------------------
        // TEST 7: Check x0
        // --------------------------------
        rs1 = 5'd0;
        rs2 = 5'd0;

        #10;

        $finish;

    end

endmodule