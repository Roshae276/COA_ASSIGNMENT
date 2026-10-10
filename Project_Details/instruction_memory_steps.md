# RISC-V RV32I Single-Cycle Processor --- Step 2: Instruction Memory

## Goal

This document is the complete learning and implementation guide for the
**Instruction Memory** of the RV32I single-cycle RISC-V processor.

We will learn the hardware first, then the Verilog, then the testbench,
and finally verify the simulation from the terminal. We will **not rely
on waveforms** for this step.

------------------------------------------------------------------------

# 1. Where we are in the project

Our component-by-component order is:

``` text
1. Program Counter       DONE
2. Instruction Memory    <-- CURRENT
3. Register File
4. ALU
5. Immediate Generator
6. Main Control Unit
7. ALU Control Unit
8. Data Memory
9. MUX / Branch / Jump logic
10. Top-level RISC-V CPU
```

The first two components form the beginning of the instruction-fetch
path:

``` text
             +---------+
             |   PC    |
             +----+----+
                  |
                  | address
                  v
       +----------------------+
       | Instruction Memory   |
       +----------+-----------+
                  |
                  | 32-bit instruction
                  v
               Decoder
```

The PC answers:

> "Where is the current instruction?"

Instruction Memory answers:

> "Give me the instruction stored at that address."

------------------------------------------------------------------------

# 2. What is Instruction Memory?

Instruction Memory is a memory structure containing the program's
machine instructions.

Suppose the memory contains:

``` text
Address       Instruction
--------------------------------
0             ADDI x1, x0, 5
4             ADDI x2, x0, 10
8             ADD  x3, x1, x2
12            NOP
```

If:

``` text
PC = 0
```

the Instruction Memory returns the instruction at address 0.

If:

``` text
PC = 4
```

it returns the instruction at address 4.

If:

``` text
PC = 8
```

it returns the instruction at address 8.

The basic relationship is:

``` text
address -> Instruction Memory -> instruction
```

------------------------------------------------------------------------

# 3. What the supplied RISC-V notes tell us

The lecture notes used for this project state that:

-   RISC-V has a single **byte-addressable** address space.
-   A memory word is 32 bits = 4 bytes.
-   RV32I has 32-bit registers.
-   The PC holds the address of the current instruction.
-   RV32I base instructions are fixed at 32 bits.
-   Base instructions are aligned on a four-byte boundary.
-   The base formats are R, I, S, U plus SB and UJ subformats.

These facts determine the basic Instruction Memory model we are using.

------------------------------------------------------------------------

# 4. Why does the PC normally increase by 4?

An RV32I instruction is:

``` text
32 bits
```

One byte is:

``` text
8 bits
```

Therefore:

``` text
32 / 8 = 4 bytes
```

So one instruction occupies four bytes.

For example:

``` text
Instruction 0:
byte address 0
byte address 1
byte address 2
byte address 3
```

The next instruction starts at:

``` text
byte address 4
```

Then:

``` text
Instruction 1:
byte address 4
byte address 5
byte address 6
byte address 7
```

Then the next instruction begins at 8.

Therefore normal sequential execution uses:

``` text
PC_next = PC + 4
```

Important:

**The Program Counter module does not calculate `pc_next`.**

The PC module only stores the value given to it.

Later, next-PC logic will calculate:

``` text
PC + 4
```

for normal execution, or a branch/jump target when required.

------------------------------------------------------------------------

# 5. Byte-addressable memory

This is an important concept.

Byte-addressable means:

> Every memory address identifies one byte.

For example:

``` text
Address 0 -> one byte
Address 1 -> one byte
Address 2 -> one byte
Address 3 -> one byte
```

A 32-bit word contains four bytes:

``` text
Address 0 -> byte 0
Address 1 -> byte 1
Address 2 -> byte 2
Address 3 -> byte 3
```

The next 32-bit word starts at address 4:

``` text
Address 4 -> byte 0 of next word
Address 5 -> byte 1
Address 6 -> byte 2
Address 7 -> byte 3
```

This is why the PC is a **byte address**.

------------------------------------------------------------------------

# 6. Four-byte instruction alignment

The supplied notes state that base RV32I instructions must be aligned on
a four-byte boundary.

Therefore normal instruction addresses are:

``` text
0
4
8
12
16
20
...
```

Not normally:

``` text
1
2
3
5
6
7
...
```

For an aligned address, the two least-significant address bits are zero:

``` text
0  = ...0000
4  = ...0100
8  = ...1000
12 = ...1100
```

