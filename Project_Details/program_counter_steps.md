# STEP 1 --- PROGRAM COUNTER (PC)

## Single-Cycle RISC-V RV32I Processor --- Detailed Study and Implementation

------------------------------------------------------------------------

## 1. Objective

The first hardware component of our single-cycle RISC-V processor is the
**Program Counter (PC)**.

Before writing Verilog, we will understand:

1.  What the PC is
2.  What the PC stores
3.  Why the PC is 32 bits
4.  Why instructions normally move by 4 bytes
5.  What `PC_next` means
6.  How the PC behaves on a clock edge
7.  Why reset is required
8.  What inputs and outputs the PC needs
9.  How to derive the Verilog code
10. How to test the PC independently
11. How to verify the waveform
12. Common mistakes
13. How the PC will connect to the rest of the processor later

------------------------------------------------------------------------

# 2. What is a Program Counter?

The **Program Counter (PC)** is a special 32-bit register that stores
the **address of the current instruction** being executed/fetched.

The provided RISC-V lecture notes explicitly describe the PC as holding
the address of the current instruction.

For example:

``` text
PC = 0
```

means:

``` text
Instruction Memory address 0
        |
        v
   Current instruction
```

After that instruction, in the normal sequential case, the processor
will calculate:

``` text
PC_next = PC + 4
```

So:

``` text
Current PC     Next PC
   0              4
   4              8
   8             12
  12             16
```

The important distinction is:

``` text
PC      = address of the current instruction
PC_next = address that will become the PC next
```

At the next active clock edge:

``` text
PC <= PC_next
```

So after the update, the PC contains the address of the next
instruction.

------------------------------------------------------------------------

# 3. Why is the PC 32 bits?

We are implementing **RV32I**.

The `32` in RV32I refers to the 32-bit base integer architecture.

The lecture notes specify that the PC is an additional unprivileged
register and that RV32I has 32-bit registers.

For our educational processor, we therefore use:

``` verilog
reg [31:0] pc;
```

This means:

``` text
PC width = 32 bits
```

So the PC can represent a 32-bit address.

------------------------------------------------------------------------

# 4. Why does PC normally increase by 4?

An RV32I instruction is:

``` text
32 bits
```

Convert bits to bytes:

``` text
32 bits / 8 = 4 bytes
```

Therefore each normal RV32I instruction occupies 4 bytes.

The lecture notes also state that the base RV32I instructions are fixed
at 32 bits and must be aligned on a four-byte boundary.

Therefore, in the normal sequential case:

``` text
PC_next = PC + 4
```

Example:

``` text
Instruction 1:
Address = 0

Instruction 2:
Address = 4

Instruction 3:
Address = 8

Instruction 4:
Address = 12
```

So the PC normally follows:

``` text
0 → 4 → 8 → 12 → 16 → ...
```

------------------------------------------------------------------------

# 5. Very important: PC does NOT always become PC + 4

This is one of the most important concepts.

For an ordinary instruction:

``` text
PC_next = PC + 4
```

But for control-flow instructions, the next PC can be different.

For example, a branch may do:

``` text
PC_next = PC + branch_immediate
```

A JAL instruction may do:

``` text
PC_next = PC + jump_immediate
```

A JALR instruction may do:

``` text
PC_next = rs1 + immediate
```

with the least-significant bit cleared.

Therefore the PC module itself should **not** decide whether the next
address is:

``` text
PC + 4
```

or:

``` text
branch target
```

or:

``` text
jump target
```

Instead, another piece of combinational logic will calculate:

``` text
PC_next
```

and the PC module will simply store it.

This gives us a clean architecture:

``` text
              +------------------+
              | Next-PC Logic    |
              |                  |
PC ---------->| PC + 4           |
              | Branch target     |
              | JAL target       |
              | JALR target      |
              +--------+---------+
                       |
                       | PC_next
                       v
              +------------------+
              | Program Counter  |
              |     Register     |
              +--------+---------+
                       |
                       | PC
                       v
              Instruction Memory
```

------------------------------------------------------------------------

# 6. PC as a hardware register

A very important idea:

The PC is **state**.

That means its value must be stored.

In hardware, a value that persists from one clock cycle to another is
stored in a register/flip-flop structure.

Conceptually:

``` text
                clock
                  |
                  v
          +---------------+
PC_next ->|   PC Register |-> PC
          +---------------+
```

At every active clock edge:

``` text
PC = PC_next
```

Therefore the PC is sequential logic.

