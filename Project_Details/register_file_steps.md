# Register File Hardware — Complete Step-by-Step Guide
## Single-Cycle RISC-V RV32I Processor in Verilog

This document explains how to design, understand, code, and test the **Register File** for a single-cycle RV32I RISC-V processor.

The goal is not just to copy Verilog code. The goal is to understand:

- what the Register File does inside the CPU,
- why it has 32 registers,
- why register addresses are 5 bits,
- why there are two read ports and one write port,
- why reads can be combinational,
- why writes happen on a clock edge,
- how `x0` is kept permanently equal to zero,
- how Verilog arrays represent hardware registers,
- how the Register File connects to instruction decoding,
- and how to test it without using waveforms.

---

# 1. Where We Are in the CPU

We are building the processor component by component.

So far:

```text
1. Program Counter
2. Instruction Memory
3. Register File   <-- CURRENT COMPONENT
4. ALU
5. Immediate Generator
6. Main Control Unit
7. ALU Control Unit
8. Data Memory
9. MUXes + Branch/Jump Logic
10. Top-Level RISC-V CPU
```

The basic flow will eventually look like:

```text
          +----------------+
          | Program Counter|
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
          | Instruction    |
          | Decode         |
          +---+---------+--+
              |         |
          rs1/rs2       rd
              |         |
              v         |
       +-----------------------+
       |    Register File      |
       |                       |
       | rs1 -> Read Data 1    |
       | rs2 -> Read Data 2    |
       | rd  <- Write Data     |
       +-----------+-----------+
                   |
                   v
                 ALU
```

The Register File is therefore the place where the CPU gets the operands needed by many instructions.

---

# 2. What Is a Register?

A register is a small storage location inside the CPU.

For RV32I:

- There are 32 integer registers.
- They are named `x0` through `x31`.
- Each register is 32 bits wide.
- `x0` is permanently hardwired to zero.

Therefore:

```text
Register File = 32 registers × 32 bits
```

Conceptually:

```text
x0  = 00000000
x1  = 32-bit value
x2  = 32-bit value
x3  = 32-bit value
...
x31 = 32-bit value
```

The RISC-V lecture notes specify that RV32I has 32 registers (`x0`–`x31`), each 32 bits wide, with `x0` hardwired to zero.

---

# 3. Why Does the CPU Need a Register File?

Consider:

```text
ADD x3, x1, x2
```

This means:

```text
x3 = x1 + x2
```

Suppose:

```text
x1 = 10
x2 = 20
```

The CPU needs to:

1. Read x1.
2. Read x2.
3. Send both values to the ALU.
4. ALU calculates `10 + 20`.
5. Write the result `30` into x3.

So the data flow is:

```text
x1 --------\
            \
             ---> Register File ---> ALU ---> x3
            /
x2 --------/
```

The Register File therefore performs two main jobs:

```text
READ  registers
WRITE registers
```

---

# 4. Why Are There Two Read Ports?

Look at:

```text
ADD x3, x1, x2
```

This instruction requires two source operands:

```text
Operand 1 = x1
Operand 2 = x2
```

We want to read both values during the same instruction cycle.

Therefore the Register File has two read ports:

```text
rs1 ----> Read Data 1
rs2 ----> Read Data 2
```

Conceptually:

```text
                 +------------------+
rs1 ------------>|                  |----> read_data1
                 |                  |
rs2 ------------>|  Register File   |----> read_data2
                 |                  |
rd  ------------>|                  |
                 |                  |
write_data ------>|                  |
                 +------------------+
```

The two reads happen independently.

Example:

```text
rs1 = 1
rs2 = 2

read_data1 = registers[1]
read_data2 = registers[2]
```

So if:

```text
x1 = 10
x2 = 20
```

then:

```text
read_data1 = 10
read_data2 = 20
```

---

# 5. Why Is There One Write Port?

An instruction normally writes its result into one destination register.

For example:

```text
ADD x3, x1, x2
```

The destination is:

```text
rd = x3
```

So after the ALU calculates:

```text
ALU result = 30
```

the CPU writes:

```text
x3 = 30
```

The write interface therefore needs:

```text
rd          -> Which register?
write_data  -> What value?
reg_write   -> Should we write?
clk         -> When should we write?
```

Conceptually:

```text
                    write_data
                         |
                         v
                   +-----------+
rd -------------->|           |
reg_write -------->| Register  |
clk -------------->|   File    |
                   +-----------+
```

---

# 6. Register Addresses Are 5 Bits

There are 32 registers:

```text
x0, x1, x2, ..., x31
```

We need to select one of 32 registers.

How many bits are required?

We need:

```text
2^n = 32
```

Therefore:

```text
n = 5
```

So:

```text
rs1 = 5 bits
rs2 = 5 bits
rd  = 5 bits
```

Because:

```text
00000 = register 0 = x0
00001 = register 1 = x1
00010 = register 2 = x2
...
11111 = register 31 = x31
```

This is why register numbers in the instruction are 5 bits.

---

# 7. Important RISC-V Instruction Fields

For an R-type instruction:

```text
31        25 24    20 19    15 14    12 11     7 6      0
+-----------+--------+--------+--------+--------+--------+
|  funct7   |  rs2   |  rs1   | funct3 |   rd   | opcode |
+-----------+--------+--------+--------+--------+--------+
```

Therefore:

```text
rs1 = instruction[19:15]
rs2 = instruction[24:20]
rd  = instruction[11:7]
```

These fields are then connected to the Register File.

So eventually the CPU will do:

```text
instruction[19:15] ---> rs1
instruction[24:20] ---> rs2
instruction[11:7]  ---> rd
```

The Register File then uses these 5-bit values to select registers.

---

# 8. Register File Hardware Interface

A simple Register File needs these ports:

## Inputs

### clk

Clock signal.

Used to control when a register is written.

```verilog
input wire clk;
```

### rs1

First source register number.

```verilog
input wire [4:0] rs1;
```

### rs2

Second source register number.

```verilog
input wire [4:0] rs2;
```

### rd

Destination register number.

```verilog
input wire [4:0] rd;
```

### write_data

Value that should be written into `rd`.

```verilog
input wire [31:0] write_data;
```

### reg_write

Control signal telling the Register File whether a write should happen.

```verilog
input wire reg_write;
```

---

## Outputs

### read_data1

Value stored in the register selected by `rs1`.

```verilog
output wire [31:0] read_data1;
```

### read_data2

Value stored in the register selected by `rs2`.

```verilog
output wire [31:0] read_data2;
```

So the complete interface conceptually is:

```text
                 Register File

        rs1 --------------------> read_data1
        rs2 --------------------> read_data2

        rd
        write_data
        reg_write
        clk
```

---

# 9. The Most Important Concept: Read vs Write Timing

This is one of the most important ideas in the Register File.

We separate:

```text
READ
WRITE
```

## Read

For our simple single-cycle design, register reads are combinational.

That means:

```text
change rs1
     |
     v
read_data1 changes
```

There is no need to wait for a clock edge.

For example:

```text
rs1 = x1
```

immediately selects:

```text
read_data1 = x1's stored value
```

Similarly:

```text
rs2 = x2
```

selects:

```text
read_data2 = x2's stored value
```

---

# 10. Write Is Clocked

Writing is different.

We do not want the register contents changing randomly whenever `rd` or `write_data` changes.

Instead, writing occurs on a clock edge.

Typically:

```verilog
always @(posedge clk)
```

means:

> Run this block whenever the clock changes from 0 to 1.

If:

```text
reg_write = 1
rd = x3
write_data = 30
```

then at the next positive clock edge:

```text
x3 = 30
```

This gives the Register File controlled synchronous storage.

---

# 11. What Does `posedge` Mean?

Suppose the clock is:

```text
0 ---- 1 ---- 0 ---- 1 ---- 0
```

The transition:

```text
0 -> 1
```

is called the positive edge.

So:

```verilog
always @(posedge clk)
```

means:

```text
Do something only when clk goes from 0 to 1.
```

Example:

```text
time      0    5    10   15   20
clk       0    1    0    1    0
                ^         ^
             posedge    posedge
```

The write operation occurs at those positive edges.

---

# 12. Verilog Array for the Register File

We need to represent 32 registers.

A very useful Verilog declaration is:

```verilog
reg [31:0] registers [0:31];
```

This line can look confusing, so break it into two parts.

## `[31:0]`

This means each register is 32 bits wide.

For example:

```text
registers[0] = 32 bits
registers[1] = 32 bits
...
```