So:

``` text
address[1:0] = 2'b00
```

for the normal aligned instruction addresses in our basic RV32I model.

------------------------------------------------------------------------

# 7. Why do we use `address[31:2]`?

This is the most important part of this component.

There are two different things:

1.  The **PC address** is a byte address.
2.  Our Verilog memory array will store one complete 32-bit instruction
    per array element.

So we need to convert:

``` text
byte address
```

into:

``` text
instruction index
```

For aligned addresses:

``` text
instruction index = address / 4
```

Examples:

``` text
PC        PC / 4       array index
------------------------------------
0            0             0
4            1             1
8            2             2
12           3             3
16           4             4
20           5             5
```

Taking:

``` verilog
address[31:2]
```

is equivalent to shifting right by two bits, which is division by 4 for
an aligned address.

Therefore:

``` verilog
memory[address[31:2]]
```

maps:

``` text
PC = 0  -> memory[0]
PC = 4  -> memory[1]
PC = 8  -> memory[2]
PC = 12 -> memory[3]
PC = 16 -> memory[4]
```

------------------------------------------------------------------------

# 8. Understand `[31:2]` using one example

Take:

``` text
PC = 12
```

Binary:

``` text
00000000000000000000000000001100
```

The last two bits are:

``` text
00
```

The remaining bits `[31:2]` represent:

``` text
3
```

because:

``` text
12 / 4 = 3
```

Therefore:

``` verilog
memory[address[31:2]]
```

selects:

``` verilog
memory[3]
```

This is the main reason we use `[31:2]`.

------------------------------------------------------------------------

# 9. PC address vs memory array index

Do not confuse them.

### PC

``` text
PC = 12
```

means:

> The current instruction begins at byte address 12.

### Array index

``` text
memory[3]
```

means:

> The fourth 32-bit instruction slot.

They are related by:

``` text
byte address / 4 = instruction-word index
```

So:

``` text
PC = 12
     |
     | divide by 4
     v
index = 3
```

------------------------------------------------------------------------

# 10. Hardware view

The Instruction Memory can be viewed as:

``` text
                  address
                     |
                     v
              +-------------+
              |             |
              | Instruction |
              |   Memory    |
              |             |
              +------+------+
                     |
                     v
                instruction
```

Internally:

``` text
Index       32-bit instruction
-----------------------------------
0           instruction 0
1           instruction 1
2           instruction 2
3           instruction 3
4           instruction 4
...
```

The PC gives a byte address.

The memory converts that address into an instruction index.

Then the selected 32-bit instruction is returned.

------------------------------------------------------------------------

# 11. Sequential vs combinational hardware

This is our next major Verilog concept.

## Program Counter

The PC is sequential hardware.

It changes on a clock edge:

``` text
clock edge
    |
    v
PC changes
```

That is why we wrote:

``` verilog
always @(posedge clk)
```

## Instruction Memory read

For our simple model, instruction reading is combinational:

``` text
address changes
      |
      v
selected memory word changes
      |
      v
instruction changes
```

We therefore do not need a clock just to read an instruction.

We can use:

``` verilog
assign instruction = memory[address[31:2]];
```

------------------------------------------------------------------------

# 12. What does combinational mean?

Combinational hardware means the output depends on the current inputs.

For our read:

``` text
address
   |
   v
memory lookup
   |
   v
instruction
```

If the address changes, the selected instruction changes.

There is no requirement to wait for:

``` text
posedge clk
```

This is different from the PC.

------------------------------------------------------------------------

# 13. Verilog memory arrays

We need many instruction locations.

We can declare:

``` verilog
reg [31:0] memory [0:255];
```

Break it down.

## `[31:0]`

Each memory element contains:

``` text
32 bits
```

because each instruction is 32 bits.

## `[0:255]`

There are:

``` text
256 elements
```

numbered:

``` text
0
1
2
...
255
```

Therefore:

``` verilog
reg [31:0] memory [0:255];
```

means:

> An array containing 256 entries, where each entry stores 32 bits.

Conceptually:

``` text
memory[0]   -> 32 bits
memory[1]   -> 32 bits
memory[2]   -> 32 bits
...
memory[255] -> 32 bits
```

Total capacity:

``` text
256 × 32 bits
= 8192 bits
= 1024 bytes
= 1 KB
```

For a small educational CPU program, this is enough.

------------------------------------------------------------------------

# 14. Why is the memory declared `reg`?

You may ask:

> "If this is memory, why are we using `reg`?"

