# Main Control Unit --- Step-by-Step Guide

## Single-Cycle RISC-V RV32I Processor

> **Project stage:** Program Counter → Instruction Memory → Register
> File → ALU → Immediate Generator → **Main Control Unit**
>
> This document explains the Main Control Unit before writing the
> Verilog. The RISC-V lecture notes are used for the instruction
> formats, opcodes, and instruction behavior. The control-signal design
> itself is the hardware implementation we are choosing for our
> single-cycle processor.

------------------------------------------------------------------------

# 1. Where are we in the processor?

So far we have built and tested:

1.  Program Counter
2.  Instruction Memory
3.  Register File
4.  ALU
5.  Immediate Generator

Now we need something that looks at the instruction and tells the
datapath:

> **"For this instruction, which hardware parts should be active and
> what should they do?"**

That block is the **Main Control Unit**.

------------------------------------------------------------------------

# 2. What does the lecture material give us?

The RISC-V lecture material explains the ISA and instruction encoding:

-   RV32I has 32 registers, x0--x31, each 32 bits.
-   The PC contains the address of the current instruction.
-   Instructions are 32 bits and aligned on four-byte boundaries.
-   The six instruction formats are R, I, S, SB, U and UJ.
-   The operation is identified using fields such as opcode, funct3 and
    funct7.
-   It explains arithmetic instructions, loads, stores, branches, LUI,
    AUIPC, JAL and JALR.

For our processor, these instruction properties become the input
information used by the control unit.

The lecture material does **not** explicitly teach names such as
`ALUSrc`, `ALUOp`, `RegWrite`, etc. Those are implementation-level
control signals that we introduce while designing the processor
datapath.

------------------------------------------------------------------------

# 3. Why do we need a Control Unit?

Consider:

``` text
ADDI x1, x2, 5
```

The processor must:

1.  Read x2 from the register file.
2.  Generate the immediate 5.
3.  Give x2 and the immediate to the ALU.
4.  Tell the ALU to perform ADD.
5.  Write the ALU result into x1.

Now consider:

``` text
LW x5, 8(x2)
```

The processor must:

1.  Read x2.
2.  Generate immediate 8.
3.  Calculate address x2 + 8.
4.  Read data memory.
5.  Write the memory data into x5.

These two instructions use some of the same hardware but in different
ways.

The Control Unit generates signals that select the required path.

------------------------------------------------------------------------

# 4. Basic idea

The flow is:

``` text
                 32-bit Instruction
                         |
                         v
                  +-------------+
                  | Main Control|
                  |    Unit     |
                  +-------------+
                         |
       +-----------------+------------------+
       |                 |                  |
       v                 v                  v
   Register           Memory              ALU
    control           control            control
```

The Main Control Unit mainly looks at:

``` text
instruction[6:0]
```

which is the **opcode**.

Later, the ALU Control Unit will additionally use fields such as
`funct3` and `funct7` to determine the exact ALU operation.

------------------------------------------------------------------------

# 5. What is an opcode?

The lowest 7 bits of a RISC-V instruction are the opcode:

``` text
instruction[6:0]
```

For the instructions used in our processor:

  Instruction type / instruction   Opcode
  -------------------------------- -----------
  R-type arithmetic                `0110011`
  I-type arithmetic                `0010011`
  Load                             `0000011`
  Store                            `0100011`
  Branch                           `1100011`
  JAL                              `1101111`
  JALR                             `1100111`
  LUI                              `0110111`
  AUIPC                            `0010111`

The Control Unit can therefore start with:

``` verilog
case (opcode)
```

and generate the appropriate control signals.

------------------------------------------------------------------------

# 6. What is a control signal?

A control signal is simply a 0/1 signal that tells hardware what to do.

For example:

``` text
RegWrite = 1
```

means:

> The register file should write a value.

While:

``` text
RegWrite = 0
```

means:

> Do not write to the register file.

------------------------------------------------------------------------

# 7. Our control signals

For this project, we will use these signals:

``` text
RegWrite
MemRead
MemWrite
MemToReg
ALUSrc
ALUOp
Branch
Jump
Jalr
ALUSrcA
```

