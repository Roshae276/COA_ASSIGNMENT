# Single-Cycle RISC-V RV32I Processor in Verilog

## Step-by-step implementation guide --- from individual hardware blocks to the complete CPU

> **Goal:** Build a single-cycle RV32I processor in Verilog by
> understanding and implementing every hardware block separately first,
> testing each block, and only then integrating them into one top-level
> CPU.
>
> **Important:** This guide follows the RV32I concepts and instruction
> formats covered in the provided lecture notes. The implementation
> covers the instruction classes discussed there: R-type ALU
> instructions, I-type arithmetic, loads, S-type stores, SB-type
> branches, U-type LUI/AUIPC, UJ-type JAL, and JALR. It does **not**
> attempt to implement privileged instructions, CSRs, exceptions/traps,
> interrupts, or other extensions not covered in the notes.

------------------------------------------------------------------------

# 0. First understand the complete CPU

A single-cycle processor completes one instruction in one clock cycle.

The high-level data path is:

``` text
                         +----------------+
                         | Program Counter|
                         |      (PC)      |
                         +-------+--------+
                                 |
                                 | instruction address
                                 v
                         +----------------+
                         | Instruction    |
                         | Memory         |
                         +-------+--------+
                                 |
                                 | 32-bit instruction
                                 v
                     +-----------------------+
                     | Instruction Decode    |
                     | opcode/funct3/funct7 |
                     +-----------+-----------+
                                 |
              +------------------+------------------+
              |                                     |
              v                                     v
      +---------------+                     +----------------+
      | Register File |                     | Immediate Gen. |
      +-------+-------+                     +-------+--------+
              |                                     |
        rs1   |   rs2                              imm
              |                                     |
              +----------------+--------------------+
                               |
                               v
                         +-----------+
                         |    ALU    |
                         +-----+-----+
                               |
                    +----------+----------+
                    |                     |
                    v                     v
              +-----------+         +-----------+
              | Data      |         | Branch /  |
              | Memory    |         | Jump PC   |
              +-----+-----+         | Logic     |
                    |               +-----+-----+
                    |                     |
                    v                     |
              +-----------+               |
              | Writeback |<--------------+
              |   MUX     |
              +-----+-----+
                    |
                    v
              Register File

                         PC_next
                            |
                            v
                       Program Counter
```

The major implementation order is:

1.  Program Counter
2.  Instruction Memory
3.  Register File
4.  ALU
5.  Immediate Generator
6.  Main Control Unit
7.  ALU Control Unit
8.  Data Memory
9.  Branch / Jump / Next-PC logic
10. Writeback MUX logic
11. Top-level `riscv_cpu.v`
12. Final testbench and simulation
13. Debugging checklist

The lecture notes state that RV32I has 32 registers of 32 bits, `x0` is
hardwired to zero, the PC holds the address of the current instruction,
and RV32I instructions are 32 bits and aligned on four-byte boundaries.
The notes also describe R/I/S/SB/U/UJ formats and the use of opcode,
funct3 and funct7 for decoding.

------------------------------------------------------------------------

# 1. Program Counter

## 1.1 What is the PC?

The Program Counter is a 32-bit register containing the address of the
**current instruction**.

For a normal sequential instruction:

``` text
PC_next = PC + 4
```

because each RV32I instruction is 32 bits = 4 bytes.

For a branch or jump:

``` text
PC_next = branch/jump target
```

At the active clock edge:

``` text
PC <= PC_next
```

The notes define the PC as holding the address of the current
instruction.

## 1.2 Inputs and outputs

``` text
Inputs:
    clk
    reset
    pc_next

Output:
    pc
```

The PC itself should only store a value. The logic that decides the next
PC belongs outside this module.

## 1.3 Verilog

``` verilog
module program_counter (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);

always @(posedge clk) begin
    if (reset)
        pc <= 32'b0;
    else
        pc <= pc_next;
end

endmodule
```

## 1.4 Line-by-line explanation

``` verilog
module program_counter (
```

Creates a hardware module named `program_counter`.

``` verilog
input wire clk
```

Clock input.

``` verilog
input wire reset
```

Reset input.

``` verilog
input wire [31:0] pc_next
```

32-bit address that will become the new PC.

``` verilog
output reg [31:0] pc
```

PC is stored in a register, so it is declared `reg` in Verilog.

``` verilog
always @(posedge clk)
```

This is sequential logic. The PC changes only on the rising edge of the
clock.

``` verilog
if (reset)
    pc <= 32'b0;
```

When reset is active, PC becomes address 0.

``` verilog
else
    pc <= pc_next;
```

Otherwise, load the calculated next address.

`<=` is non-blocking assignment and is the correct style for clocked
registers.

------------------------------------------------------------------------

# 2. Instruction Memory

## 2.1 Why do we need it?

The PC gives an instruction address.

Instruction memory uses that address to return the corresponding 32-bit
instruction.

Example:

``` text
PC = 0   -> instruction at address 0
PC = 4   -> instruction at address 4
PC = 8   -> instruction at address 8
PC = 12  -> instruction at address 12
```

RV32I instructions are 32 bits and aligned to four-byte boundaries.

## 2.2 Important address conversion

If we store instructions as 32-bit words:

``` text
word 0 -> address 0
word 1 -> address 4
word 2 -> address 8
word 3 -> address 12
```

Therefore:

``` verilog
instruction = memory[pc[9:2]];
```

The bottom two address bits are removed because every instruction starts
on a 4-byte boundary.

This is a simplified word-array model of instruction memory. The
architecture itself has a byte-addressable memory space.

## 2.3 Verilog

``` verilog
module instruction_memory (
    input  wire [31:0] address,
    output wire [31:0] instruction
);

reg [31:0] memory [0:255];

assign instruction = memory[address[9:2]];

initial begin
    $readmemh("program.hex", memory);
end

endmodule
```

## 2.4 Explanation

``` verilog
reg [31:0] memory [0:255];
```

Creates 256 memory locations, each 32 bits wide.

Total modeled instruction memory:

``` text
256 x 32 bits = 8192 bits = 1024 bytes
```

``` verilog
assign instruction = memory[address[9:2]];
```

The instruction is read combinationally.

``` verilog
$readmemh("program.hex", memory);
```

Loads machine-code instructions from a hexadecimal file.

Example `program.hex`:

``` text
00500093
00A00113
002081B3
10302023
10002203
00418463
00100293
00200293
```

Each line represents one 32-bit instruction.

------------------------------------------------------------------------

