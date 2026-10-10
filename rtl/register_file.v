module register_file (
    input  wire        clk,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] write_data,
    input  wire        reg_write,

    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);

    // 32 registers, each 32 bits wide
    reg [31:0] registers [0:31];

    integer i;

    // Initialize all registers to 0
    initial begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 32'd0;
    end

    // Read Port 1
    // x0 always returns 0
    assign read_data1 = (rs1 == 5'd0) ? 32'd0 : registers[rs1];

    // Read Port 2
    // x0 always returns 0
    assign read_data2 = (rs2 == 5'd0) ? 32'd0 : registers[rs2];

    // Write Port
    // Writing happens only at the rising edge of the clock
    // x0 cannot be written
    always @(posedge clk) begin
        if (reg_write && rd != 5'd0)
            registers[rd] <= write_data;
    end

endmodule