Some of these are standard datapath-control names. We are defining their
exact meaning here so that the complete processor has a clear interface.

------------------------------------------------------------------------

# 8. RegWrite

`RegWrite` controls whether the register file writes to `rd`.

``` text
RegWrite = 1
        ↓
write rd

RegWrite = 0
        ↓
do not write rd
```

Examples:

``` text
ADD   → 1
ADDI  → 1
LW    → 1
JAL   → 1
JALR  → 1
LUI   → 1

SW    → 0
BEQ   → 0
```

------------------------------------------------------------------------

# 9. MemRead

`MemRead` indicates that the data memory should be read.

For:

``` text
LW x5, 8(x2)
```

we need:

``` text
MemRead = 1
```

For arithmetic instructions:

``` text
ADD
ADDI
SUB
```

we do not need data memory:

``` text
MemRead = 0
```

------------------------------------------------------------------------

# 10. MemWrite

`MemWrite` indicates that data should be written into memory.

For:

``` text
SW x5, 8(x2)
```

we need:

``` text
MemWrite = 1
```

For `LW`, arithmetic, branches and jumps:

``` text
MemWrite = 0
```

------------------------------------------------------------------------

# 11. MemToReg

For a load instruction, the value written into the register comes from
memory.

For an arithmetic instruction, the value written into the register comes
from the ALU.

So we need a selection signal:

``` text
MemToReg = 0 → write ALU result
MemToReg = 1 → write memory result
```

Example:

``` text
ADD x3, x1, x2

ALU result → rd
```

Therefore:

``` text
MemToReg = 0
```

For:

``` text
LW x3, 8(x1)

Memory result → rd
```

Therefore:

``` text
MemToReg = 1
```

------------------------------------------------------------------------

# 12. ALUSrc

The ALU has two inputs:

``` text
              ALU
             /   \
            A     B
```

The first input normally comes from `rs1`.

The second input can come from either:

-   `rs2`
-   immediate

Therefore we need a MUX:

``` text
                 rs2
                  |
                  |
                  v
              +-------+
              |       |
              |  MUX  |----> ALU B
              |       |
              +-------+
                  ^
                  |
                imm
```

`ALUSrc` controls this MUX:

``` text
ALUSrc = 0 → ALU B = rs2
ALUSrc = 1 → ALU B = immediate
```

Examples:

### R-type

``` text
ADD x3, x1, x2
```

ALU:

``` text
x1 + x2
```

Therefore:

``` text
ALUSrc = 0
```

### I-type

``` text
ADDI x3, x1, 5
```

ALU:

``` text
x1 + 5
```

Therefore:

``` text
ALUSrc = 1
```

### LW

``` text
LW x5, 8(x2)
```

Address:

``` text
x2 + 8
```

Therefore:

``` text
ALUSrc = 1
```

### SW

``` text
SW x5, 8(x2)
```

Address:

``` text
x2 + 8
```

Therefore:

``` text
ALUSrc = 1
```

------------------------------------------------------------------------

# 13. ALUSrcA

There is one extra issue with AUIPC.

For:

``` text
AUIPC x1, imm
```

the processor needs:

``` text
PC + immediate
```

The ALU's first input therefore sometimes needs to be the PC instead of
`rs1`.

So we use `ALUSrcA`.

Our encoding is:

``` text
ALUSrcA = 00 → rs1
ALUSrcA = 01 → PC
ALUSrcA = 10 → zero
```

The `zero` option is useful for instructions such as LUI if we decide to
calculate the value through the ALU.

For our current datapath, LUI can also use the immediate directly
through the result selection. The signal is kept because it makes the
datapath explicit and gives us a clean way to support AUIPC.

------------------------------------------------------------------------

# 14. ALUOp

`ALUOp` does NOT directly mean "ADD", "SUB", etc.

It is a small control code that tells the later **ALU Control Unit**
what kind of instruction it is.

We use:

``` text
ALUOp = 00 → address/add operation
ALUOp = 01 → branch/subtraction
ALUOp = 10 → R-type
ALUOp = 11 → I-type arithmetic
```

Why do we need another ALU Control Unit?

