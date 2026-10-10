module alu_control (
    input  wire [31:0] instruction,
    input  wire [1:0]  alu_op,
    output reg  [3:0]  alu_control
);

    wire [2:0] funct3;
    wire [6:0] funct7;

    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    always @(*) begin

        // Safe default: ADD
        alu_control = 4'b0000;

        case (alu_op)

            // Address calculation / AUIPC
            2'b00: begin
                alu_control = 4'b0000; // ADD
            end

            // Branch comparison
            2'b01: begin
                alu_control = 4'b0001; // SUB
            end

            // R-type
            2'b10: begin
                case (funct3)

                    3'b000: begin
                        if (funct7 == 7'b0100000)
                            alu_control = 4'b0001; // SUB
                        else
                            alu_control = 4'b0000; // ADD
                    end

                    3'b001: alu_control = 4'b0110; // SLL
                    3'b010: alu_control = 4'b0101; // SLT
                    3'b011: alu_control = 4'b1001; // SLTU
                    3'b100: alu_control = 4'b0100; // XOR

                    3'b101: begin
                        if (funct7 == 7'b0100000)
                            alu_control = 4'b1000; // SRA
                        else
                            alu_control = 4'b0111; // SRL
                    end

                    3'b110: alu_control = 4'b0011; // OR
                    3'b111: alu_control = 4'b0010; // AND

                    default: alu_control = 4'b0000;
                endcase
            end

            // I-type arithmetic
            2'b11: begin
                case (funct3)

                    3'b000: alu_control = 4'b0000; // ADDI
                    3'b001: alu_control = 4'b0110; // SLLI
                    3'b010: alu_control = 4'b0101; // SLTI
                    3'b011: alu_control = 4'b1001; // SLTIU
                    3'b100: alu_control = 4'b0100; // XORI

                    3'b101: begin
                        if (funct7 == 7'b0100000)
                            alu_control = 4'b1000; // SRAI
                        else
                            alu_control = 4'b0111; // SRLI
                    end

                    3'b110: alu_control = 4'b0011; // ORI
                    3'b111: alu_control = 4'b0010; // ANDI

                    default: alu_control = 4'b0000;
                endcase
            end

            default: begin
                alu_control = 4'b0000;
            end

        endcase
    end

endmodule
