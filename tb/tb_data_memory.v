`timescale 1ns/1ps

module tb_data_memory;

    reg        clk;
    reg        mem_read;
    reg        mem_write;
    reg [31:0] address;
    reg [31:0] write_data;

    wire [31:0] read_data;

    data_memory dut (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .address(address),
        .write_data(write_data),
        .read_data(read_data)
    );

    // Clock: period = 10 ns
    always #5 clk = ~clk;

    initial begin

        $monitor("Time=%0t | clk=%b | MemRead=%b | MemWrite=%b | Address=%0d | WriteData=%0d | ReadData=%0d",
                 $time,
                 clk,
                 mem_read,
                 mem_write,
                 address,
                 write_data,
                 read_data);

        // Initial values
        clk = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        address = 32'd0;
        write_data = 32'd0;

        // TEST 1: Read address 0
        mem_read = 1'b1;
        address = 32'd0;
        #10;

        // TEST 2: Read address 4
        address = 32'd4;
        #10;

        // TEST 3: Read address 8
        address = 32'd8;
        #10;

        // TEST 4: Read address 12
        address = 32'd12;
        #10;

        // TEST 5: Write 999 to address 16
        mem_read = 1'b0;
        mem_write = 1'b1;
        address = 32'd16;
        write_data = 32'd999;
        #10;

        // TEST 6: Read back address 16
        mem_write = 1'b0;
        mem_read = 1'b1;
        address = 32'd16;
        #10;

        // TEST 7: Read disabled
        mem_read = 1'b0;
        address = 32'd16;
        #10;

        $finish;
    end

endmodule