Because for R-type:

``` text
0110011
```

the opcode alone does not tell us whether the instruction is:

``` text
ADD
SUB
AND
OR
XOR
SLT
...
```

The ALU Control Unit will later inspect:

``` text
funct3
funct7
ALUOp
```

and produce the 4-bit ALU control code used by our ALU.

So the chain is:

``` text
Instruction
     |
     v
Main Control
     |
    ALUOp
     |
     v
ALU Control <---- funct3/funct7
     |
     v
ALU control code
     |
     v
ALU
```

------------------------------------------------------------------------

# 15. Branch

`Branch` tells the processor that the instruction is a conditional
branch.

For:

``` text
BEQ x1, x2, offset
```

we set:

``` text
Branch = 1
```

For normal arithmetic:

``` text
Branch = 0
```

Later, the PC-selection logic will combine:

``` text
Branch
```

with the ALU's:

``` text
zero
```

signal.

For BEQ:

``` text
x1 - x2 = 0
```

means:

``` text
zero = 1
```

and the branch can be taken.

------------------------------------------------------------------------

# 16. Jump

`Jump` identifies JAL.

For:

``` text
JAL x1, offset
```

we need:

``` text
Jump = 1
```

JAL also writes:

``` text
PC + 4
```

into `rd`.

------------------------------------------------------------------------

# 17. Jalr

JALR is different from JAL because its target uses:

``` text
rs1 + immediate
```

So we use a separate signal:

``` text
Jalr = 1
```

For JAL:

``` text
Jump = 1
Jalr = 0
```

For JALR:

``` text
Jump = 1
Jalr = 1
```

This will allow the PC logic to distinguish:

``` text
JAL  → PC + immediate
JALR → rs1 + immediate
```

------------------------------------------------------------------------

# 18. Control table

Here is the main table we will implement.

  ----------------------------------------------------------------------------------------------------------
  Instruction     RegWrite   MemRead   MemWrite   MemToReg   ALUSrc ALUSrcA   ALUOp     Branch   Jump   Jalr
  ------------- ---------- --------- ---------- ---------- -------- --------- ------- -------- ------ ------
  R-type                 1         0          0          0        0 00        10             0      0      0

  I-type                 1         0          0          0        1 00        11             0      0      0
  arithmetic                                                                                          

  LW                     1         1          0          1        1 00        00             0      0      0

  SW                     0         0          1          0        1 00        00             0      0      0

  BEQ/branch             0         0          0          0        0 00        01             1      0      0

  JAL                    1         0          0        0\*        1 01        00             0      1      0

  JALR                   1         0          0        0\*        1 00        00             0      1      1

  LUI                    1         0          0          0        1 10        00             0      0      0

  AUIPC                  1         0          0          0        1 01        00             0      0      0
  ----------------------------------------------------------------------------------------------------------

`*` For JAL/JALR, our eventual write-back MUX will need a `PC+4` option.
The current `MemToReg` signal alone cannot express that third source.
Therefore, when we build the complete top-level processor, we will
replace/extend this simple write-back selection with a multi-way
`ResultSrc`/write-back MUX.

This is an important design point: **do not force JAL/JALR into an
incorrect two-input MemToReg design.**

------------------------------------------------------------------------

# 19. Why are JAL and JALR special?

JAL:

``` text
rd = PC + 4
PC = PC + immediate
```

JALR:

``` text
rd = PC + 4
PC = rs1 + immediate
```

Therefore they need two things:

1.  A jump target.
2.  `PC + 4` written into `rd`.

Later, our top-level datapath will have a write-back MUX with multiple
possible sources:

``` text
ALU result
Memory data
PC + 4
Immediate
```

This is more complete than a simple ALU-vs-memory MUX.

------------------------------------------------------------------------

# 20. Why is LUI special?

LUI means:

``` text
rd = immediate[31:12] << 12
```

Example:

``` text
LUI x5, 0x12345
```

produces:

``` text
x5 = 0x12345000
```

There is no normal `rs1 + rs2` calculation.

Our Immediate Generator already produces:

``` text
12345000
```

So later the write-back logic can select the generated immediate for
LUI.