Traditional Verilog uses a `reg` array for storage that can be assigned
procedurally:

``` verilog
memory[0] = 32'h...
```

Here `reg` means the array elements are procedural variables.

It does **not** automatically mean every memory element physically
becomes a flip-flop.

For this project, the easiest mental model is:

``` text
reg [31:0] memory [0:255]
```

means:

> A table of 256 instruction slots, each 32 bits wide.

The physical implementation after synthesis depends on the hardware
target and synthesis tool.

------------------------------------------------------------------------

# 15. First implementation: initialize instructions manually

For learning, we can directly place a few instructions into the memory:

``` verilog
initial begin
    memory[0] = 32'h00500093;
    memory[1] = 32'h00A00113;
    memory[2] = 32'h002081B3;
    memory[3] = 32'h00000013;
end
```

Conceptually:

``` text
memory[0] -> first instruction
memory[1] -> second instruction
memory[2] -> third instruction
memory[3] -> fourth instruction
```

Instruction Memory does not execute these instructions.

It only stores and returns their 32 bits.

------------------------------------------------------------------------

# 16. Example machine instructions

For our test program:

``` text
memory[0] = 00500093   -> ADDI x1, x0, 5
memory[1] = 00A00113   -> ADDI x2, x0, 10
memory[2] = 002081B3   -> ADD  x3, x1, x2
memory[3] = 00000013   -> ADDI x0, x0, 0 (NOP encoding)
```

The exact instruction fields are decoded later.

Instruction Memory only sees:

``` text
00500093
00A00113
002081B3
00000013
```

The decoder will later interpret:

``` text
opcode
funct3
funct7
rs1
rs2
rd
immediate fields
```

according to the instruction format.

------------------------------------------------------------------------

# 17. Instruction Memory does NOT decode

Keep the responsibilities separate.

### Instruction Memory

``` text
address
   |
   v
instruction
```

### Decoder / Control Unit

``` text
instruction
   |
   v
opcode / funct3 / funct7
   |
   v
control signals
```

### Register File

``` text
rs1 / rs2
   |
   v
register values
```

### ALU

``` text
operands + control
   |
   v
result
```

This modular design will make the final processor much easier to
understand.

------------------------------------------------------------------------

# 18. Complete Instruction Memory module

Create:

``` text
rtl/instruction_memory.v
```

Use:

``` verilog
module instruction_memory (
    input  wire [31:0] address,
    output wire [31:0] instruction
);

    reg [31:0] memory [0:255];

    initial begin
        memory[0] = 32'h00500093; // ADDI x1, x0, 5
        memory[1] = 32'h00A00113; // ADDI x2, x0, 10
        memory[2] = 32'h002081B3; // ADD x3, x1, x2
        memory[3] = 32'h00000013; // NOP
    end

    assign instruction = memory[address[31:2]];

endmodule
```

------------------------------------------------------------------------

# 19. Line-by-line explanation

## Line 1

``` verilog
module instruction_memory (
```

Creates the Instruction Memory hardware module.

A module is a hardware block with ports and internal logic.

------------------------------------------------------------------------

## Address input

``` verilog
input wire [31:0] address,
```

The module receives a 32-bit byte address.

Eventually:

``` text
PC -> address
```

------------------------------------------------------------------------

## Instruction output

``` verilog
output wire [31:0] instruction
```

The module returns a 32-bit instruction.

Therefore:

``` text
32-bit address
      |
      v
Instruction Memory
      |
      v
32-bit instruction
```

------------------------------------------------------------------------

## Memory array

``` verilog
reg [31:0] memory [0:255];
```

Creates:

``` text
256 locations
each location = 32 bits
```

------------------------------------------------------------------------

## Initialization

``` verilog
initial begin
```

Starts an initialization procedure.

For our simulation, it fills the memory with known test instructions.

------------------------------------------------------------------------

## Instruction 0

``` verilog
memory[0] = 32'h00500093;
```

Stores the first machine instruction.

------------------------------------------------------------------------

## Instruction 1

``` verilog
memory[1] = 32'h00A00113;
```

Stores the second machine instruction.

------------------------------------------------------------------------

## Instruction 2

``` verilog
memory[2] = 32'h002081B3;
```

Stores the third machine instruction.

------------------------------------------------------------------------

## Instruction 3

``` verilog
memory[3] = 32'h00000013;
```

Stores a harmless NOP encoding for the test.

------------------------------------------------------------------------

## Continuous read

``` verilog
assign instruction = memory[address[31:2]];
```

This is the most important line.

It means:

> Continuously output the 32-bit memory word selected by the address.

Examples:

``` text
address = 0
address[31:2] = 0
instruction = memory[0]
```

``` text
address = 4
address[31:2] = 1
instruction = memory[1]
```

``` text
address = 8
address[31:2] = 2
instruction = memory[2]
```

``` text
address = 12
address[31:2] = 3
instruction = memory[3]
```

------------------------------------------------------------------------

# 20. What is `assign`?

This is an important Verilog fundamental.

``` verilog
assign instruction = ...
```

is a continuous assignment.

It means:

> Keep the output `instruction` connected to the value on the right
> side.

It does not wait for a clock edge.

So:

``` text
address changes
      |
      v
selected memory element changes
      |
      v
instruction changes
```

This is why the read is combinational.

------------------------------------------------------------------------

# 21. Testbench

Create:

``` text
tb/tb_instruction_memory.v
```

Use:

``` verilog
`timescale 1ns/1ps

module tb_instruction_memory;

    reg [31:0] address;
    wire [31:0] instruction;

    instruction_memory dut (
        .address(address),
        .instruction(instruction)
    );

    initial begin

        $monitor("Time=%0t | Address=%0d | Instruction=%h",
                 $time, address, instruction);

        address = 32'd0;
        #10;

        address = 32'd4;
        #10;

        address = 32'd8;
        #10;

        address = 32'd12;
        #10;

        $finish;

    end

endmodule
```

------------------------------------------------------------------------

# 22. Why is `address` a `reg` in the testbench?

Because the testbench itself changes it:

``` verilog
address = 32'd0;
address = 32'd4;
address = 32'd8;
address = 32'd12;
```

These assignments occur inside an `initial` procedural block.

Therefore:

``` verilog
reg [31:0] address;
```

is appropriate.

------------------------------------------------------------------------

# 23. Why is `instruction` a `wire`?

The testbench does not assign a value to `instruction`.

The Instruction Memory module drives it:

``` text
Instruction Memory
       |
       v
 instruction
```

Therefore:

``` verilog
wire [31:0] instruction;
```

------------------------------------------------------------------------

# 24. Why is there no clock in this testbench?

Because we are testing the combinational read:

``` text
address -> instruction
```

There is no need for:

``` verilog
always @(posedge clk)
```

in the Instruction Memory read.

This is different from the PC testbench.

The PC was clocked hardware.

Instruction Memory read is being modeled as a combinational lookup.

------------------------------------------------------------------------

# 25. Understand the test sequence

At time 0:

``` verilog
address = 32'd0;
```

Therefore:

``` text
address[31:2] = 0
```

and:

``` text
instruction = memory[0]
```

which is:

``` text
00500093
```

Then:

``` verilog
#10;
```

means:

> Wait 10 ns in simulation.

Next:

``` verilog
address = 32'd4;
```

Now:

``` text
address[31:2] = 1
```

so:

``` text
instruction = memory[1]
```

which is:

``` text
00A00113
```

Then:

``` text
address = 8
```

selects:

``` text
memory[2]
```

Then:

``` text
address = 12
```

selects:

``` text
memory[3]
```

------------------------------------------------------------------------

# 26. Expected terminal output

Compile:

``` powershell
iverilog -o imem_sim rtl/instruction_memory.v tb/tb_instruction_memory.v
```

Run:

``` powershell
vvp imem_sim
```

The important expected mapping is:

``` text
Address     Instruction
-------------------------
0           00500093
4           00A00113
8           002081B3
12          00000013
```

The displayed simulation time can appear in simulator time units,
depending on the formatting.

------------------------------------------------------------------------

# 27. What are we verifying?

We are checking four address-to-instruction cases.

### Case 1

``` text
address = 0
```

Expected:

``` text
memory[0]
```

### Case 2

``` text
address = 4
```

Expected:

``` text
memory[1]
```

### Case 3

``` text
address = 8
```

Expected:

``` text
memory[2]
```

### Case 4

``` text
address = 12
```

Expected:

``` text
memory[3]
```

If all four are correct, the basic Instruction Memory read works.

------------------------------------------------------------------------

# 28. No waveform is required

For this learning project we can simply use:

``` verilog
$monitor(...)
```

and read the terminal output.

Workflow:

``` text
Write RTL
    |
    v
Write testbench
    |
    v
iverilog compile
    |
    v
vvp simulation
    |
    v
Read terminal output
    |
    v
Correct?
    |
    +---- No ----> Debug
    |
   Yes
    |
    v
