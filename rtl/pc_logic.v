module pc_logic (
    input  wire [31:0] pc,
    input  wire [31:0] rs1_data,
    input  wire [31:0] immediate,

    input  wire branch,
    input  wire zero,
    input  wire jump,
    input  wire jalr,

    output wire [31:0] pc_plus_4,
    output wire [31:0] branch_target,
    output wire [31:0] jal_target,
    output wire [31:0] jalr_target,
    output reg  [31:0] pc_next
);

    assign pc_plus_4 = pc + 32'd4;

    // Used for PC-relative branch and JAL targets
    assign branch_target = pc + immediate;
    assign jal_target    = pc + immediate;

    // JALR target: rs1 + immediate, with bit 0 cleared
    assign jalr_target = (rs1_data + immediate) & 32'hFFFFFFFE;

    always @(*) begin
        if (jalr)
            pc_next = jalr_target;
        else if (jump)
            pc_next = jal_target;
        else if (branch && zero)
            pc_next = branch_target;
        else
            pc_next = pc_plus_4;
    end

endmodule