------------------------------------------------------------------------

# 7. Why do we need a clock?

Digital processors operate in synchronized clock cycles.

Suppose:

``` text
PC_next = 4
```

At some instant.

The PC should not continuously change to 4 at an arbitrary time.

Instead, it should update at the clock edge.

For example:

``` text
Clock:

____/‾‾‾‾\____/‾‾‾‾\____
       ↑          ↑
    edge         edge
```

At the rising edge:

``` text
PC <= PC_next
```

So if:

``` text
PC = 0
PC_next = 4
```

then at the rising edge:

``` text
PC becomes 4
```

------------------------------------------------------------------------

# 8. Rising-edge triggered PC

We will use:

``` verilog
always @(posedge clk)
```

`posedge` means:

``` text
positive edge
```

or:

``` text
rising edge
```

So:

``` verilog
always @(posedge clk)
```

means:

> Execute this sequential hardware behavior whenever the clock changes
> from 0 to 1.

This is exactly what we want for a clocked register.

------------------------------------------------------------------------

# 9. Why do we need reset?

When the processor starts, we need a known PC value.

For our processor, we will start execution from:

``` text
address 0
```

Therefore reset should make:

``` text
PC = 0
```

Conceptually:

``` text
reset = 1
    ↓
PC = 0
```

After reset is released:

``` text
reset = 0
```

the PC can start following `PC_next`.

------------------------------------------------------------------------

# 10. Synchronous reset used in this design

Our first implementation will use a **synchronous reset**.

That means reset is checked at the clock edge.

The logic is:

``` verilog
always @(posedge clk) begin

    if (reset)
        pc <= 32'b0;

    else
        pc <= pc_next;

end
```

So if reset becomes high between clock edges, the PC does not
immediately change.

It changes when the next rising clock edge occurs.

------------------------------------------------------------------------

# 11. PC inputs and output

We need to decide exactly what the PC module requires.

### Inputs

#### 1. `clk`

Clock signal.

``` verilog
input wire clk
```

#### 2. `reset`

Used to initialize the PC.

``` verilog
input wire reset
```

#### 3. `pc_next`

The next address calculated by external logic.

``` verilog
input wire [31:0] pc_next
```

### Output

#### `pc`

Current PC value.

``` verilog
output reg [31:0] pc
```

Therefore:

``` text
             Program Counter
        +------------------------+
        |                        |
clk --->|                        |
reset ->|        PC Register     |---> pc
        |                        |
pc_next>|                        |
        +------------------------+
```

------------------------------------------------------------------------

# 12. Before writing code, derive the behavior

Do not start by memorizing Verilog.

First write the hardware rule.

The rule is:

``` text
IF reset is active:
    PC = 0

ELSE:
    PC = PC_next
```

This becomes:

``` verilog
always @(posedge clk) begin

    if (reset)
        pc <= 32'b0;

    else
        pc <= pc_next;

end
```

That is the entire sequential behavior of the PC.

------------------------------------------------------------------------

# 13. Final Program Counter module

Create:

``` text
rtl/program_counter.v
```

Code:

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

------------------------------------------------------------------------

# 14. Line-by-line explanation

## Line 1

``` verilog
module program_counter (
```

We are creating a module named:

``` text
program_counter
```

A module is a hardware block.

Later, the top-level CPU will instantiate this block.

------------------------------------------------------------------------

## Line 2

``` verilog
input wire clk,
```

This is the clock input.

`input` means the signal enters this module.

`wire` means the signal is driven from outside this module.

------------------------------------------------------------------------

## Line 3

``` verilog
input wire reset,
```

Reset signal.

When reset is active at a rising clock edge:

``` text
PC = 0
```

------------------------------------------------------------------------

## Line 4

``` verilog
input wire [31:0] pc_next,
```

This is a 32-bit input.

It represents:

``` text
the address that should become the PC on the next clock edge
```

Example:

``` text
pc_next = 32'd4
```

means:

``` text
At the next clock edge:
PC becomes 4
```

------------------------------------------------------------------------

## Line 5

``` verilog
output reg [31:0] pc
```

The output is the current PC.

Why `reg`?

Because the PC stores a value and is assigned inside a clocked `always`
block.

The width is:

``` text
32 bits
```

------------------------------------------------------------------------

## Module closing

``` verilog
);
```

This completes the port list.

------------------------------------------------------------------------

# 15. The always block

``` verilog
always @(posedge clk) begin
```

This says:

> The PC state changes on the rising edge of the clock.

This is sequential logic.

------------------------------------------------------------------------

# 16. Reset condition

``` verilog
if (reset)
    pc <= 32'b0;
```

If reset is 1 at the clock edge:

``` text
PC = 0
```

`32'b0` means a 32-bit binary value containing all zeros:

``` text
00000000000000000000000000000000
```

which represents decimal 0.

------------------------------------------------------------------------

# 17. Normal operation

``` verilog
else
    pc <= pc_next;
```

If reset is not active:

``` text
PC gets PC_next
```

Notice that we are **not** writing:

``` verilog
pc <= pc + 4;
```

inside this module.

Why?

Because later the processor may need:

``` text
PC + 4
```

or:

``` text
PC + branch offset
```

or:

``` text
PC + jump offset
```

or:

``` text
rs1 + immediate
```

Therefore the external next-PC logic should calculate the correct
`pc_next`.

The PC only stores the result.

------------------------------------------------------------------------

# 18. Why use `<=` instead of `=`?

For clocked/sequential logic, use:

``` verilog
<=
```

called **non-blocking assignment**.

So:

``` verilog
pc <= pc_next;
```

is appropriate.

We will use blocking assignments `=` later for many combinational
`always @(*)` blocks.

A simple rule:

``` text
Sequential / clocked logic:
    <=

Combinational logic:
    =
```

For this PC:

``` verilog
always @(posedge clk)
```

therefore:

``` verilog
pc <= pc_next;
```

------------------------------------------------------------------------

# 19. Complete PC behavior

Suppose initially:

``` text
reset = 1
```

At a rising edge:

``` text
PC = 0
```

Then:

``` text
reset = 0
pc_next = 4
```

At the next rising edge:

``` text
PC = 4
```

Then:

``` text
pc_next = 8
```

At the next rising edge:

``` text
PC = 8
```

Then:

``` text
pc_next = 12
```

At the next rising edge:

``` text
PC = 12
```

So:

``` text
Clock edge       PC
--------------------
Reset edge        0
Next edge         4
Next edge         8
Next edge        12
Next edge        16
```

------------------------------------------------------------------------

# 20. Important conceptual difference: PC vs PC_next

This distinction should be completely clear.

Suppose:

``` text
PC = 8
```

The current instruction is stored at:

``` text
address 8
```

For a normal instruction:

``` text
PC_next = 8 + 4
        = 12
```

But until the clock edge occurs:

``` text
PC = 8
```

After the rising edge:

``` text
PC = 12
```

So:

``` text
Before edge:

PC      = 8
PC_next = 12

After edge:

PC      = 12
```

This is why saying:

> "PC stores the address of the next instruction"

can be confusing.

The precise statement is:

> **PC stores the address of the current instruction; `PC_next` is the
> address that will become the PC at the next clock edge.**

The lecture notes use the same current-instruction-address definition
for the PC.

------------------------------------------------------------------------

# 21. Why should PC not contain the instruction itself?

The PC contains:

``` text
ADDRESS
```

not:

``` text
INSTRUCTION
```

Example:

``` text
PC = 8
```

means:

``` text
Go to memory address 8
```

Instruction Memory then returns something like:

``` text
instruction = 32'h002081B3
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
Instruction
```

The PC does not store:

``` text
ADD x3,x1,x2
```

It stores the address where that instruction is located.

------------------------------------------------------------------------

# 22. PC and Instruction Memory relationship

Later, we will connect:

``` text
PC → Instruction Memory
```

For example:

``` text
PC = 0
```

Instruction Memory returns instruction 0.

Then:

``` text
PC = 4
```

Instruction Memory returns instruction 1.

Then:

``` text
PC = 8
```

Instruction Memory returns instruction 2.

Conceptually:

``` text
        PC
        |
        | address
        v
+----------------------+
| Instruction Memory   |
|                      |
| Address 0  -> Inst 0 |
| Address 4  -> Inst 1 |
| Address 8  -> Inst 2 |
| Address 12 -> Inst 3 |
+----------------------+
```

------------------------------------------------------------------------

# 23. PC and the single-cycle concept

In a single-cycle CPU, one instruction is completed during one clock
cycle.

A simplified view is:

``` text
        Start of cycle
              |
              v
             PC
              |
              v
     Instruction Memory
              |
              v
          Decode
              |
              v
          Execute
              |
              v
       Memory / Writeback
              |
              v
          PC_next
              |
              v
       End of cycle
              |
       next clock edge
              |
              v
             PC
```