Next component
```

GTKWave is optional and is not required to understand this component.

------------------------------------------------------------------------

# 29. `$readmemh`

Manually writing:

``` verilog
memory[0] = ...
memory[1] = ...
memory[2] = ...
```

is fine for a tiny test.

For a larger program, Verilog provides:

``` verilog
$readmemh
```

which loads hexadecimal values from a text file.

For example:

``` text
program.hex
```

could contain:

``` text
00500093
00A00113
002081B3
00000013
```

Then:

``` verilog
initial begin
    $readmemh("program.hex", memory);
end
```

The first line goes into:

``` text
memory[0]
```

The second line goes into:

``` text
memory[1]
```

and so on.

This is the cleaner direction when we start testing larger programs.

------------------------------------------------------------------------

# 30. Why hexadecimal?

A 32-bit instruction is long in binary.

Binary:

``` text
00000000010100000000100010010011
```

Hexadecimal:

``` text
00500093
```

One hexadecimal digit represents four binary bits.

Therefore:

``` text
8 hex digits × 4 bits = 32 bits
```

Hexadecimal is therefore convenient for machine instructions.

------------------------------------------------------------------------

# 31. Future `$readmemh` version

Later, the module can be:

``` verilog
module instruction_memory (
    input  wire [31:0] address,
    output wire [31:0] instruction
);

    reg [31:0] memory [0:255];

    initial begin
        $readmemh("program.hex", memory);
    end

    assign instruction = memory[address[31:2]];

endmodule
```

For the first learning test, manual initialization is easier because
every memory entry is visible in the Verilog file.

------------------------------------------------------------------------

# 32. Important Verilog concepts learned

  Verilog concept               Meaning
  ----------------------------- -------------------------------------
  `module`                      Hardware block
  `input`                       Input port
  `output`                      Output port
  `wire`                        Net/connection
  `reg`                         Procedurally assignable variable
  `[31:0]`                      32-bit width
  `reg [31:0] memory [0:255]`   256 memory elements, each 32 bits
  `assign`                      Continuous assignment
  `initial`                     Initialization/simulation procedure
  `$monitor`                    Print simulation values
  `$finish`                     Stop simulation
  `$readmemh`                   Load hexadecimal memory contents

------------------------------------------------------------------------

# 33. Common mistake: `memory[address]`

Do not write:

``` verilog
memory[address]
```

and expect:

``` text
address 4 -> second instruction
```

In our array:

``` text
memory[4]
```

means the fifth array element.

But we want:

``` text
byte address 4 -> second 32-bit instruction
```

Therefore:

``` verilog
memory[address[31:2]]
```

gives:

``` text
address 4 -> memory[1]
```

------------------------------------------------------------------------

# 34. Common mistake: adding a clock to the read

Do not automatically add:

``` verilog
always @(posedge clk)
```

to the Instruction Memory read.

The PC is clocked storage:

``` text
clock -> PC changes
```

Our simple Instruction Memory read is:

``` text
address -> instruction
```

------------------------------------------------------------------------

# 35. Common mistake: decoding inside Instruction Memory

Instruction Memory should not decide whether an instruction is:

``` text
ADD
ADDI
LW
SW
BEQ
JAL
```

It only stores and returns the instruction bits.

Later:

``` text
instruction
    |
    v
opcode
funct3
funct7
    |
    v
Control Unit / Decoder
```

will interpret them.

------------------------------------------------------------------------

# 36. Common mistake: confusing PC and instruction

If:

``` text
PC = 8
```

this does not mean:

``` text
instruction = 8
```

It means:

> Read the instruction beginning at byte address 8.

The lookup is:

``` text
PC = 8
   |
   v
PC[31:2] = 2
   |
   v
memory[2]
   |
   v
002081B3
```

------------------------------------------------------------------------

# 37. PC + Instruction Memory together

We now have:

``` text
             +-------------+
             |     PC      |
             +------+------+
                    |
                    | address
                    v
             +-------------+
             | Instruction |
             |   Memory    |
             +------+------+
                    |
                    | instruction
                    v
                Decoder
```

The PC tells memory:

> "I need the instruction at this address."

Memory responds:

> "Here are the 32 instruction bits stored there."

------------------------------------------------------------------------

# 38. Complete fetch example

Suppose:

``` text
PC = 0
```

Instruction Memory receives:

``` text
address = 0
```

Then:

``` text
address[31:2] = 0
```

So:

``` text
memory[0]
```

is selected.

It contains:

``` text
00500093
```

Therefore:

``` text
instruction = 00500093
```

Later, the decoder interprets those bits.

------------------------------------------------------------------------

# 39. Next instruction

For normal sequential execution, next-PC logic will calculate:

``` text
PC_next = PC + 4
```

So:

``` text
PC_next = 0 + 4
        = 4