------------------------------------------------------------------------

# 21. Why is AUIPC special?

AUIPC means:

``` text
rd = PC + immediate
```

Therefore:

``` text
ALU input A = PC
ALU input B = immediate
ALU operation = ADD
```

This is exactly why we introduced:

``` text
ALUSrcA
```

For AUIPC:

``` text
ALUSrcA = 01
ALUSrc = 1
```

------------------------------------------------------------------------

# 22. Default values are important

Inside the Verilog `always @(*)` block, we first assign safe defaults:

``` verilog
RegWrite = 0;
MemRead  = 0;
MemWrite = 0;
...
```

Why?

Because this is **combinational logic**.

Every output should receive a value for every possible input.

It also makes unsupported instructions behave safely instead of
accidentally enabling hardware.

------------------------------------------------------------------------

# 23. Why use `always @(*)`?

The Main Control Unit has no clock.

It is combinational logic:

``` text
instruction changes
       ↓
control signals change
```

Therefore:

``` verilog
always @(*)
```

is appropriate.

We do NOT use:

``` verilog
always @(posedge clk)
```

because the control unit is not storing anything.

------------------------------------------------------------------------

# 24. Why is opcode an input instead of the whole instruction?

We could pass the complete instruction:

``` verilog
input wire [31:0] instruction;
```

and then use:

``` verilog
instruction[6:0]
```

inside the module.

That is convenient.

We will do exactly that because it keeps the top-level wiring simple.

------------------------------------------------------------------------

# 25. Verilog structure

The module will look like:

``` text
instruction
     |
     v
instruction[6:0]
     |
     v
   case
     |
     +----> RegWrite
     +----> MemRead
     +----> MemWrite
     +----> MemToReg
     +----> ALUSrc
     +----> ALUSrcA
     +----> ALUOp
     +----> Branch
     +----> Jump
     +----> Jalr
```

------------------------------------------------------------------------

# 26. Main Control Unit algorithm

### Step 1

Receive the 32-bit instruction.

### Step 2

Extract:

``` text
opcode = instruction[6:0]
```

### Step 3

Set all control signals to safe defaults.

### Step 4

Use:

``` verilog
case (opcode)
```

### Step 5

For each instruction class, assign the correct controls.

### Step 6

Finish with a `default` case.

------------------------------------------------------------------------

# 27. Example: R-type

Suppose:

``` text
ADD x3, x1, x2
```

Opcode:

``` text
0110011
```

We need:

``` text
read rs1
read rs2
ALU gets rs1 and rs2
ALU performs an R-type operation
write result to rd
```

Therefore:

``` text
RegWrite = 1
MemRead  = 0
MemWrite = 0
ALUSrc   = 0
ALUOp    = 10
```

The exact ADD/SUB/AND/OR operation will be decided later by ALU Control.

------------------------------------------------------------------------

# 28. Example: ADDI

``` text
ADDI x1, x2, 5
```

Opcode:

``` text
0010011
```

We need:

``` text
rs1 + immediate
```

Therefore:

``` text
RegWrite = 1
ALUSrc   = 1
ALUOp    = 11
```

The ALU Control Unit will later determine which I-type ALU operation is
required using funct3.

------------------------------------------------------------------------

# 29. Example: LW

``` text
LW x5, 8(x2)
```

We need:

``` text
address = x2 + 8
memory[address] → x5
```

Therefore:

``` text
RegWrite = 1
MemRead  = 1
MemWrite = 0
MemToReg = 1
ALUSrc   = 1
ALUOp    = 00
```

------------------------------------------------------------------------

# 30. Example: SW

``` text
SW x5, 8(x2)
```

We need:

``` text
address = x2 + 8
memory[address] = x5
```

Therefore:

``` text
RegWrite = 0
MemRead  = 0
MemWrite = 1
ALUSrc   = 1
ALUOp    = 00
```

------------------------------------------------------------------------

# 31. Example: BEQ

``` text
BEQ x1, x2, 8
```

We need the ALU to compare:

``` text
x1 - x2
```

Therefore:

``` text
Branch = 1
ALUSrc = 0
ALUOp  = 01
```

The later PC logic uses:

``` text
Branch AND zero
```

to decide whether to use the branch target.

------------------------------------------------------------------------

# 32. Example: JAL

``` text
JAL x1, 8
```

We need:

``` text
PC = PC + 8
x1 = old PC + 4
```

Therefore:

``` text
Jump     = 1
RegWrite = 1
ALUSrcA  = 01
ALUSrc   = 1
```

The write-back selection will later choose `PC + 4`.

------------------------------------------------------------------------

# 33. Example: JALR

``` text
JALR x1, x2, 16
```

We need:

``` text
target = x2 + 16
x1 = old PC + 4
```

Therefore:

``` text
Jump     = 1
Jalr     = 1
RegWrite = 1
ALUSrcA  = 00
ALUSrc   = 1
```

------------------------------------------------------------------------

# 34. Example: LUI

``` text
LUI x5, 0x12345
```

The immediate generator produces:

``` text
12345000
```

We need:

``` text
x5 = 12345000
```

Therefore:

``` text
RegWrite = 1
ALUSrc   = 1
ALUSrcA  = 10
```

The final write-back design can select the immediate directly.

------------------------------------------------------------------------

# 35. Example: AUIPC

``` text
AUIPC x5, 0x12345
```

We need:

``` text
x5 = PC + 12345000
```

Therefore:

``` text
RegWrite = 1
ALUSrcA  = 01
ALUSrc   = 1
ALUOp    = 00
```

The ALU performs ADD.

------------------------------------------------------------------------

# 36. Important distinction: Main Control vs ALU Control

Do not mix these two.

## Main Control

Answers:

> What type of instruction is this and which datapath paths should be
> enabled?

Outputs things like:

``` text
RegWrite
MemRead
MemWrite
ALUSrc
ALUOp
Branch
Jump
```

## ALU Control

Answers:

> What exact ALU operation should happen?

For example:

``` text
0000 → ADD
0001 → SUB
0010 → AND
0011 → OR
...
```

Our ALU already uses these 4-bit codes.

So eventually:

``` text
Main Control
      |
     ALUOp
      |
      v
ALU Control <--- funct3/funct7
      |
      v
4-bit ALU control
      |
      v
ALU
```

------------------------------------------------------------------------

# 37. Testbench strategy

We will test one instruction from every important opcode class:

``` text
R-type
I-type arithmetic
LW
SW
BEQ
JAL
JALR
LUI
AUIPC
unknown opcode
```

We don't need a clock because the Main Control Unit is combinational.

The testbench will simply change:

``` verilog
instruction
```

and observe the outputs.

------------------------------------------------------------------------

# 38. Expected testbench behavior

For R-type:

``` text
Opcode = 0110011
RegWrite = 1
ALUSrc = 0
ALUOp = 10
```

For I-type:

``` text
Opcode = 0010011
RegWrite = 1
ALUSrc = 1
ALUOp = 11
```

For LW:

``` text
Opcode = 0000011
RegWrite = 1
MemRead = 1
MemToReg = 1
ALUSrc = 1
ALUOp = 00
```

For SW:

``` text
Opcode = 0100011
MemWrite = 1
ALUSrc = 1
ALUOp = 00
```

For BEQ:

``` text
Opcode = 1100011
Branch = 1
ALUSrc = 0
ALUOp = 01
```

For JAL:

``` text
Opcode = 1101111
Jump = 1
RegWrite = 1
```

For JALR:

``` text
Opcode = 1100111
Jump = 1
Jalr = 1
RegWrite = 1
```

For LUI:

``` text
Opcode = 0110111
RegWrite = 1
```

For AUIPC:

``` text
Opcode = 0010111
RegWrite = 1
ALUSrcA = 01
ALUSrc = 1
```

------------------------------------------------------------------------

# 39. Common mistakes

### Mistake 1: Thinking ALUOp is the exact ALU operation

Not in our design.

``` text
ALUOp = 10
```

means:

> This is an R-type instruction.

The ALU Control Unit later determines ADD/SUB/AND/etc.

------------------------------------------------------------------------

### Mistake 2: Using `always @(posedge clk)`

Wrong for this module.

