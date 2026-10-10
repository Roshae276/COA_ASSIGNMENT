module riscv_cpu (
    input wire clk,
    input wire reset
);

    // ==========================================
    // PC Signals
    // ==========================================
    wire [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus_4;


    // ==========================================
    // Instruction
    // ==========================================
    wire [31:0] instruction;


    // ==========================================
    // Register File
    // ==========================================
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] write_back_data;


    // ==========================================
    // Immediate
    // ==========================================
    wire [31:0] immediate;


    // ==========================================
    // Control Signals
    // ==========================================
    wire       reg_write;
    wire       mem_read;
    wire       mem_write;
    wire [1:0] result_src;
    wire       alu_src;
    wire [1:0] alu_src_a;
    wire [1:0] alu_op;
    wire       branch;
    wire       jump;
    wire       jalr;


    // ==========================================
    // ALU Signals
    // ==========================================
    wire [3:0]  alu_control_signal;
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_result;
    wire        zero;


    // ==========================================
    // Data Memory
    // ==========================================
    wire [31:0] memory_data;


    // ==========================================
    // PC Logic
    // ==========================================
    wire [31:0] branch_target;
    wire [31:0] jal_target;
    wire [31:0] jalr_target;


    // ==========================================
    // 1. PROGRAM COUNTER
    // ==========================================

    program_counter pc_unit (
        .clk(clk),
        .reset(reset),
        .pc_next(pc_next),
        .pc(pc)
    );


    // ==========================================
    // 2. INSTRUCTION MEMORY
    // ==========================================

    instruction_memory imem (
        .address(pc),
        .instruction(instruction)
    );


    // ==========================================
    // 3. MAIN CONTROL UNIT
    // ==========================================

    main_control control_unit (
        .instruction(instruction),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .result_src(result_src),
        .alu_src(alu_src),
        .alu_src_a(alu_src_a),
        .alu_op(alu_op),
        .branch(branch),
        .jump(jump),
        .jalr(jalr)
    );


    // ==========================================
    // 4. REGISTER FILE
    // ==========================================

    register_file rf (
        .clk(clk),
        .reg_write(reg_write),
        .rs1(instruction[19:15]),
        .rs2(instruction[24:20]),
        .rd(instruction[11:7]),
        .write_data(write_back_data),
        .read_data1(rs1_data),
        .read_data2(rs2_data)
    );


    // ==========================================
    // 5. IMMEDIATE GENERATOR
    // ==========================================

    immediate_generator imm_gen (
        .instruction(instruction),
        .immediate(immediate)
    );


    // ==========================================
    // 6. ALU CONTROL
    // ==========================================

    alu_control alu_ctrl (
        .instruction(instruction),
        .alu_op(alu_op),
        .alu_control(alu_control_signal)
    );

        // ==========================================
    // 7. DATAPATH MUXES
    // ==========================================

    datapath_muxes muxes (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .pc(pc),
        .immediate(immediate),
        .alu_result(alu_result),
        .memory_data(memory_data),
        .pc_plus_4(pc_plus_4),

        .alu_src_a(alu_src_a),
        .alu_src(alu_src),
        .result_src(result_src),

        .alu_a(alu_a),
        .alu_b(alu_b),
        .write_back_data(write_back_data)
    );

     // ==========================================
    // 8. ALU
    // ==========================================

    alu alu_unit (
        .a(alu_a),
        .b(alu_b),
        .alu_control(alu_control_signal),
        .result(alu_result),
        .zero(zero)
    );


        // ==========================================
    // 9. DATA MEMORY
    // ==========================================

    data_memory data_mem (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .address(alu_result),
        .write_data(rs2_data),
        .read_data(memory_data)
    );

        // ==========================================
    // 10. PC LOGIC
    // ==========================================

    pc_logic pc_control (
        .pc(pc),
        .rs1_data(rs1_data),
        .immediate(immediate),

        .branch(branch),
        .zero(zero),
        .jump(jump),
        .jalr(jalr),

        .pc_plus_4(pc_plus_4),
        .branch_target(branch_target),
        .jal_target(jal_target),
        .jalr_target(jalr_target),
        .pc_next(pc_next)
    );


endmodule