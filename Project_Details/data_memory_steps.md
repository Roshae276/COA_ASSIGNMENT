# Data Memory --- Step-by-Step Guide

## Single-Cycle RISC-V RV32I Processor

> **Project stage:** PC → Instruction Memory → Register File → ALU →
> Immediate Generator → Main Control → ALU Control → **Data Memory**
>
> This component is mainly needed for `LW` and `SW`.

------------------------------------------------------------------------

# 1. What is Data Memory?

RISC-V is a **load-store architecture**.

That means normal arithmetic instructions operate on registers:

``` text
ADD
SUB
AND
OR
...
```

Memory is accessed by dedicated instructions:

``` text
LW  → Load Word
SW  → Store Word
```

So our processor needs a separate **Data Memory** block.

------------------------------------------------------------------------

# 2. What does the lecture material tell us?

The RISC-V lecture material states that:

-   Memory is byte-addressable.
-   A word is 32 bits = 4 bytes.
-   RV32I uses 32-bit registers.
-   Memory is little-endian.

Therefore, in our simple RV32I processor:

``` text
1 word = 32 bits = 4 bytes
```

and word addresses are aligned on multiples of 4.

For this project we will implement a simple 32-bit word-oriented memory
model.

------------------------------------------------------------------------

# 3. Why is Data Memory separate from Instruction Memory?

We already built:

``` text
Instruction Memory
```

Its job is:

``` text
PC address → instruction
```

Data Memory has a different job:

``` text
CPU address → data
```

For example:

``` text
LW x5, 8(x2)
```

uses the ALU to calculate:

``` text
address = x2 + 8
```

Then Data Memory reads the value stored at that address.

------------------------------------------------------------------------

# 4. Basic hardware

Our Data Memory will have:

``` text
address
write_data
mem_read
mem_write
     |
     v
+-------------+
| Data Memory |
+-------------+
     |
     v
read_data
```

Inputs:

``` text
address
write_data
mem_read
mem_write
clk
```

Output:

``` text
read_data
```

------------------------------------------------------------------------

# 5. Why do we need a clock?

There are two different operations:

### Reading

Reading memory will be combinational in our simple design.

That means:

``` text
address changes
      ↓
read_data changes
```

No clock is required for the read itself.

### Writing

Writing should happen on a clock edge.

We use:

``` verilog
always @(posedge clk)
```

This means:

> At the rising edge of the clock, if `mem_write` is enabled, store the
> data.

------------------------------------------------------------------------

# 6. LW instruction

Consider:

``` text
LW x5, 8(x2)
```

This means:

``` text
x5 = Memory[x2 + 8]
```

The processor performs:

``` text
1. Register File reads x2.
2. Immediate Generator produces 8.
3. ALU calculates x2 + 8.
4. Data Memory receives that address.
5. Data Memory returns the stored word.
6. Register File writes that word into x5.
```

Hardware flow:

``` text
x2
 |
 v
Register File
 |
 +------+
        |
        v
       ALU <----- immediate 8
        |
        | address
        v
   Data Memory
        |
        | read_data
        v
   Register File
        |
        v
       x5
```

------------------------------------------------------------------------

# 7. SW instruction

Consider:

``` text
SW x5, 8(x2)
```

This means:

``` text
Memory[x2 + 8] = x5
```

Flow:

``` text
x2
 |
 v
Register File
 |
 v
 ALU <----- immediate 8
 |
 | address
 v
Data Memory
 ^
 |
write_data = x5
```

At the rising clock edge:

``` text
memory[address] = write_data
```

if:

``` text
MemWrite = 1
```

------------------------------------------------------------------------

# 8. `mem_read`

`mem_read` tells the Data Memory whether the processor wants to read
data.

For:

``` text
LW
```

we set:

``` text
mem_read = 1
```

For:

``` text
SW
ADD
SUB
BEQ
...
```

we normally set:

``` text
mem_read = 0
```

In our model, when `mem_read = 0`, `read_data` will be `0`.

This is a design choice that makes simulation easy to understand.

------------------------------------------------------------------------

# 9. `mem_write`

`mem_write` tells the Data Memory whether it should write.

For:

``` text
SW
```

we set:

``` text
mem_write = 1
```

For other instructions:

``` text
mem_write = 0
```

------------------------------------------------------------------------

# 10. Memory array

We will create:

``` verilog
reg [31:0] memory [0:255];
```

This means:

``` text
256 locations
```

and each location stores:

``` text
32 bits
```

So total storage in this simple model is:

``` text
256 × 32 bits
= 8192 bits
= 1024 bytes
= 1 KB
```

This is a small simulation memory, not a representation of the entire
physical RAM of a real computer.

------------------------------------------------------------------------

# 11. Why address\[31:2\]?

This is one of the most important points.

A word is:

``` text
4 bytes
```

Therefore aligned word addresses are:

``` text
0
4
8
12
16
...
```

But our array indices are:

``` text
0
1
2
3
4
...
```

So we convert byte address to word index by removing the lowest two
bits:

``` text
address[31:2]
```

because:

``` text
4 bytes = 2^2 bytes
```

Example:

``` text
Byte address 0
000...0000
      ↓
memory[0]

Byte address 4
000...0100
      ↓
memory[1]

Byte address 8
000...1000
      ↓
memory[2]

Byte address 12
000...1100
      ↓
memory[3]
```

Therefore:

``` verilog
memory[address[31:2]]
```

selects the correct 32-bit word.

------------------------------------------------------------------------

# 12. What about address 1, 2, or 3?

Those are byte offsets inside the first word.

Our simple Data Memory is designed for **word-aligned LW/SW**.

For RV32I `LW` and `SW`, the effective address should be aligned
appropriately for a word access.

Therefore we use:

``` text
address[31:2]
```

and do not implement byte/halfword access in this basic block.

If later we implement `LB`, `LH`, `SB`, `SH`, we would need additional
byte-selection and sign/zero-extension logic.

------------------------------------------------------------------------

# 13. Read logic

The read logic will be:

``` verilog
assign read_data =
    mem_read ? memory[address[31:2]] : 32'd0;
```

Meaning:

``` text
if mem_read = 1
    read_data = selected memory word

if mem_read = 0
    read_data = 0
```

This is combinational logic.

------------------------------------------------------------------------

# 14. Write logic

The write logic will be:

``` verilog
always @(posedge clk) begin
    if (mem_write)
        memory[address[31:2]] <= write_data;
end
```

Meaning:

``` text
At every rising edge:

if mem_write == 1
    store write_data
```

The nonblocking assignment:

``` verilog
<=
```

is used because this is sequential/clocked hardware.

------------------------------------------------------------------------

# 15. Initial memory values

For testing, we need some known data.

We can initialize:

``` verilog
memory[0] = 32'd100;
memory[1] = 32'd200;
memory[2] = 32'd300;
memory[3] = 32'd400;
```

Therefore:

``` text
Address 0  → 100
Address 4  → 200
Address 8  → 300
Address 12 → 400
```

This allows us to test LW immediately.

------------------------------------------------------------------------

# 16. Important distinction: address vs array index

Suppose:

``` text
address = 8
```

The CPU is using a **byte address**.

The memory array receives:

``` text
address[31:2]
```

which gives:

``` text
2
```

Therefore:

``` text
memory[2]
```

is selected.

So:

``` text
CPU address 8 → memory array index 2
```

This is correct because each array entry represents a 4-byte word.

------------------------------------------------------------------------

# 17. Test 1 --- Read address 0

Set:

``` text
address = 0
mem_read = 1
```

Expected:

``` text
read_data = 100
```

because:

``` text
memory[0] = 100
```

------------------------------------------------------------------------

# 18. Test 2 --- Read address 4

Set:

``` text
address = 4
mem_read = 1
```

Then:

``` text
address[31:2] = 1
```

so:

``` text
read_data = memory[1]
          = 200
```

------------------------------------------------------------------------

# 19. Test 3 --- Read address 8

Set:

``` text
address = 8
mem_read = 1
```

Then:

``` text
address[31:2] = 2
```

Expected:

``` text
read_data = 300
```

------------------------------------------------------------------------

# 20. Test 4 --- Write

Suppose:

``` text
address = 16
write_data = 999
mem_write = 1
```

At the next rising clock edge:

``` text
memory[4] = 999
```

because:

``` text
16 / 4 = 4
```

After the write, set:

``` text
mem_write = 0
mem_read = 1
address = 16
```

Expected:

``` text
read_data = 999
```

This verifies both the write and read paths.

------------------------------------------------------------------------

# 21. Why does write happen on a clock edge?

Because a memory write changes stored state.

Think of it like the Register File we already built:

``` text
Register File write
        ↓
posedge clk
```

Similarly:

``` text
Data Memory write
        ↓
posedge clk
```

Reading is combinational in our simple model.

------------------------------------------------------------------------

# 22. Data Memory and Register File comparison

Both contain stored data.

### Register File

``` text
32 registers × 32 bits
```

### Data Memory

Our simulation memory:

``` text
256 words × 32 bits
```

Both use:

``` text
reg [31:0]
```

But their roles are different:

``` text
Register File → x0 to x31
Data Memory   → program data
```

------------------------------------------------------------------------

# 23. Data Memory and Instruction Memory comparison

### Instruction Memory

``` text
address → instruction
```

It is initialized with program instructions.

### Data Memory

``` text
address → data
```

It supports writing data as well as reading data.

So:

``` text
Instruction Memory
        ↓
   instructions

Data Memory
        ↓
      data
```

------------------------------------------------------------------------

# 24. No reset input

We don't need a reset input in this simple Data Memory module.

Why?

The PC needs reset because the processor must know where to start.

The register file needs x0 initialization behavior.

Data Memory does not need reset for our basic design because we
initialize selected test locations in an `initial` block.

In a real hardware implementation, memory initialization depends on the
actual memory technology and FPGA/ASIC design.

------------------------------------------------------------------------

# 25. Verilog module structure

The module will contain:

``` verilog
module data_memory (
    input wire clk,
    input wire mem_read,
    input wire mem_write,
    input wire [31:0] address,
    input wire [31:0] write_data,
    output wire [31:0] read_data
);
```