```

At the next clock edge:

``` text
PC = 4
```

Instruction Memory receives:

``` text
address = 4
```

Then:

``` text
address[31:2] = 1
```

so it returns:

``` text
memory[1]
```

which contains:

``` text
00A00113
```

The same process repeats.

------------------------------------------------------------------------

# 40. Full fetch flow

``` text
             +---------+
             |   PC    |
             +----+----+
                  |
                  | byte address
                  v
       +----------------------+
       | Instruction Memory   |
       |                      |
       | address[31:2]        |
       |        |             |
       |        v             |
       |    memory[index]     |
       +----------+-----------+
                  |
                  | 32-bit instruction
                  v
             +----------+
             | Decoder  |
             +----------+
```

------------------------------------------------------------------------

# 41. Full CPU picture after Step 2

We have now completed the beginning of the fetch path:

``` text
             +----------------+
             |      PC        |
             |   32-bit reg   |
             +-------+--------+
                     |
                     | address
                     v
             +--------------------+
             | Instruction Memory |
             +---------+----------+
                       |
                       | instruction
                       v
                  Decode stage
```

Later we will extend this into:

``` text
PC
 |
 v
Instruction Memory
 |
 v
Instruction
 |
 +---------------------+
 |                     |
 v                     v
Control             Register File
 |                     |
 |                     |
 +----------+----------+
            |
            v
           ALU
            |
            v
       Data Memory
            |
            v
        Write Back
            |
            v
       Register File

And separately:

instruction + control + results
            |
            v
       Next-PC Logic
            |
            v
          PC_next
            |
            v
            PC
```

------------------------------------------------------------------------

# 42. Project files after Step 2

Your project should look like:

``` text
RISCV/
│
├── rtl/
│   ├── program_counter.v
│   └── instruction_memory.v
│
├── tb/
│   ├── tb_program_counter.v
│   └── tb_instruction_memory.v
│
└── program.hex       (optional for $readmemh)
```

------------------------------------------------------------------------

# 43. Exact commands

From:

``` text
C:\Users\dodan\OneDrive\Desktop\RISCV
```

compile:

``` powershell
iverilog -o imem_sim rtl/instruction_memory.v tb/tb_instruction_memory.v
```

Run:

``` powershell
vvp imem_sim
```

Expected address-to-instruction mapping:

``` text
Address 0  -> 00500093
Address 4  -> 00A00113
Address 8  -> 002081B3
Address 12 -> 00000013
```

------------------------------------------------------------------------

# 44. Questions to answer before moving to Register File

You should be able to explain:

### Q1. Why is one RV32I instruction 4 bytes?

``` text
32 bits / 8 bits = 4 bytes
```

### Q2. Why are normal instruction addresses:

``` text
0, 4, 8, 12...
```

Because base RV32I instructions are 4-byte aligned.

### Q3. Why do we use:

``` verilog
address[31:2]
```

Because the PC is a byte address and our memory array is indexed by
complete 32-bit instruction words.

### Q4. What does this mean?

``` verilog
reg [31:0] memory [0:255];
```

256 memory locations, each 32 bits wide.

### Q5. What does this mean?

``` verilog
assign instruction = memory[address[31:2]];
```

Continuously output the 32-bit instruction selected by the byte address.

### Q6. Why does the read not need `posedge clk`?

Because our read is modeled as a combinational address-to-data lookup.

------------------------------------------------------------------------

# 45. Final mental model

Remember these three statements:

``` text
PC
= "Where is the current instruction?"
```

``` text
Instruction Memory
= "Give me the 32-bit instruction stored at that address."
```

``` text
Decoder
= "What do these 32 bits mean?"
```

So:

``` text
PC
 |
 | address
 v
Instruction Memory
 |
 | 32-bit instruction
 v
Decoder
 |
 | operation/control information
 v
Rest of CPU
```

That is the complete conceptual job of Instruction Memory.

------------------------------------------------------------------------

## Source basis

The hardware assumptions in this guide are based on the supplied
**RISC-V ISA lecture notes**, especially the sections on RISC-V memory,
RV32I, the PC, and base instruction formats: byte-addressable memory,
32-bit words, fixed 32-bit instructions, and four-byte instruction
alignment.