## `[0:31]`

This means there are 32 entries:

```text
registers[0]
registers[1]
...
registers[31]
```

Therefore:

```verilog
reg [31:0] registers [0:31];
```

means:

```text
32 registers
|
+-- each register is 32 bits
```

Think of it as:

```text
              32 bits
        <---------------->
registers[0]   000000000...
registers[1]   000000000...
registers[2]   000000000...
...
registers[31]  000000000...
```

---

# 13. Why Is It Called `reg`?

In Verilog, `reg` is used for variables that are assigned procedurally, such as inside:

```verilog
always
```

blocks.

Our Register File storage is updated inside:

```verilog
always @(posedge clk)
```

Therefore:

```verilog
reg [31:0] registers [0:31];
```

is a natural representation.

Important:

`reg` in Verilog does not automatically mean a physical CPU register in every situation. It is a Verilog variable type. The hardware inferred depends on how the variable is used.

In this design, the array is used as register storage.

---

# 14. Why Are Read Outputs `wire`?

The read outputs can be declared as:

```verilog
output wire [31:0] read_data1;
output wire [31:0] read_data2;
```

because the read operation can be expressed as continuous combinational connections.

For example:

```verilog
assign read_data1 = registers[rs1];
assign read_data2 = registers[rs2];
```

The meaning is:

```text
read_data1 always follows registers[rs1]
read_data2 always follows registers[rs2]
```

No clock is required for these reads.

---

# 15. `assign` — Verilog Fundamental

A continuous assignment looks like:

```verilog
assign A = B;
```

It means:

```text
A continuously gets the value of B.
```

For the Register File:

```verilog
assign read_data1 = registers[rs1];
```

means:

```text
select register number rs1
        |
        v
registers[rs1]
        |
        v
read_data1
```

Similarly:

```verilog
assign read_data2 = registers[rs2];
```

means:

```text
select register number rs2
        |
        v
registers[rs2]
        |
        v
read_data2
```

---

# 16. What Does `registers[rs1]` Mean?

Suppose:

```text
rs1 = 5
```

Then:

```verilog
registers[rs1]
```

becomes:

```verilog
registers[5]
```

which means:

```text
value stored in x5
```

If:

```text
rs1 = 10
```

then:

```verilog
registers[rs1]
```

means:

```text
registers[10]
```

So the 5-bit address selects one of the 32 registers.

This is exactly how an indexed register array models a register file.

---

# 17. The Special Rule for x0

RISC-V has an important rule:

```text
x0 is always 0
```

Therefore:

```text
x0 = 0
```

must always remain true.

We have to handle this carefully.

There are two things to guarantee:

## Rule 1: Reading x0 must return zero

If:

```text
rs1 = 0
```

then:

```text
read_data1 = 0
```

If:

```text
rs2 = 0
```

then:

```text
read_data2 = 0
```

## Rule 2: Writing x0 must do nothing

Suppose the CPU tries:

```text
rd = x0
write_data = 99
reg_write = 1
```

We must NOT store:

```text
x0 = 99
```

Instead:

```text
x0 remains 0
```

Therefore the write condition is:

```verilog
if (reg_write && rd != 5'd0)
```

Only registers x1 through x31 can actually be written.

---

# 18. Two Ways to Handle x0

There are two common implementation ideas.

## Method 1 — Explicit read condition

For example:

```verilog
assign read_data1 = (rs1 == 5'd0) ? 32'd0 : registers[rs1];
assign read_data2 = (rs2 == 5'd0) ? 32'd0 : registers[rs2];
```

This says:

```text
If rs1 == 0:
    return 0
otherwise:
    return registers[rs1]
```

And similarly for rs2.

Then during writing:

```verilog
if (reg_write && rd != 5'd0)
    registers[rd] <= write_data;
```

So x0 cannot be overwritten.

## Method 2 — Keep registers[0] explicitly zero

Another idea is to initialize or continuously force the storage for register 0 to zero.

For a beginner-friendly implementation, the explicit read condition plus blocked write is easy to understand and verify.

---

# 19. Should We Initialize All Registers?

For this educational project, initialization is useful for simulation.

Without initialization, registers other than x0 may begin as:

```text
x
```

where `x` means unknown in Verilog simulation.

For example:

```text
read x5
```

could produce:

```text
xxxxxxxx
```

