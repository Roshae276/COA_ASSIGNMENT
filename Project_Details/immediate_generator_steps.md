# Immediate Generator — Complete Step-by-Step Guide
## Single-Cycle RISC-V RV32I Processor in Verilog

This document explains the Immediate Generator from the RISC-V instruction formats all the way to the Verilog implementation and testbench.

The most important goal is to understand **where immediate bits are located in a 32-bit RISC-V instruction, how those bits are rearranged, and how they are sign-extended to 32 bits**.

---

# 1. Current CPU Progress

We are building a single-cycle RV32I processor component by component.

```text
[✓] Program Counter
[✓] Instruction Memory
[✓] Register File
[✓] ALU
[ ] Immediate Generator       <-- CURRENT
[ ] Main Control Unit
[ ] ALU Control Unit
[ ] Data Memory
[ ] MUXes + Branch/Jump Logic
[ ] Top-Level CPU
```

The Immediate Generator is the next component.

---

# 2. What Is an Immediate?

An immediate is a constant value encoded directly inside a RISC-V instruction.

For example:

```text
ADDI x1, x0, 5
```

means:

```text
x1 = x0 + 5
```

The value:

```text
5
```

is not stored in another register.

It is encoded inside the instruction itself.

Therefore, the CPU needs hardware that can:

```text
1. Look at the instruction.
2. Determine its format.
3. Extract the immediate bits.
4. Rearrange them if necessary.
5. Sign-extend them to 32 bits.
6. Send the resulting 32-bit immediate to the datapath.
```

That hardware is the:

```text
Immediate Generator
```

---

# 3. Why Do We Need a Separate Immediate Generator?

RISC-V instructions are 32 bits long, but the immediate is not always stored in the same positions.

The base RV32I instruction formats are:

```text
R-format
I-format
S-format
SB-format
U-format
UJ-format
```

The lecture notes describe these six formats and explain that R/I/S/U are core formats while SB and UJ are sub-formats.

The immediate is arranged differently in I, S, SB, U, and UJ formats.

Therefore, we cannot simply do:

```verilog
immediate = instruction[31:20];
```

for every instruction.

We need format-specific extraction.

---

# 4. The Six RV32I Instruction Formats

The six formats are:

```text
R
I
S
SB
U
UJ
```

Their general uses are:

```text
R  -> register-register arithmetic/logical instructions
I  -> immediate arithmetic, loads, JALR
S  -> stores
SB -> conditional branches
U  -> upper-immediate instructions
UJ -> JAL jump
```

Examples:

```text
R:
    ADD
    SUB
    AND
    OR
    XOR
    ...

I:
    ADDI
    LW
    JALR
    ...

S:
    SW
    SH
    SB

SB:
    BEQ
    BGE
    ...

U:
    LUI
    AUIPC

UJ:
    JAL
```

---

# 5. Important Observation About Register Fields

RISC-V keeps:

```text
rs1
rs2
rd
```

at consistent positions where applicable.

For example:

```text
rs1 = instruction[19:15]
rs2 = instruction[24:20]
rd  = instruction[11:7]
```

This simplifies instruction decoding.

However, immediate bits are rearranged between formats.

That is the main reason we need the Immediate Generator.

---

# 6. What Does "Sign Extend" Mean?

This is one of the most important concepts in this component.

Suppose we have a 12-bit immediate:

```text
000000000101
```

This is:

```text
5
```

To convert it to 32 bits, we add zeros to the left:

```text
00000000000000000000000000000101
```

For a positive signed value, the sign bit is:

```text
0
```

So we extend with zeros.

---

# 7. Sign Extension of a Negative Immediate

Suppose a 12-bit immediate is:

```text
111111111011
```

The most significant bit is:

```text
1
```

which indicates a negative signed value.

When sign extending, we copy that sign bit into the newly added upper bits:

```text
11111111111111111111111111111011
```

Therefore:

```text
12-bit immediate
       |
       v
111111111011
       |
       | sign extend
       v
11111111111111111111111111111011
```

This preserves the signed value when the immediate is used as a 32-bit operand.

---

# 8. General Rule for Sign Extension

If the original immediate has `N` bits:

```text
imm[N-1:0]
```

and its sign bit is:

```text
imm[N-1]
```

then a 32-bit sign extension is:

```text
{{(32-N){imm[N-1]}}, imm[N-1:0]}
```

For a 12-bit immediate:

```text
{{20{imm[11]}}, imm[11:0]}
```

because:

```text
32 - 12 = 20
```

---

# 9. Immediate Generator Interface

A simple design can use:

```verilog
module immediate_generator (
    input  wire [31:0] instruction,
    output reg  [31:0] immediate
);
```

There is:

```text
1 input:
    instruction

1 output:
    immediate
```

The generator examines the instruction's opcode and creates the appropriate 32-bit immediate.

No clock is needed.

Why?

Because the Immediate Generator is combinational logic.

---

# 10. Why Does the Immediate Generator Not Need a Clock?

The generator does not store anything.

If:

```text
instruction changes
```

then:

```text
immediate changes
```

according to the instruction format.

Therefore we use:

```verilog
always @(*)
```

not:

```verilog
always @(posedge clk)
```

This is the same basic idea as the ALU.

---

# 11. Opcodes Used by the Immediate Generator

The opcode tells us which instruction family we are dealing with.

Important opcodes from the RV32I lecture notes include:

```text
I-type arithmetic:
0010011

Load:
0000011

Store:
0100011

Branch:
1100011

LUI:
0110111

AUIPC:
0010111

JAL:
1101111

JALR:
1100111
```

The Immediate Generator can use these opcodes to select the correct immediate extraction logic.

---

# 12. I-Type Immediate

The I-type format is:

```text
31          20 19      15 14    12 11       7 6       0
+-------------+----------+--------+-----------+---------+
|  imm[11:0]  |   rs1    | funct3 |    rd     | opcode  |
+-------------+----------+--------+-----------+---------+
```

Therefore:

```text
I-type immediate = instruction[31:20]
```

The lecture notes specify that the I-type immediate is sign-extended to 32 bits.

So:

```verilog
immediate = {{20{instruction[31]}}, instruction[31:20]};
```

---

# 13. I-Type Example

Consider:

```text
ADDI x1, x0, 5
```

The immediate is:

```text
5
```

12-bit representation:

```text
000000000101
```

Sign extension:

```text
00000000000000000000000000000101
```

So the Immediate Generator outputs:

```text
00000005
```

---

# 14. Negative I-Type Example

Suppose the immediate is:

```text
-5
```

Its 12-bit two's-complement representation is:

```text
111111111011
```

After sign extension:

```text
11111111111111111111111111111011
```

which is:

```text
0xFFFFFFFB
```

This is why we must sign-extend rather than simply put zeros in the upper bits.

---

# 15. Loads Also Use I-Type Immediates

Load instructions are I-format instructions.

For example:

```text
LW x5, 12(x2)
```

The effective address is:

```text
EA = x2 + immediate
```

The immediate is the same 12-bit I-type field:

```text
instruction[31:20]
```

and it is sign-extended.

Therefore the Immediate Generator does not need a separate load-immediate format.

It can use the same I-type logic.

The lecture notes identify load instructions as I-format and give load opcode:

```text
0000011
```

---

# 16. JALR Also Uses I-Type Immediate

JALR is also an I-format instruction.

Its opcode is:

```text
1100111
```

Its immediate is:

```text
instruction[31:20]
```

and is sign-extended to 32 bits.

The lecture notes state that the JALR target uses the sign-extended 12-bit I-immediate added to `rs1`, with the least significant bit of the resulting target cleared.

The Immediate Generator only needs to produce the sign-extended immediate. The later PC/jump logic handles the target calculation.

---

# 17. S-Type Immediate

S-type instructions are stores:

```text
SW
SH
SB
```

The S-type format is:

```text
31       25 24      20 19      15 14    12 11        7 6       0
+----------+----------+----------+--------+------------+---------+
| imm[11:5]|   rs2    |   rs1    | funct3 |  imm[4:0]  | opcode  |
+----------+----------+----------+--------+------------+---------+
```

The immediate is split into two pieces:

```text
imm[11:5] = instruction[31:25]

imm[4:0]  = instruction[11:7]
```

Therefore the complete 12-bit immediate is:

```text
instruction[31:25] + instruction[11:7]
```

Then sign extend it.

---

# 18. S-Type Verilog Expression

The 32-bit immediate can be created as:

```verilog
immediate = {{20{instruction[31]}},
             instruction[31:25],
             instruction[11:7]};
```