# 3. Register File

## 3.1 Architecture

RV32I has:

``` text
32 registers
x0 through x31
each register = 32 bits
```

Special rule:

``` text
x0 = 0 always
```

Writing to x0 must have no effect.

The register file normally has:

``` text
2 read ports
1 write port
```

That is useful because R-type instructions need two source registers and
one destination register.

## 3.2 Interface

``` text
Inputs:
    clk
    reset
    rs1 address
    rs2 address
    rd address
    write data
    RegWrite

Outputs:
    rs1 data
    rs2 data
```

## 3.3 Verilog

``` verilog
module register_file (
    input  wire        clk,
    input  wire        reset,

    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,

    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    input  wire        reg_write,

    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);

reg [31:0] registers [0:31];

integer i;

always @(posedge clk) begin
    if (reset) begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] <= 32'b0;
    end
    else if (reg_write && (rd_addr != 5'b00000)) begin
        registers[rd_addr] <= rd_data;
    end
end

assign rs1_data = (rs1_addr == 5'b00000) ?
                  32'b0 : registers[rs1_addr];

assign rs2_data = (rs2_addr == 5'b00000) ?
                  32'b0 : registers[rs2_addr];

endmodule
```

## 3.4 Complete explanation

The register number needs 5 bits because:

``` text
2^5 = 32
```

Therefore:

``` verilog
input wire [4:0] rs1_addr;
```

can select x0 through x31.

The same applies to `rs2` and `rd`.

The write operation is clocked:

``` verilog
always @(posedge clk)
```

because registers store state.

The condition:

``` verilog
rd_addr != 5'b00000
```

prevents writing to x0.

The read operations are combinational:

``` verilog
assign rs1_data = ...
assign rs2_data = ...
```

So after the register number is supplied, the corresponding register
value is available without waiting for a clock edge.

------------------------------------------------------------------------

# 4. ALU

## 4.1 Why is the ALU needed?

The Arithmetic Logic Unit performs operations such as:

``` text
ADD
SUB
AND
OR
XOR
SLL
SRL
SRA
SLT
SLTU
```

These are required by the R-type and I-type arithmetic instructions.

The ALU also calculates effective addresses for loads/stores:

``` text
address = rs1 + immediate
```

and AUIPC can use:

``` text
PC + immediate
```

## 4.2 ALU control encoding

We will use:

``` text
0000 ADD
0001 SUB
0010 AND
0011 OR
0100 XOR
0101 SLL
0110 SRL
0111 SRA
1000 SLT
1001 SLTU
```

## 4.3 Verilog

``` verilog
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control,

    output reg  [31:0] result,
    output wire        zero
);

always @(*) begin
    case (alu_control)

        4'b0000: result = a + b;                         // ADD
        4'b0001: result = a - b;                         // SUB
        4'b0010: result = a & b;                         // AND
        4'b0011: result = a | b;                         // OR
        4'b0100: result = a ^ b;                         // XOR
        4'b0101: result = a << b[4:0];                  // SLL
        4'b0110: result = a >> b[4:0];                  // SRL
        4'b0111: result = $signed(a) >>> b[4:0];        // SRA
        4'b1000: result = ($signed(a) < $signed(b)) ?
                          32'b1 : 32'b0;                // SLT
        4'b1001: result = (a < b) ?
                          32'b1 : 32'b0;                // SLTU

        default: result = 32'b0;

    endcase
end

assign zero = (result == 32'b0);

endmodule
```

## 4.4 Important distinction

``` verilog
a >> b[4:0]
```

is logical right shift because `a` is unsigned here.

``` verilog
$signed(a) >>> b[4:0]
```

is arithmetic right shift because `a` is treated as signed.

For signed comparison:

``` verilog
$signed(a) < $signed(b)
```

For unsigned comparison:

``` verilog
a < b
```

------------------------------------------------------------------------

# 5. Immediate Generator

## 5.1 Why is it needed?

An instruction is only 32 bits.

The immediate is stored inside different instruction bit positions
depending on the format.

We must extract those bits and create a 32-bit immediate.

The important formats are:

``` text
I
S
SB
U
UJ
```

R-type has no immediate.

## 5.2 Immediate formats

### I-type

``` text
imm = instruction[31:20]
```

Sign extend to 32 bits.

### S-type

``` text
imm = {instruction[31:25], instruction[11:7]}
```

Sign extend.

### SB-type

``` text
imm =
{instruction[31],
 instruction[7],
 instruction[30:25],
 instruction[11:8],
 1'b0}
```

Then sign extend.

### U-type

``` text
imm = {instruction[31:12], 12'b0}
```

### UJ-type

``` text
imm =
{instruction[31],
 instruction[19:12],
 instruction[20],
 instruction[30:21],
 1'b0}
```

Then sign extend.

## 5.3 Verilog

``` verilog
module immediate_generator (
    input  wire [31:0] instruction,
    input  wire [2:0]  imm_sel,
    output reg  [31:0] immediate
);

localparam IMM_I = 3'b000;
localparam IMM_S = 3'b001;
localparam IMM_B = 3'b010;
localparam IMM_U = 3'b011;
localparam IMM_J = 3'b100;

always @(*) begin

    case (imm_sel)

        IMM_I:
            immediate = {{20{instruction[31]}},
                         instruction[31:20]};

        IMM_S:
            immediate = {{20{instruction[31]}},
                         instruction[31:25],
                         instruction[11:7]};

        IMM_B:
            immediate = {{19{instruction[31]}},
                         instruction[31],
                         instruction[7],
                         instruction[30:25],
                         instruction[11:8],
                         1'b0};

        IMM_U:
            immediate = {instruction[31:12], 12'b0};

        IMM_J:
            immediate = {{11{instruction[31]}},
                         instruction[31],
                         instruction[19:12],
                         instruction[20],
                         instruction[30:21],
                         1'b0};

        default:
            immediate = 32'b0;

    endcase
end

endmodule
```

## 5.4 Why sign extension?

Suppose:

``` text
12-bit immediate = 111111111111
```

This represents `-1` in two's complement.

After sign extension:

``` text
11111111111111111111111111111111
```

which is 32-bit `-1`.

That is why we repeat the sign bit.

------------------------------------------------------------------------

# 6. Main Control Unit

## 6.1 Why do we need control?

The instruction itself tells us what operation should happen, but
hardware blocks need control signals.

For example, for:

``` text
LW x5, 0(x1)
```

we need:

``` text
ALUSrc = 1
MemRead = 1
MemtoReg = 1
RegWrite = 1
```

