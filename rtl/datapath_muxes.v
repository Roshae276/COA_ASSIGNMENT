module datapath_muxes (
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire [31:0] pc,
    input  wire [31:0] immediate,
    input  wire [31:0] alu_result,
    input  wire [31:0] memory_data,
    input  wire [31:0] pc_plus_4,

    input  wire [1:0] alu_src_a,
    input  wire       alu_src,
    input  wire [1:0] result_src,

    output reg [31:0] alu_a,
    output reg [31:0] alu_b,
    output reg [31:0] write_back_data
);

    // ALU input A MUX
    always @(*) begin
        case (alu_src_a)
            2'b00: alu_a = rs1_data;
            2'b01: alu_a = pc;
            2'b10: alu_a = 32'd0;
            default: alu_a = rs1_data;
        endcase
    end

    // ALU input B MUX
    always @(*) begin
        if (alu_src)
            alu_b = immediate;
        else
            alu_b = rs2_data;
    end

    // Write-back MUX
    always @(*) begin
        case (result_src)
            2'b00: write_back_data = alu_result;
            2'b01: write_back_data = memory_data;
            2'b10: write_back_data = pc_plus_4;
            2'b11: write_back_data = immediate;
            default: write_back_data = 32'd0;
        endcase
    end

endmodule