Count the bits:

```text
20 sign bits
+
7 bits from instruction[31:25]
+
5 bits from instruction[11:7]

= 32 bits
```

---

# 19. Why Is the S-Type Immediate Split?

Because S-type has no destination register `rd`.

The positions normally used for `rd` are reused to hold:

```text
imm[4:0]
```

So:

```text
instruction[11:7]
```

contains the lower immediate bits instead of a destination register.

This is why the Immediate Generator must join two separated instruction fields.

---

# 20. S-Type Example

Consider:

```text
SW x5, 8(x2)
```

Conceptually:

```text
EA = x2 + 8
```

The Immediate Generator extracts the two pieces of the 12-bit immediate:

```text
imm[11:5]
imm[4:0]
```

joins them:

```text
imm[11:0]
```

and sign-extends them to 32 bits.

The Data Memory will later use:

```text
address = rs1 + immediate
```

---

# 21. SB-Type Immediate

SB-format is used for conditional branches.

Examples include:

```text
BEQ
BGE
...
```

The lecture notes show the SB immediate as:

```text
Imm[12] Imm[10:5] rs2 rs1 funct3 Imm[4:1] Imm[11] opcode
```

So the immediate bits are not stored in normal numerical order.

They must be rearranged.

The mapping is:

```text
imm[12]   = instruction[31]

imm[11]   = instruction[7]

imm[10:5] = instruction[30:25]

imm[4:1]  = instruction[11:8]

imm[0]    = 0
```

---

# 22. Why Is SB Immediate 13 Bits?

A branch target is PC-relative.

The lecture notes describe the branch target as:

```text
BT = PC + imm*2
```

and explain that the immediate is considered 13 bits wide with the least significant bit equal to zero.

Therefore:

```text
imm[12:0]
```

has:

```text
12 instruction-encoded bits
+
1 fixed zero bit
```

The fixed:

```text
imm[0] = 0
```

means the branch offset is aligned appropriately.

---

# 23. SB-Type Sign Extension

SB immediate has:

```text
13 bits
```

and must be sign-extended to:

```text
32 bits
```

So the number of sign bits is:

```text
32 - 13 = 19
```

Therefore the structure is:

```text
19 sign bits
+
imm[12]
+
imm[11]
+
imm[10:5]
+
imm[4:1]
+
0
```

Verilog:

```verilog
immediate = {
    {19{instruction[31]}},
    instruction[31],
    instruction[7],
    instruction[30:25],
    instruction[11:8],
    1'b0
};
```

Count:

```text
19 + 1 + 1 + 6 + 4 + 1 = 32
```

---

# 24. Very Important SB Immediate Mapping

Memorize this table:

```text
Immediate bit       Instruction bit

imm[12]     <-      instruction[31]
imm[11]     <-      instruction[7]
imm[10:5]   <-      instruction[30:25]
imm[4:1]    <-      instruction[11:8]
imm[0]      <-      0
```

This is one of the most important pieces of the Immediate Generator.

---

# 25. Example: BEQ

Consider:

```text
BEQ x1, x2, label
```

The branch logic will eventually do:

```text
if x1 == x2:
    PC = PC + branch_immediate
```

The Immediate Generator does NOT decide whether the branch is taken.

It only generates:

```text
branch_immediate
```

The later branch/PC logic combines:

```text
PC
+
immediate
```

when the branch condition is true.

---

# 26. U-Type Immediate

U-format is used by:

```text
LUI
AUIPC
```

The format is:

```text
31                       12 11       7 6       0
+--------------------------+-----------+---------+
|       imm[31:12]         |    rd     | opcode  |
+--------------------------+-----------+---------+
```

The lecture notes state that U-format handles large immediates.

The upper 20 bits are encoded in:

```text
instruction[31:12]
```

and the lower 12 bits of the resulting value are zeros.

Therefore:

```verilog
immediate = {instruction[31:12], 12'b0};
```

---

# 27. LUI

LUI means:

```text
Load Upper Immediate
```

For:

```text
LUI x10, 0x87654
```

the lecture notes give:

```text
x10 = 0x87654000
```

The Immediate Generator creates:

```text
87654000
```

The actual Register File write is handled later by the datapath.

The Immediate Generator simply provides:

```text
87654000
```

---

# 28. AUIPC

