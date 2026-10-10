# ALU Control Unit --- Step-by-Step Guide

## Single-Cycle RISC-V RV32I Processor

> **Previous components completed:** PC, Instruction Memory, Register
> File, ALU, Immediate Generator, Main Control Unit.
>
> **Current component:** ALU Control Unit.
>
> The RISC-V lecture material gives us the instruction fields and
> identifies operations using opcode, funct3 and funct7. The `ALUOp`
> control-signal scheme used below is an implementation choice for our
> single-cycle datapath, not a signal explicitly defined in the lecture
> notes.

------------------------------------------------------------------------

# 1. Why do we need ALU Control?

We already have an ALU.

Our ALU accepts:

``` text
a
b
alu_control
```

where `alu_control` is 4 bits:

``` text
0000 → ADD
0001 → SUB
0010 → AND
0011 → OR
0100 → XOR
0101 → SLT
0110 → SLL
0111 → SRL
1000 → SRA
1001 → SLTU
```

But the RISC-V instruction does not contain these exact 4-bit values.

For example:

``` text
ADD x3, x1, x2
```

contains:

``` text
opcode
funct3
funct7
```

Therefore we need a block that translates:

``` text
RISC-V instruction information
          ↓
      ALU Control
          ↓
4-bit ALU control signal
          ↓
         ALU
```

------------------------------------------------------------------------

# 2. What does the lecture material tell us?

The lecture material explains that the RISC-V instruction operation is
determined using fields such as:

``` text
opcode
funct3
funct7
```

For R-type instructions, the instruction contains:

``` text
funct7 | rs2 | rs1 | funct3 | rd | opcode
```

For example, R-type arithmetic uses opcode:

``` text
0110011
```

and `funct3`/`funct7` distinguish operations such as ADD, SUB, AND, OR,
XOR, shifts and comparisons.

The lecture material does not define our `ALUOp` signal. We use `ALUOp`
because it is useful for dividing the work between:

``` text
Main Control
```

and:

``` text
ALU Control
```

------------------------------------------------------------------------

# 3. Main Control vs ALU Control

This distinction is extremely important.

## Main Control Unit

It looks mainly at the opcode and answers:

> What category of instruction is this?

It produces:

``` text
ALUOp
```

among other control signals.

------------------------------------------------------------------------

## ALU Control Unit

It receives:

``` text
ALUOp
funct3
funct7
```

and answers:

> What exact operation should the ALU perform?

It produces:

``` text
alu_control[3:0]
```

------------------------------------------------------------------------

# 4. Complete flow

``` text
                    Instruction
                        |
             +----------+----------+
             |          |          |
             v          v          v
          opcode      funct3     funct7
             |
             v
      +--------------+
      | Main Control |
      +--------------+
             |
           ALUOp
             |
             +-------------------+
                                 |
                                 v
                       +----------------+
                       |  ALU Control  |
                       |                |
                       | ALUOp          |
                       | funct3         |
                       | funct7         |
                       +-------+--------+
                               |
                         4-bit control
                               |
                               v
                            +-----+
                            | ALU |
                            +-----+
```

------------------------------------------------------------------------

# 5. Why can't Main Control directly decide ADD/SUB/AND/etc.?

Consider:

``` text
ADD
SUB
AND
OR
XOR
SLT
```

All of these are R-type.

They have the same opcode:

``` text
0110011
```

Therefore opcode alone is not enough.

For R-type, we need:

``` text
funct3
funct7
```

Example:

``` text
ADD:
funct7 = 0000000
funct3 = 000
```

while:

``` text
SUB:
funct7 = 0100000
funct3 = 000
```

The opcode is the same.

The ALU Control Unit handles this distinction.

------------------------------------------------------------------------

# 6. Our ALU control codes

These are the codes already used by our ALU:

  ALU Control   Operation
  ------------- -----------
  `0000`        ADD
  `0001`        SUB
  `0010`        AND
  `0011`        OR
  `0100`        XOR
  `0101`        SLT
  `0110`        SLL
  `0111`        SRL
  `1000`        SRA
  `1001`        SLTU