unless x5 has been written first.

This does not necessarily mean real hardware is broken. It means the simulation does not know the starting value.

For clean testing, we can initialize the registers to zero.

One simple simulation-friendly approach is:

```verilog
integer i;

initial begin
    for (i = 0; i < 32; i = i + 1)
        registers[i] = 32'd0;
end
```

Then:

```text
x0 = 0
x1 = 0
x2 = 0
...
x31 = 0
```

At the end, x0 is also protected by the write logic and read logic.

---

# 20. What Is `integer i`?

We use:

```verilog
integer i;
```

as a loop counter.

Then:

```verilog
for (i = 0; i < 32; i = i + 1)
```

means:

```text
i = 0
i = 1
i = 2
...
i = 31
```

So this:

```verilog
for (i = 0; i < 32; i = i + 1)
    registers[i] = 32'd0;
```

initializes all 32 registers.

---

# 21. Why Does the Register File Have No Reset Port Here?

There are multiple design choices.

For this simple educational Register File, we can omit reset from the module and use an `initial` block for simulation initialization.

The important architectural behavior is:

```text
x0 must always read as 0
writes happen only when reg_write = 1
writes happen on posedge clk
```

Later, depending on the exact FPGA/ASIC target, reset/initialization can be designed differently.

For this project, the simple approach keeps the hardware easier to understand.

---

# 22. Complete Register File Design

After understanding every part, the module can be written as:

```verilog
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

    reg [31:0] registers [0:31];

    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 32'd0;
    end

    assign read_data1 = (rs1 == 5'd0) ? 32'd0 : registers[rs1];
    assign read_data2 = (rs2 == 5'd0) ? 32'd0 : registers[rs2];

    always @(posedge clk) begin
        if (reg_write && rd != 5'd0)
            registers[rd] <= write_data;
    end

endmodule
```

---

# 23. Understand the Module Line by Line

## Module declaration

```verilog
module register_file (
```

Starts the Register File module.

---

## Clock

```verilog
input wire clk,
```

The clock controls when writing occurs.

---

## First source register

```verilog
input wire [4:0] rs1,
```

5-bit address selecting the first register to read.

---

## Second source register

```verilog
input wire [4:0] rs2,
```

5-bit address selecting the second register to read.

---

## Destination register

```verilog
input wire [4:0] rd,
```

5-bit address selecting the register that should receive the result.

---

## Data to write

```verilog
input wire [31:0] write_data,
```

32-bit value that will be stored in `rd`.

---

## Write enable

```verilog
input wire reg_write,
```

If:

```text
reg_write = 1
```

the CPU is requesting a register write.

If:

```text
reg_write = 0
```

no register is written.

---

## Read output 1

```verilog
output wire [31:0] read_data1,
```

Contains the value of the register selected by rs1.

---

## Read output 2

```verilog
output wire [31:0] read_data2
```

Contains the value of the register selected by rs2.

---

# 24. Storage Declaration

```verilog
reg [31:0] registers [0:31];
```

This creates:

```text
32 entries
```

where each entry is:

```text
32 bits
```

So:

```text
registers[0]  -> x0
registers[1]  -> x1
...
registers[31] -> x31
```

---

# 25. Initialization

```verilog
integer i;
```

Creates a loop variable.

Then:

```verilog
initial begin
    for (i = 0; i < 32; i = i + 1)
        registers[i] = 32'd0;
end
```

sets every register to zero at simulation start.

This makes testing easier.

---

# 26. First Read Port

```verilog
assign read_data1 = (rs1 == 5'd0) ? 32'd0 : registers[rs1];
```

This uses the Verilog conditional operator:

```text
condition ? value_if_true : value_if_false
```

So:

```verilog
(rs1 == 5'd0)
```

checks whether rs1 is x0.

If yes:

```text
read_data1 = 0
```

Otherwise:

```text
read_data1 = registers[rs1]
```

---

# 27. Second Read Port

```verilog
assign read_data2 = (rs2 == 5'd0) ? 32'd0 : registers[rs2];
```

Same logic for rs2.

---

# 28. Write Logic

```verilog
always @(posedge clk) begin
```

The block executes on every rising edge of the clock.

Then:

```verilog
if (reg_write && rd != 5'd0)
```

means:

```text
write only if:
    reg_write = 1
AND
    rd is not x0
```