AUIPC means:

```text
Add Upper Immediate to PC
```

The lecture notes state that AUIPC adds the upper immediate, extended to 32 bits, to the PC.

The Immediate Generator still produces:

```text
{instruction[31:12], 12'b0}
```

The later ALU/PC datapath performs:

```text
PC + immediate
```

---

# 29. UJ-Type Immediate

UJ-format is used by:

```text
JAL
```

The lecture notes give the JAL immediate arrangement as:

```text
Imm[20|10:1|11|19:12]
```

The mapping is:

```text
imm[20]     = instruction[31]

imm[19:12]  = instruction[19:12]

imm[11]     = instruction[20]

imm[10:1]   = instruction[30:21]

imm[0]      = 0
```

---

# 30. Why Is UJ Immediate 21 Bits?

JAL uses a PC-relative jump offset.

The immediate is:

```text
imm[20:0]
```

which contains:

```text
20 instruction-encoded bits
+
1 fixed zero bit
```

Therefore the immediate has:

```text
21 bits
```

and is sign-extended to 32 bits.

Number of sign-extension bits:

```text
32 - 21 = 11
```

---

# 31. UJ-Type Verilog Expression

The 32-bit immediate is:

```verilog
immediate = {
    {11{instruction[31]}},
    instruction[31],
    instruction[19:12],
    instruction[20],
    instruction[30:21],
    1'b0
};
```

Count:

```text
11 + 1 + 8 + 1 + 10 + 1
= 32
```

---

# 32. Very Important UJ Mapping

Memorize:

```text
Immediate bit       Instruction bit

imm[20]     <-      instruction[31]
imm[19:12]  <-      instruction[19:12]
imm[11]     <-      instruction[20]
imm[10:1]   <-      instruction[30:21]
imm[0]      <-      0
```

This is different from SB format.

---

# 33. Summary of All Immediate Formats

| Format | Immediate Construction |
|---|---|
| I | `instruction[31:20]` sign-extended |
| S | `instruction[31:25]` + `instruction[11:7]`, sign-extended |
| SB | `31, 7, 30:25, 11:8, 0`, sign-extended |
| U | `instruction[31:12]` + `12'b0` |
| UJ | `31, 19:12, 20, 30:21, 0`, sign-extended |

---

# 34. Immediate Generator Control Strategy

We need some way to determine which format to use.

The easiest design for this project is to examine:

```text
instruction[6:0]
```

which is the opcode.

Then use:

```verilog
case (instruction[6:0])
```

For example:

```verilog
7'b0010011:
```

means I-type arithmetic.

```verilog
7'b0000011:
```

means load, also I-type.

```verilog
7'b0100011:
```

means S-type store.

```verilog
7'b1100011:
```

means SB branch.

```verilog
7'b0110111:
```

means LUI.

```verilog
7'b0010111:
```

means AUIPC.

```verilog
7'b1101111:
```

means JAL.

```verilog
7'b1100111:
```

means JALR, also I-type.

---

# 35. Why Can We Combine I-Type Opcodes?

The immediate extraction for:

```text
I-type arithmetic
load
JALR
```

is the same:

```text
instruction[31:20]
```

So we can group these opcodes into the same case branch.

For example:

```verilog
7'b0010011,
7'b0000011,
7'b1100111:
```

all use I-type immediate extraction.

---

# 36. Complete Immediate Generator Logic

The overall hardware flow becomes:

```text
                 32-bit instruction
                        |
                        v
                +---------------+
                | Immediate     |
                | Generator     |
                +-------+-------+
                        |
             inspect opcode
                        |
        +---------------+---------------+
        |       |       |       |       |
        v       v       v       v       v
       I        S      SB       U      UJ
        |       |       |       |       |
        +-------+-------+-------+-------+
                        |
                        v
                 32-bit immediate
```

---

# 37. Complete Verilog Module

After understanding all formats, the module can be:

```verilog
module immediate_generator (
    input  wire [31:0] instruction,
    output reg  [31:0] immediate
);

    always @(*) begin

        case (instruction[6:0])

            // I-type arithmetic, loads, and JALR
            7'b0010011,
            7'b0000011,
            7'b1100111: begin
                immediate = {{20{instruction[31]}},
                             instruction[31:20]};
            end

            // S-type stores
            7'b0100011: begin
                immediate = {{20{instruction[31]}},
                             instruction[31:25],
                             instruction[11:7]};
            end

            // SB-type branches
            7'b1100011: begin
                immediate = {{19{instruction[31]}},
                             instruction[31],
                             instruction[7],
                             instruction[30:25],
                             instruction[11:8],
                             1'b0};
            end

            // U-type LUI and AUIPC
            7'b0110111,
            7'b0010111: begin
                immediate = {instruction[31:12], 12'b0};
            end

            // UJ-type JAL
            7'b1101111: begin
                immediate = {{11{instruction[31]}},
                             instruction[31],
                             instruction[19:12],
                             instruction[20],
                             instruction[30:21],
                             1'b0};
            end

            // Unsupported instruction
            default: begin
                immediate = 32'd0;
            end

        endcase

    end

endmodule
```

---

# 38. Line-by-Line Understanding

## Module declaration

```verilog
module immediate_generator (
```

Starts the hardware module.

---

## Instruction input

```verilog
input wire [31:0] instruction,
```

The complete 32-bit RISC-V instruction enters the generator.

---

## Immediate output

```verilog
output reg [31:0] immediate
```

The generator produces a 32-bit immediate.

It is `reg` because it is assigned inside:

```verilog
always @(*)
```

---

# 39. Combinational Block

```verilog
always @(*) begin
```

This means:

```text
Whenever instruction changes,
recalculate immediate.
```

No clock is required.

---

# 40. Opcode Extraction

```verilog
instruction[6:0]
```

These are the seven opcode bits.

For example:

```text
instruction[6:0] = 0010011
```

means I-type arithmetic.

---

# 41. I-Type Code

```verilog
immediate = {{20{instruction[31]}},
             instruction[31:20]};
```

The first part:

```text
{20{instruction[31]}}
```

copies the sign bit 20 times.

Then:

```text
instruction[31:20]
```

provides the original 12-bit immediate.

Total:

```text
20 + 12 = 32
```

---

# 42. S-Type Code

```verilog
immediate = {{20{instruction[31]}},
             instruction[31:25],
             instruction[11:7]};
```

Here:

```text
instruction[31:25] -> imm[11:5]
instruction[11:7]  -> imm[4:0]
```

The two pieces are joined.

---

# 43. SB-Type Code

```verilog
immediate = {{19{instruction[31]}},
             instruction[31],
             instruction[7],
             instruction[30:25],
             instruction[11:8],
             1'b0};
```

The pieces form:

```text
sign extension
imm[12]
imm[11]
imm[10:5]
imm[4:1]
imm[0]
```

where:

```text
imm[0] = 0
```

---

# 44. U-Type Code

```verilog
immediate = {instruction[31:12], 12'b0};
```

No rearrangement is necessary.

We take:

```text
20 bits
```

and append:

```text
12 zeros
```

giving:

```text
32 bits
```

---

# 45. UJ-Type Code

```verilog
immediate = {{11{instruction[31]}},
             instruction[31],
             instruction[19:12],
             instruction[20],
             instruction[30:21],
             1'b0};
```

This rearranges the JAL immediate into normal bit order.

---

# 46. Why Does the Immediate Generator Not Calculate the Branch Target?

For SB:

```text
branch immediate
```

is generated here.

But:

```text
PC + immediate
```

belongs to the later datapath/branch logic.

Similarly for JAL:

```text
JAL immediate
```

is generated here.

The later PC logic calculates:

```text
PC + immediate
```

The Immediate Generator should remain a clean extraction/sign-extension block.

---

# 47. Why Does the Immediate Generator Not Decide Instruction Type Using funct3?

Because the opcode is enough to determine the immediate format for our supported base instructions.

For example:

```text
0010011 -> I-type
0100011 -> S-type
1100011 -> SB-type
0110111 -> U-type
0010111 -> U-type
1101111 -> UJ-type
1100111 -> I-type
```

The `funct3` field is mainly needed later by the control logic to distinguish operations within an instruction family.

---

# 48. Testbench Strategy

The Immediate Generator is combinational.

Therefore:

```text
No clock.
```

We will:

```text
1. Put a known instruction into instruction.
2. Wait a small amount of simulation time.
3. Print the generated immediate.
4. Try another instruction.
```

We should test every supported immediate format.

---

# 49. Testbench File