The ALU itself does not know anything about RISC-V opcodes.

It only sees these 4 bits.

------------------------------------------------------------------------

# 7. ALUOp design

Our Main Control Unit generates:

``` text
ALUOp = 00 → ADD/address calculation
ALUOp = 01 → branch comparison
ALUOp = 10 → R-type
ALUOp = 11 → I-type arithmetic
```

This is our processor-design convention.

------------------------------------------------------------------------

# 8. What does ALUOp = 00 mean?

For:

``` text
LW
SW
AUIPC
```

we need addition.

Examples:

``` text
LW  → rs1 + immediate
SW  → rs1 + immediate
AUIPC → PC + immediate
```

Therefore:

``` text
ALUOp = 00
```

means:

``` text
ALU Control = ADD
```

So:

``` text
0000
```

is generated.

------------------------------------------------------------------------

# 9. What does ALUOp = 01 mean?

For a branch such as:

``` text
BEQ x1, x2, offset
```

we need to compare:

``` text
x1 == x2
```

Our ALU can do this by subtraction:

``` text
x1 - x2
```

If the result is zero:

``` text
zero = 1
```

Therefore:

``` text
ALUOp = 01
```

generates:

``` text
SUB = 0001
```

------------------------------------------------------------------------

# 10. What does ALUOp = 10 mean?

This means:

``` text
R-type instruction
```

Now we must inspect:

``` text
funct3
funct7
```

to determine the exact operation.

For example:

``` text
ADD → funct7=0000000, funct3=000
SUB → funct7=0100000, funct3=000
AND → funct7=0000000, funct3=111
OR  → funct7=0000000, funct3=110
```

------------------------------------------------------------------------

# 11. R-type instruction format

The R-type format is:

``` text
31        25 24    20 19    15 14   12 11     7 6      0
+-----------+--------+--------+-------+---------+---------+
|  funct7   |  rs2   |  rs1   |funct3 |   rd    | opcode  |
+-----------+--------+--------+-------+---------+---------+
```

The fields we need are:

``` verilog
instruction[31:25] → funct7
instruction[14:12] → funct3
instruction[6:0]   → opcode
```

------------------------------------------------------------------------

# 12. R-type operation table

For our supported RV32I arithmetic instructions:

  Instruction   funct7      funct3   ALU Control
  ------------- ----------- -------- -------------
  ADD           `0000000`   `000`    `0000`
  SUB           `0100000`   `000`    `0001`
  SLL           `0000000`   `001`    `0110`
  SLT           `0000000`   `010`    `0101`
  SLTU          `0000000`   `011`    `1001`
  XOR           `0000000`   `100`    `0100`
  SRL           `0000000`   `101`    `0111`
  SRA           `0100000`   `101`    `1000`
  OR            `0000000`   `110`    `0011`
  AND           `0000000`   `111`    `0010`

------------------------------------------------------------------------

# 13. Example: ADD

Instruction:

``` text
ADD x3, x1, x2
```

Relevant fields:

``` text
opcode = 0110011
funct3 = 000
funct7 = 0000000
```

Main Control produces:

``` text
ALUOp = 10
```

ALU Control sees:

``` text
ALUOp = 10
funct3 = 000
funct7 = 0000000
```

and produces:

``` text
ALU Control = 0000
```

The ALU therefore performs:

``` text
a + b
```

------------------------------------------------------------------------

# 14. Example: SUB

Instruction:

``` text
SUB x3, x1, x2
```

Relevant fields:

``` text
opcode = 0110011
funct3 = 000
funct7 = 0100000
```

The only important difference from ADD is `funct7`.

ALU Control generates:

``` text
0001
```

Therefore the ALU performs:

``` text
a - b
```

------------------------------------------------------------------------

# 15. Example: AND