Then:

```verilog
registers[rd] <= write_data;
```

stores the value.

---

# 29. Why Use `<=` Instead of `=`?

For clocked/sequential logic, use the non-blocking assignment:

```verilog
<=
```

Example:

```verilog
registers[rd] <= write_data;
```

This models synchronous hardware behavior more appropriately.

You will see:

```verilog
=
```

commonly used in combinational/procedural calculations and:

```verilog
<=
```

commonly used in clocked sequential logic.

A useful beginner rule:

```text
Clocked always block -> usually <=
Combinational procedural block -> usually =
```

---

# 30. Register File Example

Suppose initially:

```text
x1 = 0
x2 = 0
x3 = 0
```

We want:

```text
x1 = 10
x2 = 20
```

We set:

```text
rd = 1
write_data = 10
reg_write = 1
```

At the rising clock edge:

```text
x1 = 10
```

Then:

```text
rd = 2
write_data = 20
reg_write = 1
```

At the next rising edge:

```text
x2 = 20
```

Now set:

```text
rs1 = 1
rs2 = 2
```

Immediately:

```text
read_data1 = 10
read_data2 = 20
```

The ALU can then perform:

```text
10 + 20 = 30
```

and eventually write:

```text
x3 = 30
```

---

# 31. Register File and ADD Instruction

Consider:

```text
ADD x3, x1, x2
```

The instruction contains:

```text
rs1 = x1
rs2 = x2
rd  = x3
```

The Register File receives:

```text
rs1 = 1
rs2 = 2
```

and outputs:

```text
read_data1 = x1
read_data2 = x2
```

The ALU receives:

```text
ALU input A = read_data1
ALU input B = read_data2
```

and calculates:

```text
x1 + x2
```

The result eventually returns to the Register File:

```text
write_data = ALU result
rd = 3
reg_write = 1
```

At the clock edge:

```text
x3 = ALU result
```

Complete flow:

```text
Instruction
     |
     +----------------------+
     |                      |
     v                      v
    rs1                    rs2
     |                      |
     +----------+-----------+
                |
                v
        +---------------+
        | Register File |
        +-------+-------+
                |
       read_data1/read_data2
                |
                v
              ALU
                |
                | result
                v
          write_data
                |
                v
        Register File
             rd=x3
```

---

# 32. Register File Testbench

We will test the Register File separately before connecting it to the rest of the CPU.

We do NOT need GTKWave for this test.

Terminal output using `$monitor` is enough.

Testbench:

```verilog
`timescale 1ns/1ps