The PC is therefore part of the boundary between one instruction cycle
and the next.

------------------------------------------------------------------------

# 24. PC testbench

Before connecting the PC to the complete CPU, we should test it
independently.

Create:

``` text
tb/tb_program_counter.v
```

Use:

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

    // Initial values
    clk = 1'b0;
    reset = 1'b1;
    pc_next = 32'd0;

    // Keep reset active
    #12;

    // Release reset
    reset = 1'b0;

    // Next PC = 4
    pc_next = 32'd4;
    #10;

    // Next PC = 8
    pc_next = 32'd8;
    #10;

    // Next PC = 12
    pc_next = 32'd12;
    #10;

    // Test arbitrary next address
    pc_next = 32'd100;
    #10;

    $finish;

end

endmodule
```

------------------------------------------------------------------------

# 25. Understand the testbench before running it

The testbench generates the clock:

``` verilog
always #5 clk = ~clk;
```

This means:

``` text
Every 5 ns:
    0 → 1
or
    1 → 0
```

Therefore one complete clock period is:

``` text
10 ns
```

The rising edges occur at approximately:

``` text
5 ns
15 ns
25 ns
35 ns
45 ns
...
```

------------------------------------------------------------------------

# 26. Testbench initial state

``` verilog
clk = 1'b0;
reset = 1'b1;
pc_next = 32'd0;
```

At the beginning:

``` text
Clock = 0
Reset = 1
PC_next = 0
```

At the first rising edge:

``` text
reset = 1
```

therefore:

``` text
PC = 0
```

------------------------------------------------------------------------

# 27. Release reset

After:

``` verilog
#12;
```

we execute:

``` verilog
reset = 1'b0;
```

Now normal operation begins.

------------------------------------------------------------------------

# 28. Set PC_next to 4

``` verilog
pc_next = 32'd4;
```

The PC does not necessarily become 4 immediately.

It becomes 4 at the next rising edge.

That is the key behavior of a register.

------------------------------------------------------------------------

# 29. Then PC_next becomes 8

``` verilog
pc_next = 32'd8;
```

At the next rising edge:

``` text
PC = 8
```

Then:

``` text
PC_next = 12
```

and at the following rising edge:

``` text
PC = 12
```

------------------------------------------------------------------------

# 30. Expected result

The expected PC sequence is:

``` text
Reset:
PC = 0

After first normal clock:
PC = 4

After second normal clock:
PC = 8

After third normal clock:
PC = 12

After fourth normal clock:
PC = 100
```

The exact time at which each value appears depends on the clock edge and
the testbench timing.

The important behavior is:

``` text
PC updates only on rising clock edges.
```

------------------------------------------------------------------------

# 31. Better testbench with automatic checking

Instead of only looking at the waveform, we can make the testbench check
the result.

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

    // Wait for reset clock edge
    @(posedge clk);

    if (pc !== 32'd0)
        $display("ERROR: PC should be 0 during reset");
    else
        $display("PASS: Reset PC = 0");

    // Release reset
    reset = 1'b0;

    // Test PC = 4
    pc_next = 32'd4;
    @(posedge clk);
    #1;

    if (pc !== 32'd4)
        $display("ERROR: PC should be 4, got %d", pc);
    else
        $display("PASS: PC = 4");

    // Test PC = 8
    pc_next = 32'd8;
    @(posedge clk);
    #1;

    if (pc !== 32'd8)
        $display("ERROR: PC should be 8, got %d", pc);
    else
        $display("PASS: PC = 8");

    // Test PC = 12
    pc_next = 32'd12;
    @(posedge clk);
    #1;

    if (pc !== 32'd12)
        $display("ERROR: PC should be 12, got %d", pc);
    else
        $display("PASS: PC = 12");

    // Test arbitrary jump target
    pc_next = 32'd100;
    @(posedge clk);
    #1;

    if (pc !== 32'd100)
        $display("ERROR: PC should be 100, got %d", pc);
    else
        $display("PASS: PC = 100");

    $display("Program Counter test completed.");

    $finish;

end

endmodule
```

------------------------------------------------------------------------

# 32. Why is `#1` used after `@(posedge clk)`?

Consider:

``` verilog
@(posedge clk);

if (pc !== 32'd4)
```

The clock edge triggers the PC's sequential block.

Simulation scheduling can involve multiple events at the same simulation
time.

Using:

``` verilog
#1;
```