For:

``` text
SW x5, 0(x1)
```

we need:

``` text
ALUSrc = 1
MemWrite = 1
```

The main control decodes the opcode and generates these signals.

## 6.2 Control signals used

``` text
RegWrite       write result into register file
MemRead        read data memory
MemWrite       write data memory
Branch         instruction is a conditional branch
Jump           JAL
Jalr           JALR
ALUSrc         ALU B input = immediate instead of rs2
ALUSrcA_PC     ALU A input = PC instead of rs1
ALUOp          tells ALU control what instruction class it is
WBSelect       chooses value written to rd
ImmSel         selects immediate format
```

## 6.3 Verilog

``` verilog
module main_control (
    input  wire [6:0] opcode,

    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        branch,
    output reg        jump,
    output reg        jalr,

    output reg        alu_src,
    output reg        alu_src_a_pc,

    output reg [1:0]  alu_op,
    output reg [1:0]  wb_select,
    output reg [2:0]  imm_sel
);

localparam ALU_ADD = 2'b00;
localparam ALU_BRANCH = 2'b01;
localparam ALU_R = 2'b10;
localparam ALU_I = 2'b11;

localparam WB_ALU = 2'b00;
localparam WB_MEM = 2'b01;
localparam WB_PC4 = 2'b10;
localparam WB_IMM = 2'b11;

localparam IMM_I = 3'b000;
localparam IMM_S = 3'b001;
localparam IMM_B = 3'b010;
localparam IMM_U = 3'b011;
localparam IMM_J = 3'b100;

always @(*) begin

    reg_write   = 1'b0;
    mem_read    = 1'b0;
    mem_write   = 1'b0;
    branch      = 1'b0;
    jump        = 1'b0;
    jalr        = 1'b0;

    alu_src     = 1'b0;
    alu_src_a_pc = 1'b0;

    alu_op      = ALU_ADD;
    wb_select   = WB_ALU;
    imm_sel     = IMM_I;

    case (opcode)

        // R-type
        7'b0110011: begin
            reg_write = 1'b1;
            alu_src   = 1'b0;
            alu_op    = ALU_R;
            wb_select = WB_ALU;
        end

        // I-type arithmetic
        7'b0010011: begin
            reg_write = 1'b1;
            alu_src   = 1'b1;
            alu_op    = ALU_I;
            wb_select = WB_ALU;
            imm_sel   = IMM_I;
        end

        // Loads
        7'b0000011: begin
            reg_write = 1'b1;
            mem_read  = 1'b1;
            alu_src   = 1'b1;
            alu_op    = ALU_ADD;
            wb_select = WB_MEM;
            imm_sel   = IMM_I;
        end

        // Stores
        7'b0100011: begin
            mem_write = 1'b1;
            alu_src   = 1'b1;
            alu_op    = ALU_ADD;
            imm_sel   = IMM_S;
        end

        // Branches
        7'b1100011: begin
            branch    = 1'b1;
            alu_op    = ALU_BRANCH;
            imm_sel   = IMM_B;
        end

        // LUI
        7'b0110111: begin
            reg_write = 1'b1;
            wb_select = WB_IMM;
            imm_sel   = IMM_U;
        end

        // AUIPC
        7'b0010111: begin
            reg_write    = 1'b1;
            alu_src      = 1'b1;
            alu_src_a_pc = 1'b1;
            alu_op       = ALU_ADD;
            wb_select    = WB_ALU;
            imm_sel      = IMM_U;
        end

        // JAL
        7'b1101111: begin
            reg_write = 1'b1;
            jump      = 1'b1;
            wb_select = WB_PC4;
            imm_sel   = IMM_J;
        end

        // JALR
        7'b1100111: begin
            reg_write = 1'b1;
            jalr      = 1'b1;
            alu_src   = 1'b1;
            wb_select = WB_PC4;
            imm_sel   = IMM_I;
        end

        default: begin
            // Keep all default control values.
        end

    endcase
end

endmodule
```

------------------------------------------------------------------------

# 7. ALU Control Unit

## 7.1 Why a second control unit?

The main control looks mainly at the opcode.

But opcode alone cannot distinguish:

``` text
ADD
SUB
AND
OR
XOR
SLL
SRL
SRA
SLT
SLTU
```

For R-type instructions, `funct3` and `funct7` are also needed.

For I-type arithmetic, `funct3` and sometimes `funct7` are needed.

Therefore:

``` text
Main Control
    |
    | ALUOp
    v
ALU Control
    |
    | funct3 + funct7
    v
ALU operation
```

## 7.2 Verilog

``` verilog
module alu_control (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg [3:0] alu_control
);

always @(*) begin

    case (alu_op)

        // Load/store/AUIPC
        2'b00:
            alu_control = 4'b0000; // ADD

        // Branch comparison
        2'b01:
            alu_control = 4'b0001; // SUB

        // R-type
        2'b10: begin
            case (funct3)

                3'b000:
                    if (funct7 == 7'b0100000)
                        alu_control = 4'b0001; // SUB
                    else
                        alu_control = 4'b0000; // ADD

                3'b001: alu_control = 4'b0101; // SLL
                3'b010: alu_control = 4'b1000; // SLT
                3'b011: alu_control = 4'b1001; // SLTU
                3'b100: alu_control = 4'b0100; // XOR

                3'b101:
                    if (funct7 == 7'b0100000)
                        alu_control = 4'b0111; // SRA
                    else
                        alu_control = 4'b0110; // SRL

                3'b110: alu_control = 4'b0011; // OR
                3'b111: alu_control = 4'b0010; // AND

                default: alu_control = 4'b0000;

            endcase
        end

        // I-type arithmetic
        2'b11: begin
            case (funct3)

                3'b000: alu_control = 4'b0000; // ADDI
                3'b001: alu_control = 4'b0101; // SLLI
                3'b010: alu_control = 4'b1000; // SLTI
                3'b011: alu_control = 4'b1001; // SLTIU
                3'b100: alu_control = 4'b0100; // XORI

                3'b101:
                    if (funct7 == 7'b0100000)
                        alu_control = 4'b0111; // SRAI
                    else
                        alu_control = 4'b0110; // SRLI

                3'b110: alu_control = 4'b0011; // ORI
                3'b111: alu_control = 4'b0010; // ANDI

                default: alu_control = 4'b0000;

            endcase
        end

        default:
            alu_control = 4'b0000;

    endcase
end

endmodule
```

## 7.3 Example