module tb_register_file;

    reg clk;

    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;

    reg [31:0] write_data;
    reg reg_write;

    wire [31:0] read_data1;
    wire [31:0] read_data2;

    register_file dut (
        .clk(clk),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(write_data),
        .reg_write(reg_write),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    always #5 clk = ~clk;

    initial begin

        clk = 1'b0;

        rs1 = 5'd0;
        rs2 = 5'd0;

        rd = 5'd0;
        write_data = 32'd0;
        reg_write = 1'b0;

        $monitor("Time=%0t | rs1=%0d | rs2=%0d | read1=%0d | read2=%0d | rd=%0d | write_data=%0d | reg_write=%b",
                 $time, rs1, rs2, read_data1, read_data2,
                 rd, write_data, reg_write);

        // Test 1: x0 must always read as 0
        #2;
        rs1 = 5'd0;
        rs2 = 5'd0;

        // Test 2: write 10 into x1
        #8;
        rd = 5'd1;
        write_data = 32'd10;
        reg_write = 1'b1;

        #2;
        reg_write = 1'b0;

        // Test 3: read x1
        rs1 = 5'd1;
        rs2 = 5'd1;

        // Test 4: write 20 into x2
        #8;
        rd = 5'd2;
        write_data = 32'd20;
        reg_write = 1'b1;

        #2;
        reg_write = 1'b0;

        // Test 5: read x1 and x2 simultaneously
        rs1 = 5'd1;
        rs2 = 5'd2;

        // Test 6: try to write 99 into x0
        #8;
        rd = 5'd0;
        write_data = 32'd99;
        reg_write = 1'b1;

        #2;
        reg_write = 1'b0;

        // Test 7: x0 must still be 0
        rs1 = 5'd0;
        rs2 = 5'd0;

        #10;

        $finish;

    end

endmodule
```

---

# 33. Understand the Testbench Clock

We use:

```verilog
always #5 clk = ~clk;
```

This means:

```text
every 5 ns:
    invert clk
```

So:

```text
0 ns  -> clk = 0
5 ns  -> clk = 1
10 ns -> clk = 0
15 ns -> clk = 1
20 ns -> clk = 0
...
```

The positive edges occur at:

```text
5 ns
15 ns
25 ns
35 ns
...
```

The Register File performs writes at these positive edges.

---

# 34. Why Are Testbench Signals `reg`?

In the testbench, we write values such as:

```verilog
rs1 = 5'd1;
rs2 = 5'd2;
reg_write = 1'b1;
```

These are assigned from the testbench's `initial` block.

Therefore they need to be variables that the testbench can drive.

So:

```verilog
reg clk;
reg [4:0] rs1;
reg [4:0] rs2;
reg [4:0] rd;
reg [31:0] write_data;
reg reg_write;
```

are used.

The outputs from the Register File are driven by the module:

```verilog
wire [31:0] read_data1;
wire [31:0] read_data2;
```

The testbench only observes them.

---

# 35. Test 1 — Read x0

Set:

```text
rs1 = 0
rs2 = 0
```

Expected:

```text
read_data1 = 0
read_data2 = 0
```

This verifies the x0 rule.

---

# 36. Test 2 — Write x1 = 10

Set:

```text
rd = 1
write_data = 10
reg_write = 1
```

At a rising edge:

```text
x1 = 10
```

Then disable writing:

```text
reg_write = 0
```

---

# 37. Test 3 — Read x1

Set:

```text
rs1 = 1
rs2 = 1
```

Expected:

```text
read_data1 = 10
read_data2 = 10
```

This proves the write was successful.

---

# 38. Test 4 — Write x2 = 20

Set:

```text
rd = 2
write_data = 20
reg_write = 1
```

At the next rising edge:

```text
x2 = 20
```

---

# 39. Test 5 — Simultaneous Two-Port Read

Set:

```text
rs1 = 1
rs2 = 2
```

Expected:

```text
read_data1 = 10
read_data2 = 20
```

This is a very important test.

It proves the Register File can read two registers at the same time.

---

# 40. Test 6 — Attempt to Write x0

Set:

```text
rd = 0
write_data = 99
reg_write = 1
```

The Register File should ignore the write.

It must NOT become:

```text
x0 = 99
```

---

# 41. Test 7 — Verify x0 Again

Read:

```text
rs1 = 0
rs2 = 0
```

Expected:

```text
read_data1 = 0
read_data2 = 0
```

Even after trying to write 99 into x0.

This confirms that x0 is protected.

---

# 42. Compile the Register File

Assuming your project structure is:

```text
RISCV/
├── rtl/
│   ├── program_counter.v
│   ├── instruction_memory.v
│   └── register_file.v
│
└── tb/
    ├── tb_program_counter.v
    ├── tb_instruction_memory.v
    └── tb_register_file.v
```

From the project directory:

```powershell
iverilog -o regfile_sim rtl/register_file.v tb/tb_register_file.v
```

Then:

```powershell
vvp regfile_sim
```

---

# 43. What Output Should You Look For?

The exact timestamps can depend on the testbench scheduling, but the important values are:

First:

```text
x0 read -> 0
```

After writing x1:

```text
x1 read -> 10
```

After writing x2:

```text
x2 read -> 20
```

Simultaneous read:

```text
read1 = 10
read2 = 20
```

After attempted x0 write:

```text
x0 read -> 0
```

The most important thing is the behavior, not matching every timestamp character-for-character.

---

# 44. A More Focused Expected Behavior Table

| Operation | Expected Result |
|---|---|
| Read x0 | 0 |
| Write x1 = 10 | x1 becomes 10 on posedge |
| Read x1 | 10 |
| Write x2 = 20 | x2 becomes 20 on posedge |
| Read x1 and x2 | 10 and 20 |
| Attempt x0 = 99 | Ignored |
| Read x0 again | 0 |

---

# 45. Important Difference: Read Is Immediate, Write Is Clocked

This is one of the most important things to remember.

Suppose:

```text
rs1 = x1
```

and x1 already contains:

```text
10
```

Then:

```text
read_data1 = 10
```

without waiting for a clock.

But if you request:

```text
rd = x3
write_data = 30
reg_write = 1
```

x3 changes only when:

```text
posedge clk
```

occurs.

So:

```text
READ  -> combinational
WRITE -> clocked
```

for this design.

---

# 46. Why This Works Well for a Single-Cycle CPU

In a single-cycle processor, an instruction is processed within one clock cycle.

For an instruction such as:

```text
ADD x3, x1, x2
```

the CPU can:

```text
1. Fetch instruction
2. Decode instruction
3. Read x1 and x2
4. Perform ALU operation
5. Write result to x3 at clock edge
```

The Register File supports this by providing two operand values during the cycle and accepting the result at the clock edge.

Conceptually:

```text
Clock cycle
---------------------------------------------------->

Instruction
     |
     v
Decode
     |
     v
Read x1/x2
     |
     v
ALU
     |
     v
Result
     |
     v
Write x3
     |
     v
Next cycle
```

---

# 47. Register File in the Final CPU

Eventually the top-level CPU will connect:

```text
instruction[19:15] -> rs1
instruction[24:20] -> rs2
instruction[11:7]  -> rd
```

Then:

```text
rs1 -> Register File
rs2 -> Register File
```

and:

```text
Register File
    |
    +--> read_data1
    |
    +--> read_data2
```

These values go to the ALU.

The ALU result returns through the write-back path:

```text
ALU result
    |
    v
write_data
    |
    v
Register File
    |
    v
rd
```

A control unit will later generate:

```text
reg_write
```

to decide whether the instruction should actually write a register.

---

# 48. Example: ADDI

Consider:

```text
ADDI x1, x0, 5
```

Meaning:

```text
x1 = x0 + 5
```

Since:

```text
x0 = 0
```

the result is:

```text
x1 = 5
```

The Register File provides:

```text
rs1 = x0
```

so:

```text
read_data1 = 0
```

The immediate generator provides:

```text
5
```

The ALU calculates:

```text
0 + 5 = 5
```

Then the write-back path sends:

```text
rd = x1
write_data = 5
reg_write = 1
```

At the clock edge:

```text
x1 = 5
```

This shows how the Register File will work with the Immediate Generator and ALU.

---

# 49. Example: ADD

For:

```text
ADD x3, x1, x2
```

Suppose:

```text
x1 = 10
x2 = 20
```

Register File:

```text
rs1 = 1
rs2 = 2

read_data1 = 10
read_data2 = 20
```

ALU:

```text
10 + 20 = 30
```

Write-back:

```text
rd = 3
write_data = 30
reg_write = 1
```

At the clock edge:

```text
x3 = 30
```

---

# 50. Common Mistakes

## Mistake 1 — Making rs1/rs2 32 bits

Wrong for register number:

```verilog
input wire [31:0] rs1;
```

Correct:

```verilog
input wire [4:0] rs1;
```

Why?

There are only 32 registers, so 5 bits are enough.

---

## Mistake 2 — Forgetting x0

If you simply do:

```verilog
assign read_data1 = registers[rs1];
```

and allow:

```verilog
registers[rd] <= write_data;
```

for every rd, then x0 could potentially be changed.

We must protect x0.

---

## Mistake 3 — Writing without a clock

Do not treat register writes as continuously changing storage.

Use:

```verilog
always @(posedge clk)
```

for the write operation.

---

## Mistake 4 — Using `=` in the clocked write

Prefer:

```verilog
registers[rd] <= write_data;
```

for sequential logic.

---

## Mistake 5 — Having only one read port

An instruction like:

```text
ADD x3, x1, x2
```

needs both x1 and x2.

So we need:

```text
read_data1
read_data2
```

---

## Mistake 6 — Confusing register number with register value

This is extremely important.

```text
rs1 = 5
```

does NOT mean:

```text
x1 contains 5
```

It means:

```text
select register x5
```

Similarly:

```text
rd = 3
```

means:

```text
destination is x3
```

while:

```text
write_data = 30
```

means:

```text
the value to store is 30
```

---

# 51. Very Important Terminology

Keep these concepts separate:

```text
rs1
```

= first source register number.

```text
rs2
```

= second source register number.

```text
rd
```

= destination register number.

```text
read_data1
```

= value stored in rs1.

```text
read_data2
```

= value stored in rs2.

```text
write_data
```

= value that will be stored into rd.

Example:

```text
ADD x3, x1, x2
```

means:

```text
rs1 = 1
rs2 = 2
rd  = 3
```

If:

```text
x1 = 10
x2 = 20
```

then:

```text
read_data1 = 10
read_data2 = 20
```

ALU result:

```text
30
```

and:

```text
write_data = 30
```

Then:

```text
x3 = 30
```

---

# 52. Final Hardware Picture

The Register File can be visualized as:

```text
                     REGISTER FILE
              +-------------------------+
              |                         |
       rs1 -->|                         |--> read_data1
              |                         |
       rs2 -->|   32 x 32-bit          |--> read_data2
              |   Registers             |
              |                         |
        rd -->|                         |
              |                         |
 write_data ->|                         |
              |                         |
  reg_write ->|                         |
              |                         |
       clk -->|                         |
              +-------------------------+

              x0 is permanently 0
```

---

# 53. Final CPU-Level Picture

After Register File is completed, our processor path is becoming:

```text
              +-------------------+
              | Program Counter   |
              +---------+---------+
                        |
                        v
              +-------------------+
              | Instruction       |
              | Memory            |
              +---------+---------+
                        |
                        v
                 32-bit Instruction
                        |
                        v
              +-------------------+
              | Instruction       |
              | Decode            |
              +---------+---------+
                        |
              +---------+---------+
              |                   |
             rs1                 rs2
              |                   |
              v                   v
         +---------------------------+
         |       Register File       |
         |                           |
         | read_data1   read_data2   |
         +-------------+-------------+
                       |
                       v
                     ALU
                       |
                       v
                   Result
                       |
                       v
                 Write-back
                       |
                       v
                 Register File
```

---

# 54. What You Should Understand Before Moving On

Before moving to the ALU, make sure you can answer these questions:

### Q1. Why are there 32 registers?

Because RV32I defines 32 integer registers:

```text
x0-x31
```

### Q2. Why are rs1, rs2, and rd 5 bits?

Because:

```text
2^5 = 32
```

so 5 bits can select one of 32 registers.

### Q3. Why are there two read ports?

Because instructions such as:

```text
ADD x3, x1, x2
```

need two source operands simultaneously.

### Q4. Why is write clocked?

To make register state change synchronously at a clock edge.

### Q5. Why is x0 special?

RISC-V defines x0 as permanently zero.

### Q6. What does this mean?

```verilog
registers[rd] <= write_data;
```

It means:

```text
Store write_data into the register selected by rd.
```

### Q7. What does this mean?

```verilog
assign read_data1 = registers[rs1];
```

It means:

```text
read the register selected by rs1.
```

### Q8. What is the difference between rs1 and read_data1?

```text
rs1        = register number
read_data1 = value stored in that register
```

---

# 55. Final Checklist

Before declaring Register File complete:

- [ ] 32 registers are represented.
- [ ] Each register is 32 bits.
- [ ] rs1 is 5 bits.
- [ ] rs2 is 5 bits.
- [ ] rd is 5 bits.
- [ ] There are two read ports.
- [ ] There is one write port.
- [ ] Reads are combinational.
- [ ] Writes happen on `posedge clk`.
- [ ] `reg_write` controls writing.
- [ ] x0 reads as zero.
- [ ] Attempts to write x0 are ignored.
- [ ] Testbench verifies x0.
- [ ] Testbench writes x1.
- [ ] Testbench writes x2.
- [ ] Testbench reads two registers simultaneously.
- [ ] Compilation succeeds.
- [ ] Terminal output confirms expected values.

---

# 56. Component Status

After completing this component:

```text
[✓] Program Counter
[✓] Instruction Memory
[✓] Register File
[ ] ALU
[ ] Immediate Generator
[ ] Main Control Unit
[ ] ALU Control Unit
[ ] Data Memory
[ ] MUXes + Branch/Jump Logic
[ ] Top-Level CPU
```

The next hardware component is the **ALU (Arithmetic Logic Unit)**.

The ALU will receive values from the Register File and perform operations such as:

```text
ADD
SUB
AND
OR
XOR
SLT
SLL
SRL
SRA
```

which correspond to the RV32I arithmetic/logic instructions.