moves the checking point slightly after the edge so that the
non-blocking assignment:

``` verilog
pc <= pc_next;
```

has taken effect.

Therefore:

``` verilog
@(posedge clk);
#1;
```

is a simple way to check the updated register value.

------------------------------------------------------------------------

# 33. What should you see in the waveform?

Open the waveform and add:

``` text
clk
reset
pc_next
pc
```

You should see something conceptually like:

``` text
Time       reset     pc_next      pc
--------------------------------------
0           1          0           0
5           1          0           0
15          0          4           4
25          0          8           8
35          0         12          12
45          0        100         100
```

The exact timing depends on the testbench, but the relationship is:

``` text
At rising edge:
    pc ← pc_next
```

------------------------------------------------------------------------

# 34. What happens if pc_next changes between clock edges?

Suppose:

``` text
PC = 8
```

and:

``` text
pc_next = 12
```

Then suddenly:

``` text
pc_next = 100
```

before the clock edge.

The PC will take whatever value is present at the active clock edge.

So if:

``` text
At clock edge:
pc_next = 100
```

then:

``` text
PC = 100
```

This is another reason `PC_next` is a combinationally calculated signal.

------------------------------------------------------------------------

# 35. What happens if reset is asserted again?

Suppose:

``` text
PC = 100
```

Then:

``` text
reset = 1
```

At the next rising edge:

``` text
PC = 0
```

So reset sends the processor back to the starting instruction address.

Conceptually:

``` text
100
 |
 | reset
 v
  0
```

------------------------------------------------------------------------

# 36. Why not make reset asynchronous?

There are different reset designs in digital hardware.

For this educational implementation, we are using:

``` verilog
always @(posedge clk)
```

and checking:

``` verilog
if (reset)
```

inside it.

Therefore the reset is synchronous.

We do not need to introduce an asynchronous reset at this stage because
the objective is to understand the basic PC register and its clocked
behavior.

------------------------------------------------------------------------

# 37. Common mistake: thinking PC automatically adds 4

A beginner may write:

``` verilog
always @(posedge clk) begin
    pc <= pc + 4;
end
```

This would work only for simple sequential execution.

But a RISC-V CPU also needs:

``` text
branches
JAL
JALR
```

Therefore we need:

``` text
PC_next
```

which can come from several possible sources.

The correct modular design is:

``` text
                +----------------+
                | Next PC Logic  |
                |                |
PC + 4 -------->|                |
Branch target -->|                |----> PC_next
JAL target ----->|                |
JALR target ---->|                |
                +----------------+
                         |
                         v
                   Program Counter
```

------------------------------------------------------------------------

# 38. Common mistake: thinking PC stores the next address

Be precise.

If:

``` text
PC = 20
```

then the current instruction is at:

``` text
address 20
```

The normal next address is:

``` text
20 + 4 = 24
```

So:

``` text
PC      = 20
PC_next = 24
```

After the clock edge:

``` text
PC = 24
```

Now address 24 is the current instruction address.

------------------------------------------------------------------------

# 39. Common mistake: using the instruction value as PC

Wrong mental model:

``` text
PC = ADD instruction
```

Correct:

``` text
PC = instruction address
```

For example:

``` text
PC = 0x00000008
```

and:

``` text
Instruction Memory[0x08] = 0x002081B3
```

Then:

``` text
PC = 0x00000008
instruction = 0x002081B3
```

The two are different things.

------------------------------------------------------------------------

# 40. Common mistake: wrong PC increment

For RV32I base instructions:

``` text
instruction size = 32 bits
                  = 4 bytes
```

Therefore:

``` text
PC_next = PC + 4
```

not:

``` text
PC + 1
```

and not:

``` text
PC + 32
```

Remember:

``` text
PC is an address measured in bytes.
```

------------------------------------------------------------------------

# 41. Common mistake: using blocking assignment

For this clocked register, avoid:

``` verilog
pc = pc_next;
```

Use:

``` verilog
pc <= pc_next;
```

because the PC is sequential state.

------------------------------------------------------------------------

# 42. Common mistake: wrong width

Avoid:

``` verilog
reg [7:0] pc;
```

for this processor.

We want:

``` verilog
reg [31:0] pc;
```

because we are building a 32-bit RV32I processor.

------------------------------------------------------------------------

# 43. Common mistake: putting branch logic inside PC

Avoid making:

``` verilog
program_counter.v
```

responsible for:

``` text
BEQ
BNE
JAL
JALR
```