For:

``` text
SUB x3, x1, x2
```

the fields are:

``` text
opcode = 0110011
funct3 = 000
funct7 = 0100000
```

Main control produces:

``` text
ALUOp = 10
```

ALU control sees:

``` text
ALUOp = 10
funct3 = 000
funct7 = 0100000
```

and generates:

``` text
ALUControl = 0001
```

which means SUB.

------------------------------------------------------------------------

# 8. Data Memory

## 8.1 Why data memory is separate?

RISC-V is a load-store architecture.

Arithmetic instructions operate on registers.

Only load/store instructions access data memory.

Examples:

``` text
LW x5, 0(x1)
SW x5, 4(x1)
LB x5, 0(x1)
LH x5, 0(x1)
LBU x5, 0(x1)
LHU x5, 0(x1)
SB x5, 0(x1)
SH x5, 0(x1)
```

The lecture notes describe byte-addressable memory and little-endian
organization.

## 8.2 Why use byte memory?

A byte-addressable memory lets us correctly model:

``` text
LB
LH
LW
LBU
LHU
SB
SH
SW
```

## 8.3 Verilog

``` verilog
module data_memory (
    input  wire        clk,

    input  wire        mem_read,
    input  wire        mem_write,

    input  wire [2:0]  funct3,

    input  wire [31:0] address,
    input  wire [31:0] write_data,

    output reg  [31:0] read_data
);

reg [7:0] memory [0:4095];

always @(*) begin

    read_data = 32'b0;

    if (mem_read) begin

        case (funct3)

            // LB
            3'b000:
                read_data = {{24{memory[address[11:0]][7]}},
                             memory[address[11:0]]};

            // LH
            3'b001:
                read_data = {{16{memory[address[11:0] + 1][7]}},
                             memory[address[11:0] + 1],
                             memory[address[11:0]]};

            // LW
            3'b010:
                read_data = {
                    memory[address[11:0] + 3],
                    memory[address[11:0] + 2],
                    memory[address[11:0] + 1],
                    memory[address[11:0]]
                };

            // LBU
            3'b100:
                read_data = {
                    24'b0,
                    memory[address[11:0]]
                };

            // LHU
            3'b101:
                read_data = {
                    16'b0,
                    memory[address[11:0] + 1],
                    memory[address[11:0]]
                };

            default:
                read_data = 32'b0;

        endcase
    end
end

always @(posedge clk) begin

    if (mem_write) begin

        case (funct3)

            // SB
            3'b000: begin
                memory[address[11:0]] <= write_data[7:0];
            end

            // SH
            3'b001: begin
                memory[address[11:0]]     <= write_data[7:0];
                memory[address[11:0] + 1] <= write_data[15:8];
            end

            // SW
            3'b010: begin
                memory[address[11:0]]     <= write_data[7:0];
                memory[address[11:0] + 1] <= write_data[15:8];
                memory[address[11:0] + 2] <= write_data[23:16];
                memory[address[11:0] + 3] <= write_data[31:24];
            end

            default: begin
            end

        endcase
    end
end

endmodule
```

## 8.4 Little-endian example

Suppose:

``` text
SW x5, 0(x1)
```

and:

``` text
x5 = 0x12345678
address = 0x100
```

Little-endian memory becomes:

``` text
Address       Data
0x100         78
0x101         56
0x102         34
0x103         12
```

When LW reads address `0x100`:

``` text
{12,34,56,78}
= 0x12345678
```

------------------------------------------------------------------------

# 9. Branch Unit

## 9.1 Why do we need it?

A branch instruction does not always change the PC.

Example:

``` text
BEQ x1, x2, offset
```

If:

``` text
x1 == x2
```

then branch is taken.

Otherwise:

``` text
PC_next = PC + 4
```

The lecture notes list:

``` text
BEQ
BNE
BLT
BGE
BLTU
BGEU
```

## 9.2 Verilog

``` verilog
module branch_unit (
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire [2:0]  funct3,

    output reg         taken
);

always @(*) begin

    case (funct3)

        3'b000: taken = (rs1_data == rs2_data);                 // BEQ
        3'b001: taken = (rs1_data != rs2_data);                 // BNE
        3'b100: taken = ($signed(rs1_data) < $signed(rs2_data)); // BLT
        3'b101: taken = ($signed(rs1_data) >= $signed(rs2_data)); // BGE
        3'b110: taken = (rs1_data < rs2_data);                  // BLTU
        3'b111: taken = (rs1_data >= rs2_data);                 // BGEU

        default: taken = 1'b0;

    endcase
end

endmodule
```

------------------------------------------------------------------------

# 10. Next-PC / Branch / Jump Logic

## 10.1 Normal instruction

``` text
PC_next = PC + 4
```

## 10.2 Taken branch

``` text
PC_next = PC + branch_immediate
```

The branch immediate already contains the low zero bit.

## 10.3 JAL

``` text
PC_next = PC + J_immediate
```

JAL also writes:

``` text
PC + 4
```

to `rd`.

## 10.4 JALR

``` text
target = rs1 + I_immediate
target[0] = 0
```

Then:

``` text
PC_next = target
```

JALR also writes:

``` text
PC + 4
```

to `rd`.

## 10.5 Verilog module

``` verilog
module next_pc_logic (
    input  wire [31:0] pc,
    input  wire [31:0] rs1_data,

    input  wire [31:0] branch_imm,
    input  wire [31:0] jump_imm,
    input  wire [31:0] jalr_imm,

    input  wire        branch,
    input  wire        branch_taken,
    input  wire        jump,
    input  wire        jalr,

    output reg  [31:0] pc_next
);

always @(*) begin

    pc_next = pc + 32'd4;

    if (branch && branch_taken)
        pc_next = pc + branch_imm;

    if (jump)
        pc_next = pc + jump_imm;

    if (jalr)
        pc_next = (rs1_data + jalr_imm) & 32'hFFFFFFFE;

end

endmodule
```

Because JAL and JALR have different opcodes, only one of them should be
active for a valid instruction.

------------------------------------------------------------------------

# 11. Writeback Logic

## 11.1 What is writeback?

After execution, the CPU needs to decide what value goes into `rd`.

Possible values in this design:

``` text
ALU result
Data memory result
PC + 4
Immediate
```

Examples:

### ADD

``` text
rd = ALU result
```

### LW

``` text
rd = memory result
```

### JAL/JALR

``` text
rd = PC + 4
```

### LUI

``` text
rd = immediate
```

## 11.2 Verilog