Create:

```text
tb/tb_immediate_generator.v
```

The testbench will test:

```text
I-type positive
I-type negative
S-type
SB-type
U-type
UJ-type
JALR I-type
LUI
AUIPC
unsupported opcode
```

---

# 50. Testbench Code

```verilog
`timescale 1ns/1ps

module tb_immediate_generator;

    reg [31:0] instruction;
    wire [31:0] immediate;

    immediate_generator dut (
        .instruction(instruction),
        .immediate(immediate)
    );

    initial begin

        $monitor("Time=%0t | Instruction=%h | Opcode=%b | Immediate=%h (%0d)",
                 $time,
                 instruction,
                 instruction[6:0],
                 immediate,
                 $signed(immediate));

        // --------------------------------
        // TEST 1: I-type positive immediate
        // ADDI x1, x0, 5
        // --------------------------------
        instruction = 32'h00500093;
        #10;

        // --------------------------------
        // TEST 2: I-type negative immediate
        // ADDI x1, x0, -5
        // --------------------------------
        instruction = 32'hFFB00093;
        #10;

        // --------------------------------
        // TEST 3: S-type
        // SW x5, 8(x2)
        // --------------------------------
        instruction = 32'h00512423;
        #10;

        // --------------------------------
        // TEST 4: U-type LUI
        // LUI x10, 0x87654
        // --------------------------------
        instruction = 32'h87654537;
        #10;

        // --------------------------------
        // TEST 5: U-type AUIPC
        // AUIPC x1, 0x12345
        // --------------------------------
        instruction = 32'h12345097;
        #10;

        // --------------------------------
        // TEST 6: JALR
        // JALR x1, x2, 16
        // --------------------------------
        instruction = 32'h010100E7;
        #10;

        // --------------------------------
        // TEST 7: SB-type branch
        // BEQ x1, x2, 8
        // --------------------------------
        instruction = 32'h00208463;
        #10;

        // --------------------------------
        // TEST 8: Unsupported opcode
        // --------------------------------
        instruction = 32'h00000000;
        #10;

        $finish;

    end

