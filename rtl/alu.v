module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control,

    output reg  [31:0] result,
    output wire        zero
);

    always @(*) begin

        case (alu_control)

            // ADD
            4'b0000: begin
                result = a + b;
            end

            // SUB
            4'b0001: begin
                result = a - b;
            end

            // AND
            4'b0010: begin
                result = a & b;
            end

            // OR
            4'b0011: begin
                result = a | b;
            end

            // XOR
            4'b0100: begin
                result = a ^ b;
            end

            // SLT - Signed Less Than
            4'b0101: begin
                result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            end

            // SLL - Shift Left Logical
            4'b0110: begin
                result = a << b[4:0];
            end

            // SRL - Shift Right Logical
            4'b0111: begin
                result = a >> b[4:0];
            end

            // SRA - Shift Right Arithmetic
            4'b1000: begin
                result = $signed(a) >>> b[4:0];
            end

            // SLTU - Unsigned Less Than
            4'b1001: begin
                result = (a < b) ? 32'd1 : 32'd0;
            end

            // Default
            default: begin
                result = 32'd0;
            end

        endcase
    end

    // Zero flag
    assign zero = (result == 32'd0);

endmodule