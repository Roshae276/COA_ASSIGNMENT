module data_memory (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);

    // 256 words, each 32 bits
    reg [31:0] memory [0:255];

    // Initial values for testing
    initial begin
        memory[0] = 32'd100;
        memory[1] = 32'd200;
        memory[2] = 32'd300;
        memory[3] = 32'd400;
    end

    // Combinational read
    assign read_data = mem_read ? memory[address[31:2]] : 32'd0;

    // Synchronous write
    always @(posedge clk) begin
        if (mem_write)
            memory[address[31:2]] <= write_data;
    end

endmodule