endmodule
```

---

# 51. Important Note About Encoded Test Instructions

The testbench uses complete 32-bit instruction encodings.

The Immediate Generator does not care whether every field represents a valid instruction for the CPU's full decoder.

It mainly needs the relevant immediate bit positions and the opcode.

For educational testing, these values let us verify the extraction logic.

---

# 52. Testing I-Type

Example:

```text
ADDI x1, x0, 5
```

Instruction:

```text
00500093
```

The Immediate Generator should produce:

```text
00000005
```

Expected:

```text
Immediate = 0x00000005
```

---

# 53. Testing Negative I-Type

Example:

```text
ADDI x1, x0, -5
```

The 12-bit immediate is:

```text
111111111011
```

After sign extension:

```text
FFFFFFFF - 4
```

or:

```text
FFFFFFFB
```

Expected:

```text
Immediate = 0xFFFFFFFB
```

and as signed decimal:

```text
-5
```

---

# 54. Testing S-Type

For:

```text
SW x5, 8(x2)
```

the immediate should be:

```text
8
```

Expected:

```text
Immediate = 0x00000008
```

This tests whether the generator correctly joins:

```text
instruction[31:25]
```

and:

```text
instruction[11:7]
```

---

# 55. Testing LUI

For:

```text
LUI x10, 0x87654
```

the resulting U-type immediate is:

```text
0x87654000
```

Expected:

```text
Immediate = 0x87654000
```

This verifies:

```verilog
{instruction[31:12], 12'b0}
```

---

# 56. Testing AUIPC

For:

```text
AUIPC x1, 0x12345
```

the generated immediate should be:

```text
0x12345000
```

The later ALU/PC datapath will add this to PC.

The Immediate Generator itself only produces:

```text
0x12345000
```

---

# 57. Testing JALR

JALR is I-type.

Therefore:

```text
JALR x1, x2, 16
```

should generate:

```text
0x00000010
```

The later jump logic will use:

```text
rs1 + immediate
```

and clear the target address LSB as specified for JALR.

---

# 58. Testing SB

For:

```text
BEQ x1, x2, 8
```

the immediate should be:

```text
8
```

Expected:

```text
Immediate = 0x00000008
```

The branch target is later calculated using PC-relative logic.

---

# 59. Unsupported Instruction

The testbench ends with:

```verilog
instruction = 32'h00000000;
```

Its opcode is:

```text
0000000
```

which is not one of our supported immediate-generating opcodes.

Therefore:

```verilog
default:
    immediate = 32'd0;
```

produces:

```text
Immediate = 0
```

This is useful for testing the default case.

---

# 60. Compile the Immediate Generator

From the project root:

```powershell
iverilog -o imm_sim rtl/immediate_generator.v tb/tb_immediate_generator.v
```

Then:

```powershell
vvp imm_sim
```

---

# 61. What You Should Expect

Important expected values:

```text
ADDI +5      -> 00000005
ADDI -5      -> FFFFFFFB
SW +8        -> 00000008
LUI          -> 87654000
AUIPC        -> 12345000
JALR +16     -> 00000010
BEQ +8       -> 00000008
Unsupported  -> 00000000
```

The exact timestamp formatting is not important.

The immediate values are what matter.

---

# 62. Why This Component Is More Difficult Than the ALU

The ALU mainly asks:

```text
Which operation?
```

The Immediate Generator asks:

```text
Which instruction format?
Where are the immediate bits?
Are they split?
Do they need rearranging?
How many bits are there?
Where does the sign extension go?
```

For this reason, the most important skill here is not memorizing Verilog.

It is understanding the instruction bit layouts.

---

# 63. Quick Format Cheat Sheet

## I-Type

```text
instruction[31:20]
```

Sign extend 12 bits:

```text
{{20{instruction[31]}}, instruction[31:20]}
```

---

## S-Type

```text
instruction[31:25]
instruction[11:7]
```

Combine:

```text
{{20{instruction[31]}},
 instruction[31:25],
 instruction[11:7]}
```

---

## SB-Type

```text
instruction[31]
instruction[7]
instruction[30:25]
instruction[11:8]
0
```

Sign extend 13 bits:

```text
{{19{instruction[31]}},
 instruction[31],
 instruction[7],
 instruction[30:25],
 instruction[11:8],
 1'b0}
```

---

## U-Type

```text
instruction[31:12]
12 zeros
```

```text
{instruction[31:12], 12'b0}
```

---

## UJ-Type

```text
instruction[31]
instruction[19:12]
instruction[20]
instruction[30:21]
0
```

Sign extend 21 bits:

```text
{{11{instruction[31]}},
 instruction[31],
 instruction[19:12],
 instruction[20],
 instruction[30:21],
 1'b0}
```

---

# 64. Immediate Generator vs ALU

These are different components.

```text
Immediate Generator
        |
        | creates immediate
        v
     immediate
        |
        v
       MUX
        |
        v
       ALU
```

The Immediate Generator does:

```text
instruction -> immediate
```

The ALU does:

```text
operand A + operand B
```

or another selected operation.

The ALU does NOT extract instruction bits.

The Immediate Generator does NOT perform arithmetic operations.

---

# 65. Example: ADDI End-to-End

Instruction:

```text
ADDI x1, x0, 5
```

Step 1:

```text
Instruction Memory
        |
        v
32-bit instruction
```

Step 2:

```text
Immediate Generator
```

extracts:

```text
instruction[31:20]
```

and produces:

```text
00000005
```

Step 3:

```text
Register File
```

reads:

```text
x0 = 0
```

Step 4:

```text
ALU
```

receives:

```text
A = 0
B = 5
```

and control:

```text
ADD
```

Step 5:

```text
ALU result = 5
```

Step 6:

```text
Register File
```

writes:

```text
x1 = 5
```

So the complete path is:

```text
Instruction
    |
    +--------------------+
    |                    |
    v                    v
Register File      Immediate Generator
    |                    |
    |                    |
    v                    v
   x0 = 0              imm = 5
       \                 /
        \               /
         v             v
              MUX
               |
               v
              ALU
               |
               v
             result
               |
               v
              x1
```

---

# 66. Example: SW End-to-End

Instruction:

```text
SW x5, 8(x2)
```

The Immediate Generator produces:

```text
8
```

Register File provides:

```text
rs1 = x2
rs2 = x5
```

The ALU calculates:

```text
address = x2 + 8
```

The Data Memory receives:

```text
address
write data = x5
```

So:

```text
Instruction
    |
    +--> rs1/rs2 --> Register File
    |
    +--> immediate --> Immediate Generator
                         |
                         v
                       ALU
                         |
                         v
                    Memory Address
```

---

# 67. Example: BEQ End-to-End

Instruction:

```text
BEQ x1, x2, label
```

Register File:

```text
read_data1 = x1
read_data2 = x2
```

ALU:

```text
x1 - x2
```

If result is zero:

```text
zero = 1
```

Immediate Generator:

```text
branch immediate
```

Branch logic:

```text
if zero:
    PC = PC + immediate
else:
    PC = PC + 4
```

This shows why both the ALU and Immediate Generator are needed for branch instructions.

---

# 68. Common Mistakes

## Mistake 1 — Using only `instruction[31:20]` for every format

Wrong.

Only I-type uses:

```text
instruction[31:20]
```

S, SB, U, and UJ have different layouts.

---

## Mistake 2 — Forgetting sign extension

Wrong:

```verilog
immediate = {20'b0, instruction[31:20]};
```

This would treat a negative 12-bit immediate incorrectly.

Correct:

```verilog
immediate = {{20{instruction[31]}}, instruction[31:20]};
```

---

## Mistake 3 — Forgetting SB bit 0

Branch immediate must have:

```text
imm[0] = 0
```

---

## Mistake 4 — Mixing up SB and UJ layouts

They are different.

SB:

```text
31, 7, 30:25, 11:8, 0
```

UJ:

```text
31, 19:12, 20, 30:21, 0
```

---

## Mistake 5 — Using the wrong number of sign bits

For 12-bit immediate:

```text
20 sign bits
```

For 13-bit SB immediate:

```text
19 sign bits
```

For 21-bit UJ immediate:

```text
11 sign bits
```

---

## Mistake 6 — Adding a clock

The Immediate Generator is combinational.

Use:

```verilog
always @(*)
```

not:

```verilog
always @(posedge clk)
```

---

## Mistake 7 — Making U-type behave like I-type

U-type is:

```text
instruction[31:12] + 12 zeros
```

It is not a 12-bit sign-extended immediate.

---

# 69. Final Verification Checklist

Before moving on, verify:

- [ ] I-type extraction works.
- [ ] I-type positive immediate works.
- [ ] I-type negative immediate works.
- [ ] Load instructions use I-type extraction.
- [ ] JALR uses I-type extraction.
- [ ] S-type immediate is correctly reconstructed.
- [ ] SB-type immediate is correctly reconstructed.
- [ ] SB bit 0 is zero.
- [ ] U-type immediate is shifted left by 12 bits.
- [ ] LUI immediate works.
- [ ] AUIPC immediate works.
- [ ] UJ-type immediate is correctly reconstructed.
- [ ] UJ bit 0 is zero.
- [ ] Sign extension is correct.
- [ ] Unsupported opcode gives a defined output.
- [ ] No clock is used.
- [ ] Testbench covers every immediate format.
- [ ] Compilation succeeds.
- [ ] Terminal output matches expected immediate values.

---

# 70. Current Processor Progress

After completing the Immediate Generator:

```text
[✓] Program Counter
[✓] Instruction Memory
[✓] Register File
[✓] ALU
[✓] Immediate Generator
[ ] Main Control Unit
[ ] ALU Control Unit
[ ] Data Memory
[ ] MUXes + Branch/Jump Logic
[ ] Top-Level CPU
```

The next component is the:

```text
Main Control Unit
```

The Main Control Unit will look at the instruction opcode and generate high-level control signals such as:

```text
RegWrite
MemRead
MemWrite
MemToReg
ALUSrc
Branch
Jump
```

Those signals will eventually control the datapath of the complete single-cycle CPU.

---

# 71. Final Mental Model

At this point, you should be able to visualize:

```text
              Instruction
                   |
          +--------+---------+
          |                  |
          v                  v
    Instruction         Immediate
      fields            Generator
          |                  |
          |                  |
          v                  v
    Register File          32-bit
          |               immediate
          |                  |
          +--------+---------+
                   |
                   v
                  ALU
                   |
                   v
                Result
```

The Immediate Generator has one job:

```text
32-bit instruction
       |
       v
extract + rearrange + sign extend
       |
       v
32-bit immediate
```

Once this is clear, the Main Control Unit becomes much easier to understand.