The PC should remain simple.

Recommended separation:

``` text
program_counter.v
    |
    | stores pc_next
    v
PC

next-PC logic
    |
    | calculates pc_next
    v
pc_next
```

This makes the design easier to understand, test and debug.

------------------------------------------------------------------------

# 44. Program Counter module --- final version

The final PC module should remain simple:

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

Do not add unnecessary logic to it.

------------------------------------------------------------------------

# 45. PC test checklist

Before moving to Step 2, verify all of these:

``` text
[ ] PC is 32 bits
[ ] PC is a register
[ ] PC updates on posedge clk
[ ] Reset sets PC to 0
[ ] PC loads pc_next
[ ] PC does not directly calculate branches
[ ] PC does not store instructions
[ ] PC stores an address
[ ] Normal next address will be PC + 4
[ ] pc_next can later come from branch/jump logic
[ ] Testbench passes
[ ] Waveform shows correct updates
```

------------------------------------------------------------------------

# 46. What we have built so far

We now have exactly one hardware component:

``` text
+-------------------------+
|   Program Counter       |
|                         |
| clk                     |
| reset                   |
| pc_next  -------------> |
|                         |
|              pc ------> |
+-------------------------+
```

Its only responsibility is:

``` text
At rising edge:

if reset:
    PC = 0
else:
    PC = PC_next
```

------------------------------------------------------------------------

# 47. What will be connected next?

The next component is:

``` text
Instruction Memory
```

The connection will eventually be:

``` text
             +-------------------+
             | Program Counter   |
             +---------+---------+
                       |
                       | PC
                       v
             +-------------------+
             | Instruction       |
             | Memory            |
             +---------+---------+
                       |
                       | 32-bit instruction
                       v
                 Instruction
```

For example:

``` text
PC = 0
      |
      v
Instruction Memory
      |
      v
instruction at address 0
```

Then:

``` text
PC = 4
      |
      v
Instruction Memory
      |
      v
instruction at address 4
```

------------------------------------------------------------------------

# 48. Final mental model for Step 1

Remember only this:

``` text
                 PC_next
                    |
                    v
             +-------------+
             |     PC      |
clk -------->|  Register   |
reset ------>|             |
             +------+------+
                    |
                    v
                   PC
                    |
                    v
           Instruction Memory
```

And the fundamental equation is:

``` text
                    ┌───────────────┐
                    │ if reset      │
                    │ PC_next = 0   │
                    └───────────────┘

otherwise:

                    PC ← PC_next
```

For normal sequential execution:

``` text
PC_next = PC + 4
```

For branches/jumps, later next-PC logic will choose another target.

------------------------------------------------------------------------

# 49. Step 1 complete

At the end of Step 1, you should understand:

``` text
PC
│
├── stores current instruction address
├── is 32 bits in our RV32I design
├── is sequential hardware
├── changes on the rising clock edge
├── reset initializes it to 0
├── receives pc_next from outside
├── normally receives PC + 4
└── can later receive branch/jump targets
```

**Do not move to Instruction Memory until this component passes
simulation and you can explain why every line of `program_counter.v`
exists.**

------------------------------------------------------------------------

# Quick viva questions for Step 1

### Q1. What does PC store?

The address of the current instruction.

### Q2. Why is PC 32 bits?

Because we are implementing RV32I and use a 32-bit address/register
datapath.

### Q3. Why is the normal PC increment 4?

An RV32I instruction is 32 bits = 4 bytes.

### Q4. What is PC_next?

The address that will be loaded into PC at the next clock edge.

### Q5. Does PC always become PC + 4?

No. Branches and jumps can select another target.

### Q6. Why is PC a register?

Because its value must persist from one clock cycle to the next.

### Q7. Why use `always @(posedge clk)`?

Because the PC is clocked sequential state.

### Q8. Why use `<=`?

Because non-blocking assignment is appropriate for sequential logic.

### Q9. Why does reset set PC to zero?

So instruction execution starts from the defined starting address 0 in
our design.

### Q10. Does the PC store the instruction?

No. It stores the instruction's address. Instruction Memory
stores/returns the instruction.

------------------------------------------------------------------------

# Step 1 final files

Recommended project structure at this point:

``` text
riscv_single_cycle/
│
├── rtl/
│   └── program_counter.v
│
└── tb/
    └── tb_program_counter.v
```

Only after this passes should we create:

``` text
rtl/instruction_memory.v
```

and begin Step 2.