The top-level CPU can implement this as a simple combinational block:

``` verilog
always @(*) begin

    case (wb_select)

        2'b00: writeback_data = alu_result;
        2'b01: writeback_data = memory_data;
        2'b10: writeback_data = pc + 32'd4;
        2'b11: writeback_data = immediate;

        default: writeback_data = 32'b0;

    endcase

end
```

------------------------------------------------------------------------

# 12. Top-Level `riscv_cpu.v`

Now all components are connected.

This is the most important stage.

Do not start with this file. Build and test the modules individually
first.

## 12.1 Complete top-level code

``` verilog
module riscv_cpu (
    input wire clk,
    input wire reset
);

    // =========================================================
    // 1. PC
    // =========================================================

    wire [31:0] pc;
    reg  [31:0] pc_next;

    program_counter pc_unit (
        .clk(clk),
        .reset(reset),
        .pc_next(pc_next),
        .pc(pc)
    );

    // =========================================================
    // 2. Instruction Memory
    // =========================================================

    wire [31:0] instruction;

    instruction_memory imem (
        .address(pc),
        .instruction(instruction)
    );

    // =========================================================
    // 3. Instruction fields
    // =========================================================

    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rd     = instruction[11:7];
    wire [2:0] funct3 = instruction[14:12];
    wire [4:0] rs1    = instruction[19:15];
    wire [4:0] rs2    = instruction[24:20];
    wire [6:0] funct7 = instruction[31:25];

    // =========================================================
    // 4. Main Control
    // =========================================================

    wire       reg_write;
    wire       mem_read;
    wire       mem_write;
    wire       branch;
    wire       jump;
    wire       jalr;

    wire       alu_src;
    wire       alu_src_a_pc;

    wire [1:0] alu_op;
    wire [1:0] wb_select;
    wire [2:0] imm_sel;

    main_control control_unit (
        .opcode(opcode),

        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),

        .alu_src(alu_src),
        .alu_src_a_pc(alu_src_a_pc),

        .alu_op(alu_op),
        .wb_select(wb_select),
        .imm_sel(imm_sel)
    );

    // =========================================================
    // 5. Register File
    // =========================================================

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    wire [31:0] writeback_data;

    register_file registers (
        .clk(clk),
        .reset(reset),

        .rs1_addr(rs1),
        .rs2_addr(rs2),

        .rd_addr(rd),
        .rd_data(writeback_data),
        .reg_write(reg_write),

        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // =========================================================
    // 6. Immediate Generator
    // =========================================================

    wire [31:0] immediate;

    immediate_generator imm_gen (
        .instruction(instruction),
        .imm_sel(imm_sel),
        .immediate(immediate)
    );

    // =========================================================
    // 7. ALU Control
    // =========================================================

    wire [3:0] alu_control_signal;

    alu_control alu_ctrl (
        .alu_op(alu_op),
        .funct3(funct3),
        .funct7(funct7),
        .alu_control(alu_control_signal)
    );

    // =========================================================
    // 8. ALU input selection
    // =========================================================

    wire [31:0] alu_a;
    wire [31:0] alu_b;

    assign alu_a = alu_src_a_pc ? pc : rs1_data;
    assign alu_b = alu_src ? immediate : rs2_data;

    // =========================================================
    // 9. ALU
    // =========================================================

    wire [31:0] alu_result;
    wire        alu_zero;

    alu alu_unit (
        .a(alu_a),
        .b(alu_b),
        .alu_control(alu_control_signal),

        .result(alu_result),
        .zero(alu_zero)
    );

    // =========================================================
    // 10. Data Memory
    // =========================================================

    wire [31:0] memory_data;

    data_memory dmem (
        .clk(clk),

        .mem_read(mem_read),
        .mem_write(mem_write),

        .funct3(funct3),

        .address(alu_result),
        .write_data(rs2_data),

        .read_data(memory_data)
    );

    // =========================================================
    // 11. Branch Unit
    // =========================================================

    wire branch_taken;

    branch_unit branch_unit_inst (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .funct3(funct3),
        .taken(branch_taken)
    );

    // =========================================================
    // 12. Next PC
    // =========================================================

    wire [31:0] branch_immediate;
    wire [31:0] jump_immediate;
    wire [31:0] jalr_immediate;

    immediate_generator branch_imm_gen (
        .instruction(instruction),
        .imm_sel(3'b010),
        .immediate(branch_immediate)
    );

    immediate_generator jump_imm_gen (
        .instruction(instruction),
        .imm_sel(3'b100),
        .immediate(jump_immediate)
    );

    immediate_generator jalr_imm_gen (
        .instruction(instruction),
        .imm_sel(3'b000),
        .immediate(jalr_immediate)
    );

    always @(*) begin

        pc_next = pc + 32'd4;

        if (branch && branch_taken)
            pc_next = pc + branch_immediate;

        if (jump)
            pc_next = pc + jump_immediate;

        if (jalr)
            pc_next = (rs1_data + jalr_immediate)
                      & 32'hFFFFFFFE;

    end

    // =========================================================
    // 13. Writeback MUX
    // =========================================================

    reg [31:0] writeback_data_reg;

    assign writeback_data = writeback_data_reg;

    always @(*) begin

        case (wb_select)

            2'b00:
                writeback_data_reg = alu_result;

            2'b01:
                writeback_data_reg = memory_data;

            2'b10:
                writeback_data_reg = pc + 32'd4;

            2'b11:
                writeback_data_reg = immediate;

            default:
                writeback_data_reg = 32'b0;

        endcase

    end

endmodule
```

------------------------------------------------------------------------

# 13. Important Verilog issue in the top-level

Some Verilog tools do not accept declarations with assignments such as:

``` verilog
wire [6:0] opcode = instruction[6:0];
```

if you want maximum compatibility with older Verilog tools.

You can instead write:

``` verilog
wire [6:0] opcode;
wire [4:0] rd;
wire [2:0] funct3;
wire [4:0] rs1;
wire [4:0] rs2;
wire [6:0] funct7;

assign opcode = instruction[6:0];
assign rd     = instruction[11:7];
assign funct3 = instruction[14:12];
assign rs1    = instruction[19:15];
assign rs2    = instruction[24:20];
assign funct7 = instruction[31:25];
```

Use this version if your simulator is configured for strict
Verilog-2001.

------------------------------------------------------------------------

# 14. Recommended project directory

Create the project like this:

``` text
riscv_single_cycle/
│
├── steps.md
│
├── rtl/
│   ├── program_counter.v
│   ├── instruction_memory.v
│   ├── register_file.v
│   ├── alu.v
│   ├── immediate_generator.v
│   ├── main_control.v
│   ├── alu_control.v
│   ├── data_memory.v
│   ├── branch_unit.v
│   └── riscv_cpu.v
│
├── tb/
│   ├── tb_program_counter.v
│   ├── tb_register_file.v
│   ├── tb_alu.v
│   ├── tb_immediate_generator.v
│   └── tb_riscv_cpu.v
│
└── program.hex
```

------------------------------------------------------------------------

# 15. Step-by-step testing strategy

Do not immediately test the complete processor.

Test in this order:

``` text
PC
 ↓
Instruction Memory
 ↓
Register File
 ↓
ALU
 ↓
Immediate Generator
 ↓
Main Control
 ↓
ALU Control
 ↓
Data Memory
 ↓
Branch Unit
 ↓
Top-level CPU
```

This makes debugging much easier.

------------------------------------------------------------------------

# 16. PC testbench

Create:

``` text
tb/tb_program_counter.v
```

Code:

``` verilog
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
```

Expected:

``` text
Reset -> PC = 0
Next -> PC = 4
Next -> PC = 8
Next -> PC = 12
Next -> PC = 100
```

------------------------------------------------------------------------

# 17. ALU testbench

``` verilog
`timescale 1ns/1ps

module tb_alu;

reg [31:0] a;
reg [31:0] b;
reg [3:0] alu_control;

wire [31:0] result;
wire zero;

alu dut (
    .a(a),
    .b(b),
    .alu_control(alu_control),
    .result(result),
    .zero(zero)
);

initial begin

    a = 32'd10;
    b = 32'd5;

    alu_control = 4'b0000;
    #10;
    $display("ADD = %d", result);

    alu_control = 4'b0001;
    #10;
    $display("SUB = %d", result);

    alu_control = 4'b0010;
    #10;
    $display("AND = %h", result);

    alu_control = 4'b0011;
    #10;
    $display("OR = %h", result);

    alu_control = 4'b0100;
    #10;
    $display("XOR = %h", result);

    alu_control = 4'b0101;
    b = 32'd2;
    #10;
    $display("SLL = %h", result);

    $finish;

end

endmodule
```

------------------------------------------------------------------------

# 18. Register-file testbench

``` verilog
`timescale 1ns/1ps

module tb_register_file;

reg clk;
reg reset;

reg [4:0] rs1_addr;
reg [4:0] rs2_addr;

reg [4:0] rd_addr;
reg [31:0] rd_data;
reg reg_write;

wire [31:0] rs1_data;
wire [31:0] rs2_data;

register_file dut (
    .clk(clk),
    .reset(reset),

    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),

    .rd_addr(rd_addr),
    .rd_data(rd_data),
    .reg_write(reg_write),

    .rs1_data(rs1_data),
    .rs2_data(rs2_data)
);

always #5 clk = ~clk;

initial begin

    clk = 0;
    reset = 1;
    reg_write = 0;

    rs1_addr = 0;
    rs2_addr = 0;

    rd_addr = 0;
    rd_data = 0;

    #12;

    reset = 0;

    // Write 25 into x5
    rd_addr = 5;
    rd_data = 32'd25;
    reg_write = 1;

    #10;

    reg_write = 0;

    // Read x5
    rs1_addr = 5;

    #10;

    $display("x5 = %d", rs1_data);

    // Try to write x0
    rd_addr = 0;
    rd_data = 32'd999;
    reg_write = 1;

    #10;

    reg_write = 0;

    rs1_addr = 0;

    #10;

    $display("x0 = %d", rs1_data);

    $finish;

end

endmodule
```

Expected:

``` text
x5 = 25
x0 = 0
```

------------------------------------------------------------------------

# 19. Immediate-generator test

You should test at least one instruction from each format:

``` text
I
S
B
U
J
```

The most important thing to verify is that negative immediates are
correctly sign-extended.

For example:

``` text
I-type immediate = -1
```

should become:

``` text
FFFFFFFF
```

------------------------------------------------------------------------

# 20. Main instruction decoding table

Use this table while designing and debugging the control unit.

  Instruction class   Opcode      Main behavior
  ------------------- ----------- -------------------------------
  R-type              `0110011`   ALU register-register
  I arithmetic        `0010011`   ALU register-immediate
  Load                `0000011`   memory → register
  Store               `0100011`   register → memory
  Branch              `1100011`   conditional PC change
  LUI                 `0110111`   upper immediate → register
  AUIPC               `0010111`   PC + upper immediate
  JAL                 `1101111`   PC-relative jump + link
  JALR                `1100111`   register-relative jump + link

------------------------------------------------------------------------

# 21. Instruction flow examples

## 21.1 ADD

Instruction:

``` text
ADD x3, x1, x2
```

Flow:

``` text
PC
 ↓
Instruction Memory
 ↓
Decode
 ↓
Read x1 and x2
 ↓
ALU = ADD
 ↓
Write result into x3
 ↓
PC = PC + 4
```

Control:

``` text
RegWrite = 1
MemRead  = 0
MemWrite = 0
ALUSrc   = 0
WBSelect = ALU
```

------------------------------------------------------------------------

# 22. ADDI

Instruction:

``` text
ADDI x3, x1, 10
```

Flow:

``` text
Read x1
   +
sign-extended immediate 10
   |
   v
  ALU
   |
   v
Write x3
```

The ALU second input comes from the immediate:

``` text
ALUSrc = 1
```

------------------------------------------------------------------------

# 23. LW

Instruction:

``` text
LW x5, 0(x1)
```

Flow:

``` text
x1
 +
immediate
 |
 v
ALU
 |
 | effective address
 v
Data Memory
 |
 v
Write x5
```

Control:

``` text
RegWrite = 1
MemRead  = 1
MemWrite = 0
ALUSrc   = 1
WBSelect = MEMORY
```

------------------------------------------------------------------------

# 24. SW

Instruction:

``` text
SW x5, 0(x1)
```

Flow:

``` text
x1 + immediate
       |
       v
      ALU
       |
       v
 Memory address

x5 ----------------> Memory write data
```

No register is written:

``` text
RegWrite = 0
```

------------------------------------------------------------------------

# 25. BEQ

Instruction:

``` text
BEQ x1, x2, offset
```

The processor compares:

``` text
x1 == x2
```

If true:

``` text
PC_next = PC + branch_imm
```

Otherwise:

``` text
PC_next = PC + 4
```

------------------------------------------------------------------------

# 26. LUI

Instruction:

``` text
LUI x5, imm20
```

The U-type immediate generator creates:

``` text
{imm20, 12'b0}
```

Then the writeback MUX selects the immediate directly:

``` text
WBSelect = IMM
```

So:

``` text
x5 = immediate
```

------------------------------------------------------------------------

# 27. AUIPC

Instruction:

``` text
AUIPC x5, imm20
```

The ALU inputs become:

``` text
A = PC
B = U-immediate
```

Therefore:

``` text
ALU = PC + immediate
```

and the result goes into `rd`.

This is why the top-level has:

``` verilog
alu_src_a_pc
```

------------------------------------------------------------------------

# 28. JAL

Instruction:

``` text
JAL x1, offset
```

Two things happen:

``` text
x1 = PC + 4
PC = PC + J-immediate
```

Therefore JAL needs both:

``` text
PC + 4
```

for writeback and:

``` text
PC + immediate
```

for the next PC.

------------------------------------------------------------------------

# 29. JALR

Instruction:

``` text
JALR x1, x5, 0
```

Two things happen:

``` text
x1 = PC + 4
PC = (x5 + immediate) & ~1
```

The least significant bit is cleared.

------------------------------------------------------------------------

# 30. Final integration test program

Use this simple program first.

``` text
ADDI x1, x0, 5
ADDI x2, x0, 10
ADD  x3, x1, x2
SW   x3, 256(x0)
LW   x4, 256(x0)
BEQ  x4, x3, 8
ADDI x5, x0, 1
ADDI x5, x0, 2
```

The expected register values after execution:

``` text
x1 = 5
x2 = 10
x3 = 15
x4 = 15
x5 = 2
```

Why is x5 equal to 2?

Because:

``` text
BEQ x4, x3, 8
```

is true.

Therefore the first:

``` text
ADDI x5, x0, 1
```

is skipped.

The second:

``` text
ADDI x5, x0, 2
```

executes.

------------------------------------------------------------------------

# 31. `program.hex`

Use:

``` text
00500093
00A00113
002081B3
10302023
10002203
00418463
00100293
00200293
```

These correspond to:

``` text
00500093    ADDI x1, x0, 5
00A00113    ADDI x2, x0, 10
002081B3    ADD  x3, x1, x2
10302023    SW   x3, 256(x0)
10002203    LW   x4, 256(x0)
00418463    BEQ  x4, x3, 8
00100293    ADDI x5, x0, 1
00200293    ADDI x5, x0, 2
```

------------------------------------------------------------------------

# 32. Complete CPU testbench

Create:

``` text
tb/tb_riscv_cpu.v
```

``` verilog
`timescale 1ns/1ps

module tb_riscv_cpu;

reg clk;
reg reset;

riscv_cpu dut (
    .clk(clk),
    .reset(reset)
);

always #5 clk = ~clk;

initial begin

    clk = 1'b0;
    reset = 1'b1;

    #12;

    reset = 1'b0;

    // Let the CPU execute the program.
    #100;

    $display("=================================");
    $display("Final register values:");
    $display("x1 = %d", dut.registers.registers[1]);
    $display("x2 = %d", dut.registers.registers[2]);
    $display("x3 = %d", dut.registers.registers[3]);
    $display("x4 = %d", dut.registers.registers[4]);
    $display("x5 = %d", dut.registers.registers[5]);

    $display("=================================");

    $finish;

end

endmodule
```

Expected:

``` text
x1 = 5
x2 = 10
x3 = 15
x4 = 15
x5 = 2
```

------------------------------------------------------------------------

# 33. What should happen cycle by cycle?

Assuming reset starts PC at 0:

    Cycle   PC Instruction     Important result
  ------- ---- --------------- --------------------
        1    0 ADDI x1,x0,5    x1 = 5
        2    4 ADDI x2,x0,10   x2 = 10
        3    8 ADD x3,x1,x2    x3 = 15
        4   12 SW x3,256(x0)   memory\[256\] = 15
        5   16 LW x4,256(x0)   x4 = 15
        6   20 BEQ x4,x3,8     branch taken
        7   28 ADDI x5,x0,2    x5 = 2

Notice that address 24 is skipped.

That proves the branch logic is working.

------------------------------------------------------------------------

# 34. How to debug the integrated CPU

During simulation, inspect:

``` text
pc
instruction
opcode
rs1
rs2
rd
rs1_data
rs2_data
immediate
alu_control
alu_a
alu_b
alu_result
memory_data
branch_taken
pc_next
writeback_data
```

The most useful debugging sequence is:

``` text
1. Is PC correct?
2. Is instruction correct?
3. Is opcode correct?
4. Are rs1/rs2/rd correct?
5. Is the immediate correct?
6. Are control signals correct?
7. Are register values correct?
8. Is ALU operation correct?
9. Is memory address correct?
10. Is writeback correct?
11. Is pc_next correct?
```

------------------------------------------------------------------------

# 35. Common mistakes

## Mistake 1 --- Updating PC with PC+4 inside the PC module

Avoid making the PC module decide branches.

Better:

``` text
PC module:
    stores pc_next

Next-PC logic:
    calculates pc_next
```

------------------------------------------------------------------------

## Mistake 2 --- Allowing writes to x0

Wrong:

``` verilog
registers[rd_addr] <= rd_data;
```

Correct:

``` verilog
if (rd_addr != 0)
    registers[rd_addr] <= rd_data;