``` text
AND x3, x1, x2
```

Fields:

``` text
funct3 = 111
funct7 = 0000000
```

Therefore:

``` text
ALU Control = 0010
```

------------------------------------------------------------------------

# 16. Example: SRA

``` text
SRA x3, x1, x2
```

Fields:

``` text
funct3 = 101
funct7 = 0100000
```

Therefore:

``` text
ALU Control = 1000
```

This selects the signed arithmetic right shift already implemented in
our ALU.

------------------------------------------------------------------------

# 17. I-type arithmetic

For example:

``` text
ADDI x1, x2, 5
```

Opcode:

``` text
0010011
```

Main Control produces:

``` text
ALUOp = 11
```

Now the ALU Control Unit examines `funct3`.

For our supported I-type arithmetic instructions:

  Instruction   funct3   ALU Control
  ------------- -------- ---------------------
  ADDI          `000`    `0000`
  SLLI          `001`    `0110`
  SLTI          `010`    `0101`
  SLTIU         `011`    `1001`
  XORI          `100`    `0100`
  SRLI/SRAI     `101`    depends on `funct7`
  ORI           `110`    `0011`
  ANDI          `111`    `0010`

For ADDI:

``` text
funct3 = 000
```

so:

``` text
ALU Control = 0000
```

------------------------------------------------------------------------

# 18. Why do SRLI and SRAI need funct7?

Both have:

``` text
funct3 = 101
```

But:

``` text
SRLI → logical right shift
SRAI → arithmetic right shift
```

The distinction comes from the upper immediate/funct field.

For our control logic, we can inspect:

``` text
instruction[31:25]
```

or the relevant bit pattern.

For the standard encodings:

``` text
SRLI → 0000000
SRAI → 0100000
```

Therefore:

``` text
funct3 = 101
funct7 = 0000000 → SRL
funct3 = 101
funct7 = 0100000 → SRA
```

------------------------------------------------------------------------

# 19. Load and Store

For:

``` text
LW
SW
```

the ALU calculates an address:

``` text
base register + immediate
```

Therefore Main Control sets:

``` text
ALUOp = 00
```

and ALU Control produces:

``` text
ADD = 0000
```

The ALU does not need to know that the operation is LW or SW.

It simply performs:

``` text
base + offset
```

------------------------------------------------------------------------

# 20. Branch

For:

``` text
BEQ
```

Main Control sets:

``` text
ALUOp = 01
```

ALU Control produces:

``` text
SUB = 0001
```

The ALU calculates:

``` text
rs1 - rs2
```

and its `zero` output tells the branch logic whether they are equal.

------------------------------------------------------------------------

# 21. Unsupported ALU operation

We should always have a default.

For an unsupported combination:

``` text
ALU Control = 0000
```

This gives a safe default of ADD.

However, the Main Control Unit should already prevent unsupported
instruction classes from becoming active processor operations.

------------------------------------------------------------------------

# 22. Hardware flow

The complete ALU-related path is:

``` text
Instruction
    |
    +--------------------+
    |                    |
    v                    v
Main Control        funct3/funct7
    |                    |
    | ALUOp              |
    +--------+-----------+
             |
             v
       ALU Control
             |
             v
      4-bit ALU Control
             |
             v
            ALU
```

------------------------------------------------------------------------

# 23. Verilog design

This is combinational logic.

Therefore:

``` verilog
always @(*)
```

is used.

There is no clock.

The outputs change whenever:

``` text
ALUOp
funct3
funct7
```

change.

------------------------------------------------------------------------

# 24. Inputs

We can make the module accept the complete instruction plus ALUOp:

``` verilog
input wire [31:0] instruction;
input wire [1:0] alu_op;
```

Then internally:

``` verilog
wire [2:0] funct3;
wire [6:0] funct7;

assign funct3 = instruction[14:12];
assign funct7 = instruction[31:25];
```

This keeps the top-level connection simple.

------------------------------------------------------------------------