Then:

``` verilog
reg [31:0] memory [0:255];
```

Then initialize some test data.

Then:

``` verilog
assign read_data = ...
```

Then:

``` verilog
always @(posedge clk)
```

for writes.

------------------------------------------------------------------------

# 26. Why is `read_data` a wire?

The read output is generated using:

``` verilog
assign
```

Therefore it is a continuous assignment.

So:

``` verilog
output wire [31:0] read_data;
```

is appropriate.

------------------------------------------------------------------------

# 27. Why is `memory` a reg?

The memory array stores state:

``` verilog
reg [31:0] memory [0:255];
```

Its contents can change when the clocked write block executes.

------------------------------------------------------------------------

# 28. Testbench strategy

The testbench will test:

1.  Read address 0.
2.  Read address 4.
3.  Read address 8.
4.  Read address 12.
5.  Write a new value.
6.  Read the newly written value.
7.  Confirm `mem_read = 0` gives zero.
8.  Confirm writing happens at the clock edge.

The testbench needs a clock because memory writes happen on:

``` text
posedge clk
```

------------------------------------------------------------------------

# 29. Clock generation

We can use:

``` verilog
always #5 clk = ~clk;
```

This gives:

``` text
0 → 5 ns → 10 ns → 15 ns → ...
```

with a rising edge every 10 ns.

The important point is not the exact 10 ns value. The important point is
that the write occurs at a rising edge.

------------------------------------------------------------------------

# 30. Expected sequence

The testbench will roughly do:

``` text
Read address 0
      ↓
100

Read address 4
      ↓
200

Read address 8
      ↓
300

Write 999 to address 16
      ↓
posedge clk

Read address 16
      ↓
999
```

------------------------------------------------------------------------

# 31. Common mistakes

### Mistake 1 --- Using memory\[address\]

Wrong for our word array:

``` verilog
memory[address]
```

because `address` is a byte address.

Use:

``` verilog
memory[address[31:2]]
```

------------------------------------------------------------------------

### Mistake 2 --- Writing without a clock

Do not use a normal continuous assignment for memory writes.

Use:

``` verilog
always @(posedge clk)
```

------------------------------------------------------------------------

### Mistake 3 --- Reading with posedge

Our simple memory uses combinational reads:

``` verilog
assign read_data = ...
```

------------------------------------------------------------------------

### Mistake 4 --- Forgetting mem_write

Without:

``` verilog
if (mem_write)
```

every clock edge could overwrite memory.

------------------------------------------------------------------------

### Mistake 5 --- Confusing write_data and read_data

For:

``` text
SW
```

data flows:

``` text
Register File → Data Memory
```

so we use:

``` text
write_data
```

For:

``` text
LW
```

data flows:

``` text
Data Memory → Register File
```

so we use:

``` text
read_data
```

------------------------------------------------------------------------

# 32. Complete LW flow

For:

``` text
LW x5, 8(x2)
```

the complete path is:

``` text
Instruction
    |
    +------------------+
    |                  |
    v                  v
Main Control     Immediate Gen.
    |                  |
MemRead=1          imm=8
ALUSrc=1               |
    |                  |
    +--------+---------+
             |
             v
        Register File
             |
            x2
             |
             v
            ALU
             |
       x2 + 8
             |
             v
       Data Memory
             |
         read_data
             |
             v
       Write-back MUX
             |
             v
            x5
```

------------------------------------------------------------------------

# 33. Complete SW flow

For:

``` text
SW x5, 8(x2)
```

the path is:

``` text
Instruction
    |
    +------------------+
    |                  |
    v                  v
Main Control     Immediate Gen.
    |                  |
MemWrite=1         imm=8
ALUSrc=1               |
    |                  |
    +--------+---------+
             |
             v
        Register File
        /           \
      x2             x5
       |              |
       v              v
      ALU         write_data
       |
     x2 + 8
       |
       v
 address
       |
       v
 Data Memory
```

At the rising clock edge:

``` text
Memory[address] = x5
```

------------------------------------------------------------------------

# 34. How this connects to our existing components

We already have:

``` text
Main Control
```

which generates:

``` text
MemRead
MemWrite
```

We already have:

``` text
ALU
```

which calculates the effective address.

We already have:

``` text
Immediate Generator
```

which creates the offset.

Now Data Memory provides the actual:

``` text
load/store data
```

So after this block:

``` text
LW/SW
```

will have almost all their required hardware.

------------------------------------------------------------------------

# 35. Final mental model

Remember:

``` text
LW:
address → memory → register

SW:
register → memory
```

More specifically:

``` text
LW x5, 8(x2)

address = x2 + 8
x5 = memory[address]
```

and:

``` text
SW x5, 8(x2)

address = x2 + 8
memory[address] = x5
```

------------------------------------------------------------------------

# 36. Next component

After Data Memory, the major remaining work is:

``` text
MUXes
Branch logic
Jump logic
PC-next logic
Write-back selection
```

These will connect the components we have already built into a complete
single-cycle datapath.

Finally we will create:

``` text
riscv_cpu.v
```

and test actual instructions running through the processor.