```

------------------------------------------------------------------------

## Mistake 3 --- Forgetting sign extension

For:

``` text
ADDI x1, x0, -1
```

the immediate must become:

``` text
FFFFFFFF
```

not:

``` text
00000FFF
```

------------------------------------------------------------------------

## Mistake 4 --- Confusing SRL and SRA

SRL:

``` text
zero-fill
```

SRA:

``` text
sign-fill
```

Use:

``` verilog
a >> shamt
```

for logical shift.

Use:

``` verilog
$signed(a) >>> shamt
```

for arithmetic shift.

------------------------------------------------------------------------

## Mistake 5 --- Confusing SLT and SLTU

SLT:

``` text
signed comparison
```

SLTU:

``` text
unsigned comparison
```

------------------------------------------------------------------------

## Mistake 6 --- Forgetting funct7

Both:

``` text
ADD
SUB
```

have:

``` text
funct3 = 000
```

They are distinguished by `funct7`.

Similarly:

``` text
SRL
SRA
```

share the same `funct3`.

------------------------------------------------------------------------

## Mistake 7 --- Branch immediate construction

Do not simply use:

``` verilog
instruction[31:20]
```

for a branch.

The B-immediate bits are distributed across the instruction.

Correct:

``` text
imm[12]   = instruction[31]
imm[11]   = instruction[7]
imm[10:5] = instruction[30:25]
imm[4:1]  = instruction[11:8]
imm[0]    = 0
```

------------------------------------------------------------------------

## Mistake 8 --- JAL immediate construction

JAL also has a scrambled immediate.

Correct:

``` text
imm[20]    = instruction[31]
imm[10:1]  = instruction[30:21]
imm[11]    = instruction[20]
imm[19:12] = instruction[19:12]
imm[0]     = 0
```

------------------------------------------------------------------------

# 36. Final architecture

After integration, your processor conceptually looks like this:

``` text
                         +----------------+
                         |      PC        |
                         +-------+--------+
                                 |
                                 v
                         +----------------+
                         | Instruction    |
                         | Memory         |
                         +-------+--------+
                                 |
                                 v
                         +----------------+
                         | Decode         |
                         +---+--------+---+
                             |        |
                +------------+        +-------------+
                |                                   |
                v                                   v
        +---------------+                   +---------------+
        | Register File |                   | Immediate     |
        | 2 read ports  |                   | Generator     |
        | 1 write port  |                   +-------+-------+
        +-------+-------+                           |
                |                                   |
                +----------------+------------------+
                                 |
                                 v
                         +---------------+
                         | Input MUXes   |
                         +-------+-------+
                                 |
                                 v
                            +---------+
                            |   ALU   |
                            +----+----+
                                 |
                      +----------+----------+
                      |                     |
                      v                     v
                +-----------+        +------------+
                | Data      |        | Branch /   |
                | Memory    |        | Jump Logic |
                +-----+-----+        +------+-----+
                      |                      |
                      v                      |
                +-----------+                |
                | Writeback |<---------------+
                |    MUX    |
                +-----+-----+
                      |
                      v
                Register File

                Next PC:
                PC + 4
                branch target
                JAL target
                JALR target
```

------------------------------------------------------------------------

# 37. Final implementation order

Follow this exact order while building the project.

``` text
STEP 1
Create program_counter.v
        ↓
Test PC

STEP 2
Create instruction_memory.v
        ↓
Test instruction fetch

STEP 3
Create register_file.v
        ↓
Test x0 and register read/write

STEP 4
Create alu.v
        ↓
Test ADD, SUB, AND, OR, XOR,
SLL, SRL, SRA, SLT, SLTU

STEP 5
Create immediate_generator.v
        ↓
Test I/S/B/U/J immediates

STEP 6
Create main_control.v
        ↓
Test opcode → control signals

STEP 7
Create alu_control.v
        ↓
Test opcode class + funct3 + funct7

STEP 8
Create data_memory.v
        ↓
Test LB/LH/LW/LBU/LHU
and SB/SH/SW

STEP 9
Create branch_unit.v
        ↓
Test BEQ/BNE/BLT/BGE/BLTU/BGEU

STEP 10
Create next-PC logic
        ↓
Test PC+4, branch, JAL, JALR

STEP 11
Connect writeback MUX
        ↓
Test ALU/MEM/PC+4/IMM writeback

STEP 12
Create riscv_cpu.v
        ↓
Connect every block

STEP 13
Create program.hex
        ↓
Run complete instruction sequence

STEP 14
Create tb_riscv_cpu.v
        ↓
Check registers, memory and PC

STEP 15
Add more instructions
        ↓
Test the complete instruction classes
covered by the lecture notes
```

------------------------------------------------------------------------

# 38. What you should understand before writing the top-level CPU

Before integration, you should be able to answer these questions without
looking at the code:

### PC

-   What does PC store?
-   Why is normal `PC_next = PC + 4`?
-   When does PC actually change?

### Instruction memory

-   Why does address 0,4,8,12 select consecutive instructions?
-   Why are the bottom two address bits not used in a word-array model?

### Register file

-   Why are register addresses 5 bits?
-   Why can we read two registers simultaneously?
-   Why must x0 always return zero?

### ALU

-   Why does SUB need funct7?
-   Difference between SRL and SRA?
-   Difference between SLT and SLTU?

### Immediate generator

-   Why are I/S/B/U/J immediate formats different?
-   Why do signed immediates need sign extension?
-   Why is B/J immediate bit 0 zero?

### Control

-   Why does LW need MemRead and RegWrite?
-   Why does SW not need RegWrite?
-   Why does JAL need PC+4 writeback?

### Data memory

-   Why is memory byte-addressable?
-   How does little endian store `0x12345678`?
-   Difference between LB and LBU?

### Branch/jump

-   How is a branch target calculated?
-   What is the difference between JAL and JALR?
-   Why is JALR bit 0 cleared?

If you can explain these, the Verilog becomes much easier to write
rather than something you are simply copying.

------------------------------------------------------------------------

# 39. Scope of this implementation

This project is a **single-cycle educational RV32I processor** based on
the instruction groups in the provided lecture notes.

It intentionally does not include:

``` text
Pipeline
Cache
Branch prediction
CSR subsystem
Privilege modes
Interrupts
Exceptions/traps
Virtual memory
Floating point
Compressed instructions
Other ISA extensions
```

It also assumes a simple simulation memory model and does not implement
architectural exception handling for unsupported or misaligned accesses.

The lecture notes establish the key RV32I facts used here: 32 × 32-bit
registers, x0 hardwired to zero, a PC holding the current instruction
address, 32-bit instructions aligned to four-byte boundaries,
R/I/S/SB/U/UJ instruction formats, and load/store/branch/jump behavior.

------------------------------------------------------------------------

# 40. Final mental model

The whole processor can be remembered as:

``` text
FETCH
    |
    v
DECODE
    |
    v
READ REGISTERS
    |
    v
GENERATE IMMEDIATE
    |
    v
EXECUTE / ADDRESS CALCULATION
    |
    +--------> DATA MEMORY
    |
    v
WRITEBACK
    |
    v
UPDATE PC
```

For every instruction, ask:

``` text
1. Which instruction did I fetch?
2. What does its opcode mean?
3. Which registers does it use?
4. Is there an immediate?
5. What operation should the ALU perform?
6. Does memory need to be accessed?
7. What value is written to rd?
8. What should PC become?
```

That is the complete thought process behind the single-cycle RV32I
processor.