# 25. Algorithm

### Step 1

Receive:

``` text
instruction
ALUOp
```

### Step 2

Extract:

``` text
funct3
funct7
```

### Step 3

Set a safe default:

``` text
alu_control = ADD
```

### Step 4

Check `ALUOp`.

### Step 5

If:

``` text
ALUOp = 00
```

return ADD.

### Step 6

If:

``` text
ALUOp = 01
```

return SUB.

### Step 7

If:

``` text
ALUOp = 10
```

decode R-type using funct3/funct7.

### Step 8

If:

``` text
ALUOp = 11
```

decode I-type using funct3 and, where needed, funct7.

------------------------------------------------------------------------

# 26. Why not use opcode again?

We could.

But we already used opcode in Main Control.

The purpose of separating the units is:

``` text
Main Control:
opcode → instruction category/control signals

ALU Control:
ALUOp + funct3 + funct7 → exact ALU operation
```

This makes the datapath easier to understand and extend.

------------------------------------------------------------------------

# 27. Testbench

Because this is combinational logic:

-   no clock is needed,
-   no reset is needed.

We simply change:

``` text
instruction
ALUOp
```

and observe:

``` text
alu_control
```

We will test:

1.  ADD
2.  SUB
3.  AND
4.  OR
5.  XOR
6.  SLT
7.  SLTU
8.  SLL
9.  SRL
10. SRA
11. ADDI
12. SLTI
13. SRLI
14. SRAI
15. LW
16. SW
17. BEQ

------------------------------------------------------------------------

# 28. Important relationship with our ALU

Our ALU already contains:

``` verilog
case (alu_control)
```

Therefore we must make sure the ALU Control output exactly matches those
codes.

For example:

``` text
ALU Control = 0000
```

must result in:

``` text
result = a + b
```

because our ALU already defines:

``` text
0000 → ADD
```

We are not changing the ALU.

We are building the block that drives its control input.

------------------------------------------------------------------------

# 29. Common mistakes

### Mistake 1

Thinking `ALUOp = 10` means ADD.

It does not.

In our design:

``` text
ALUOp = 10
```

means:

``` text
R-type
```

Then `funct3/funct7` decide the exact operation.

------------------------------------------------------------------------

### Mistake 2

Ignoring `funct7`.

That would make ADD and SUB impossible to distinguish.

------------------------------------------------------------------------

### Mistake 3

Ignoring `funct7` for SRAI/SRLI.

Both use:

``` text
funct3 = 101
```

so the upper field is needed.

------------------------------------------------------------------------

### Mistake 4

Adding a clock.

The ALU Control Unit is combinational.

------------------------------------------------------------------------

### Mistake 5

Confusing ALU Control with Main Control.

Remember:

``` text
Main Control → broad instruction/datapath control

ALU Control → exact ALU operation
```

------------------------------------------------------------------------

# 30. Final mental model

Think of it like this:

``` text
ADD x3,x1,x2
      |
      v
"R-type"
      |
      v
Main Control
      |
    ALUOp=10
      |
      v
ALU Control
      |
funct3=000
funct7=0000000
      |
      v
ALU Control=0000
      |
      v
ALU → ADD
```

For SUB:

``` text
SUB x3,x1,x2
      |
      v
ALUOp=10
funct3=000
funct7=0100000
      |
      v
ALU Control=0001
      |
      v
ALU → SUB
```

For ADDI:

``` text
ADDI x3,x1,5
      |
      v
ALUOp=11
funct3=000
      |
      v
ALU Control=0000
      |
      v
ALU → ADD
```

------------------------------------------------------------------------

# 31. Next component

After testing ALU Control, the next hardware block is:

## Data Memory

We will build:

``` text
address
write_data
mem_write
mem_read
        |
        v
   Data Memory
        |
        v
   read_data
```

Then we will start building the MUXes and PC-selection logic that
connect all our separate blocks into the single-cycle datapath.