Control Unit is combinational:

``` verilog
always @(*)
```

------------------------------------------------------------------------

### Mistake 3: Forgetting defaults

Without defaults, some outputs can retain old values in simulation or
synthesize into unwanted latches.

------------------------------------------------------------------------

### Mistake 4: Treating JAL like an ordinary ALU instruction

JAL must write:

``` text
PC + 4
```

to `rd`.

------------------------------------------------------------------------

### Mistake 5: Treating AUIPC like an ordinary I-type instruction

AUIPC needs:

``` text
PC + immediate
```

not:

``` text
rs1 + immediate
```

------------------------------------------------------------------------

### Mistake 6: Thinking the Control Unit performs the instruction

It doesn't.

The Control Unit only produces signals.

The datapath performs the actual operation.

------------------------------------------------------------------------

# 40. Hardware flow after adding Main Control

Eventually our single-cycle processor will look approximately like:

``` text
                  +----------------+
                  |      PC        |
                  +-------+--------+
                          |
                          v
                  +---------------+
                  | Instruction   |
                  |    Memory     |
                  +-------+-------+
                          |
                  instruction
                          |
          +---------------+---------------+
          |                               |
          v                               v
  +---------------+              +----------------+
  | Main Control  |              | Immediate Gen. |
  +---------------+              +----------------+
          |                               |
          |                               |
          v                               |
  control signals                         |
          |                               |
          +---------------+---------------+
                          |
                          v
                  +---------------+
                  | Register File |
                  +-------+-------+
                          |
                    rs1 / rs2 data
                          |
                          v
                     +---------+
                     |   ALU   |
                     +----+----+
                          |
                          v
                    Data Memory
                          |
                          v
                    Write-back
                          |
                          v
                    Register File
```

Later we will add:

-   ALU Control
-   Data Memory
-   MUXes
-   Branch logic
-   Jump logic
-   Write-back logic
-   Top-level CPU

------------------------------------------------------------------------

# 41. What we should NOT do yet

We should **not** write the complete CPU now.

Current goal:

``` text
Instruction
     ↓
Main Control
     ↓
correct control signals
```

First test this block independently.

Then move to:

``` text
ALU Control Unit
```

After that:

``` text
Data Memory
```

Then:

``` text
MUXes + PC logic
```

Finally:

``` text
riscv_cpu.v
```

------------------------------------------------------------------------

# 42. Final mental model

Remember these three levels:

``` text
LEVEL 1 — Instruction

ADDI x1, x2, 5
        ↓
opcode = 0010011
```

``` text
LEVEL 2 — Main Control

opcode = 0010011
        ↓
ALUSrc = 1
RegWrite = 1
ALUOp = 11
...
```

``` text
LEVEL 3 — ALU Control

ALUOp + funct3 + funct7
        ↓
exact ALU operation
        ↓
ADD
```

This separation keeps the processor design manageable.

------------------------------------------------------------------------

# 43. Summary

The Main Control Unit:

-   receives the instruction,
-   extracts the opcode,
-   identifies the instruction class,
-   generates control signals,
-   does not store data,
-   does not need a clock,
-   does not perform the ALU operation itself.

The most important signals for understanding the design are:

``` text
RegWrite → should register file write?

MemRead  → should memory be read?

MemWrite → should memory be written?

MemToReg → ALU result or memory result?

ALUSrc   → rs2 or immediate for ALU input B?

ALUSrcA  → rs1, PC or zero for ALU input A?

ALUOp    → what class of ALU operation?

Branch   → is this a conditional branch?

Jump     → is this a jump?

Jalr     → is this specifically JALR?
```

------------------------------------------------------------------------

# 44. Next component

After successfully testing this Main Control Unit, the next component
is:

## ALU Control Unit

It will take:

``` text
ALUOp
funct3
funct7
```

and generate the exact 4-bit control code already understood by our ALU:

``` text
0000 ADD
0001 SUB
0010 AND
0011 OR
0100 XOR
0101 SLT
0110 SLL
0111 SRL
1000 SRA
1001 SLTU
```

That will connect the **RISC-V instruction encoding** to the **ALU we
already built**.
