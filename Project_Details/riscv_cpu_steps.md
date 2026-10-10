# RISC-V RV32I Single-Cycle CPU — `riscv_cpu.v` Detailed Implementation Steps

## 0. Purpose of This File

This document explains, step by step, how to build the top-level `riscv_cpu.v` module by connecting the individual hardware blocks that have already been implemented and tested.

The top-level module should mainly perform **integration and wiring**. Do not redesign the individual components inside `riscv_cpu.v`.

Already completed and tested:

1. `program_counter.v`
2. `instruction_memory.v`
3. `register_file.v`
4. `alu.v`
5. `immediate_generator.v`
6. `main_control.v`
7. `alu_control.v`
8. `data_memory.v`
9. `datapath_muxes.v`
10. `pc_logic.v`

The final top-level CPU connects these modules into one datapath.

---

# 1. Big Picture

The processor is a **single-cycle RV32I datapath**.

For every instruction:

```text
PC
 ↓
Instruction Memory
 ↓
Instruction
 ↓
Decode / Control / Register File / Immediate
 ↓
ALU
 ↓
Data Memory (when required)
 ↓
Writeback
 ↓
Register File
```

At the same time, the PC logic calculates the address of the next instruction:

```text
PC
 ├──→ PC + 4
 ├──→ PC + branch/jump immediate
 └──→ rs1 + immediate  (JALR)
             ↓
          PC Logic
             ↓
          PC_next
             ↓
             PC
```

The top-level module therefore has two major responsibilities:

- **Datapath:** move and process data.
- **Control:** decide which path the data should take.

---

# 2. Hardware Blocks Used

The final CPU contains these blocks:

```text
                 ┌─────────────────────┐
                 │ Program Counter     │
                 └──────────┬──────────┘
                            │ PC
                            ↓
                 ┌─────────────────────┐
                 │ Instruction Memory  │
                 └──────────┬──────────┘
                            │ instruction
                            ↓
        ┌────────────────────────────────────────┐
        │             Decode / Control           │
        │                                        │
        │ Main Control                           │
        │ Immediate Generator                    │
        │ Register File                          │
        │ ALU Control                            │
        └────────────────────────────────────────┘
                            │
                            ↓
                 ┌─────────────────────┐
                 │ Datapath MUXes      │
                 └──────────┬──────────┘
                            │
                            ↓
                      ┌──────────┐
                      │   ALU    │
                      └────┬─────┘
                           │
                           ↓
                  ┌─────────────────┐
                  │  Data Memory    │
                  └────────┬────────┘
                           │
                           ↓
                  Writeback MUX
                           │
                           ↓
                    Register File

PC + 4 / branch target / JALR target
                  ↓
              PC Logic
                  ↓
               PC_next
```

---

# 3. Top-Level Module Interface

The CPU itself only needs two external inputs:

```verilog
module riscv_cpu (
    input wire clk,
    input wire reset
);
```

## Why `clk`?

The clock controls state changes.

The Program Counter changes on:

```verilog
posedge clk
```

The Register File writes on:

```verilog
posedge clk
```

The Data Memory performs stores on:

```verilog
posedge clk
```

So the clock coordinates the sequential parts of the processor.

## Why `reset`?

Reset puts the processor into a known starting state.

For this design:

```text
reset = 1
→ PC becomes 0
```

After reset is released:

```text
reset = 0
→ PC loads PC_next at the next rising clock edge
```

---

# 4. Step 1 — Declare Internal Wires

The top-level module needs wires connecting all submodules.

Remember:

```text
wire = connection between hardware blocks
```

These are not new storage elements.

---

## 4.1 PC Signals

Declare:

```verilog
wire [31:0] pc;
wire [31:0] pc_next;
wire [31:0] pc_plus_4;
```

Meaning:

- `pc` = current instruction address
- `pc_next` = address loaded into PC at next clock edge
- `pc_plus_4` = normal next instruction address

---

## 4.2 Instruction Signal

```verilog
wire [31:0] instruction;
```

The Instruction Memory outputs one 32-bit instruction.

RV32I base instructions are 32 bits wide.

---

## 4.3 Register File Signals

You need:

```verilog
wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire [31:0] write_back_data;
```

The instruction fields provide:

```text
rs1 = instruction[19:15]
rs2 = instruction[24:20]
rd  = instruction[11:7]
```

The Register File reads `rs1` and `rs2`, and eventually writes `rd`.

---

# 5. Step 2 — Control Signals

The Main Control Unit produces:

```verilog
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
```

## Meaning

### `reg_write`

Controls whether a value is written to `rd`.

```text
1 → write register
0 → don't write register
```

---

### `mem_read`

Controls a load operation.

```text
1 → read Data Memory
0 → no memory read
```

Used by `LW`.

---

### `mem_write`

Controls a store operation.

```text
1 → write Data Memory
0 → no memory write
```

Used by `SW`.

---

### `result_src`

Controls the final writeback MUX.

```text
00 → ALU result
01 → Memory data
10 → PC + 4
11 → Immediate
```

This is very important.

Examples:

```text
ADD   → 00
LW    → 01
JAL   → 10
JALR  → 10
LUI   → 11
AUIPC → 00
```

---

### `alu_src`

Controls the second ALU input.

```text
0 → rs2_data
1 → immediate
```

Examples:

```text
ADD:
ALU_B = rs2

ADDI:
ALU_B = immediate

LW:
ALU_B = immediate

SW:
ALU_B = immediate
```

---

### `alu_src_a`

Controls the first ALU input.

Current encoding:

```text
00 → rs1_data
01 → PC
10 → 0
```

Examples:

```text
ADD:
ALU_A = rs1

AUIPC:
ALU_A = PC

JAL:
ALU_A = PC

LUI:
ALU_A = 0
```

---

### `alu_op`

Gives high-level information to ALU Control.

Current meaning:

```text
00 → ADD
01 → SUB
10 → R-type
11 → I-type arithmetic
```

---

### `branch`

Indicates a branch instruction.

For BEQ:

```text
branch = 1
```

The PC logic also checks the ALU's `zero` output.

---

### `jump`

Indicates JAL/JALR.

```text
jump = 1
```

---

### `jalr`

Distinguishes JALR from JAL.

```text
jalr = 1
```

JALR uses:

```text
rs1 + immediate
```

and clears the least significant bit of the target.

---

# 6. Step 3 — ALU Signals

Declare:

```verilog
wire [3:0] alu_control_signal;

wire [31:0] alu_a;
wire [31:0] alu_b;
wire [31:0] alu_result;

wire zero;
```

Flow:

```text
Main Control
      ↓
    alu_op
      ↓
 ALU Control
      ↓
alu_control_signal
      ↓
     ALU
```

The ALU receives:

```text
alu_a
alu_b
alu_control_signal
```

and produces:

```text
alu_result
zero
```

---

# 7. Step 4 — Immediate Signal

Declare:

```verilog
wire [31:0] immediate;
```

The Immediate Generator receives the complete instruction:

```text
instruction
     ↓
Immediate Generator
     ↓
immediate
```

It handles different instruction formats:

```text
I
S
SB
U
UJ
```

For example:

```text
ADDI → I-type immediate
LW   → I-type immediate
SW   → S-type immediate
BEQ  → SB-type immediate
LUI  → U-type immediate
JAL  → UJ-type immediate
```

---

# 8. Step 5 — Data Memory Signals

Declare:

```verilog
wire [31:0] memory_data;
```

The Data Memory receives:

```text
clk
mem_read
mem_write
address
write_data
```

For this CPU:

```text
address    = alu_result
write_data = rs2_data
```

Why?

For:

```text
SW x2, 8(x1)
```

the ALU calculates:

```text
x1 + 8
```

That becomes the memory address.

The value stored is:

```text
x2
```

Therefore:

```text
ALU result → memory address
rs2_data  → memory write data
```

For LW:

```text
memory[address] → memory_data
```

---

# 9. Step 6 — PC Target Signals

Declare:

```verilog
wire [31:0] branch_target;
wire [31:0] jal_target;
wire [31:0] jalr_target;
```

The PC Logic calculates:

```text
pc_plus_4
branch_target
jal_target
jalr_target
pc_next
```

---

# 10. Step 7 — Instantiate Program Counter

Use your already-tested module:

```verilog
program_counter
```

Connections:

```text
clk      → clk
reset    → reset
pc_next  → pc_next
pc       → pc
```

Conceptually:

```text
                    ┌──────────────────┐
pc_next ───────────→│ Program Counter  │
clk ───────────────→│                  │
reset ─────────────→│                  │
                    └────────┬─────────┘
                             │
                             ↓
                            PC
```

The PC changes only on the rising edge of the clock.

---

# 11. Step 8 — Instantiate Instruction Memory

Connect:

```text
address = pc
```

Output:

```text
instruction
```

Therefore:

```text
PC = 0
 ↓
Instruction Memory
 ↓
memory[0]
 ↓
instruction at address 0
```

Because the instruction memory uses:

```verilog
memory[address[31:2]]
```

addresses map as:

```text
0  → memory[0]
4  → memory[1]
8  → memory[2]
12 → memory[3]
```

---

# 12. Step 9 — Instantiate Main Control

Input:

```text
instruction
```

Outputs:

```text
reg_write
mem_read
mem_write
result_src
alu_src
alu_src_a
alu_op
branch
jump
jalr
```

The Main Control does not calculate the ALU operation directly.

It produces `alu_op`.

Then ALU Control looks at:

```text
alu_op
funct3
funct7
```

to produce the final 4-bit ALU control.

---

# 13. Step 10 — Instantiate Register File

The Register File receives register numbers extracted from the instruction.

Use:

```verilog
instruction[19:15]
```

for `rs1`.

Use:

```verilog
instruction[24:20]
```

for `rs2`.

Use:

```verilog
instruction[11:7]
```

for `rd`.

Read outputs:

```text
read_data1 → rs1_data
read_data2 → rs2_data
```

Write input:

```text
write_data → write_back_data
```

Write enable:

```text
reg_write
```

So the complete flow is:

```text
                 instruction
                /     |      \
               /      |       \
             rs1     rs2      rd
              ↓       ↓       ↓
          ┌────────────────────────┐
          │     Register File      │
          └──────┬────────┬────────┘
                 ↓        ↓
              rs1_data  rs2_data

write_back_data ─────────────→ Register File
reg_write ───────────────────→ Register File
```

---

# 14. Step 11 — Instantiate Immediate Generator

Input:

```text
instruction
```

Output:

```text
immediate
```

No clock is needed because the immediate is combinationally decoded from the instruction.

---

# 15. Step 12 — Instantiate ALU Control

Inputs:

```text
instruction
alu_op
```

Output:

```text
alu_control_signal
```

Internally it uses:

```text
funct3 = instruction[14:12]
funct7 = instruction[31:25]
```

Examples:

```text
R-type:
alu_op = 10

funct3/funct7 decide:
ADD/SUB/AND/OR/XOR/etc.
```

For:

```text
ADDI:
alu_op = 11
funct3 decides ADDI/ANDI/ORI/etc.
```

For:

```text
LW/SW:
alu_op = 00
```

so the ALU performs ADD to calculate the address.

For:

```text
BEQ:
alu_op = 01
```

so the ALU performs subtraction:

```text
rs1 - rs2
```

If the result is zero:

```text
zero = 1
```

meaning the operands are equal.

---

# 16. Step 13 — Instantiate Datapath MUXes

This module controls three selections.

## MUX A

Input choices:

```text
rs1_data
PC
0
```

Controlled by:

```text
alu_src_a
```

Output:

```text
alu_a
```

Mapping:

```text
00 → rs1_data
01 → PC
10 → 0
```

---

## MUX B

Input choices:

```text
rs2_data
immediate
```

Controlled by:

```text
alu_src
```

Output:

```text
alu_b
```

Mapping:

```text
0 → rs2_data
1 → immediate
```

---

## Writeback MUX

Input choices:

```text
alu_result
memory_data
pc_plus_4
immediate
```

Controlled by:

```text
result_src
```

Output:

```text
write_back_data
```

Mapping:

```text
00 → alu_result
01 → memory_data
10 → pc_plus_4
11 → immediate
```

---

# 17. Example — ADD

Instruction:

```text
ADD x3, x1, x2
```

Control:

```text
reg_write = 1
alu_src   = 0
alu_src_a = 00
result_src = 00
alu_op = 10
```

Datapath:

```text
x1 ─────→ ALU A
x2 ─────→ ALU B
             ↓
            ADD
             ↓
           result
             ↓
        Writeback MUX
             ↓
            x3
```

---

# 18. Example — ADDI

Instruction:

```text
ADDI x1, x0, 5
```

Control:

```text
reg_write = 1
alu_src = 1
alu_src_a = 00
result_src = 00
alu_op = 11
```

Datapath:

```text
x0 ─────────→ ALU A
immediate 5 ─→ ALU B
                 ↓
                ADD
                 ↓
                 5
                 ↓
                x1
```

---

# 19. Example — LW

Instruction:

```text
LW x3, 8(x1)
```

Step 1:

```text
Register File
x1 → rs1_data
```

Step 2:

```text
Immediate Generator
8 → immediate
```

Step 3:

```text
ALU A = x1
ALU B = 8
```

Step 4:

```text
ALU = x1 + 8
```

Step 5:

```text
ALU result → Data Memory address
```

Step 6:

```text
Memory data → Writeback MUX
```

Step 7:

```text
Writeback MUX → x3
```

Control:

```text
reg_write = 1
mem_read = 1
mem_write = 0
result_src = 01
alu_src = 1
alu_src_a = 00
alu_op = 00
```

---

# 20. Example — SW

Instruction:

```text
SW x2, 8(x1)
```

ALU calculates:

```text
x1 + 8
```

Then:

```text
ALU result → memory address
x2         → memory write data
```

Control:

```text
reg_write = 0
mem_write = 1
alu_src = 1
alu_src_a = 00
alu_op = 00
```

No register writeback occurs.

---

# 21. Example — BEQ

Instruction:

```text
BEQ x1, x2, offset
```

ALU inputs:

```text
ALU A = x1
ALU B = x2
```

ALU performs:

```text
x1 - x2
```

If equal:

```text
zero = 1
```

PC Logic checks:

```text
branch && zero
```

If both are 1:

```text
PC_next = PC + immediate
```

Otherwise:

```text
PC_next = PC + 4
```

---

# 22. Example — JAL

Instruction:

```text
JAL x1, offset
```

Two things happen:

### 1. Calculate target

```text
PC + immediate
```

This becomes:

```text
PC_next
```

### 2. Save return address

```text
x1 = PC + 4
```

Therefore:

```text
result_src = 10
```

because the writeback value is:

```text
PC + 4
```

---

# 23. Example — JALR

Instruction:

```text
JALR x1, 8(x2)
```

Target:

```text
x2 + 8
```

Then clear bit 0:

```text
(rs1 + immediate) & 32'hFFFFFFFE
```

At the same time:

```text
x1 = PC + 4
```

Therefore:

```text
result_src = 10
jump = 1
jalr = 1
```

---

# 24. Example — LUI

Instruction:

```text
LUI x1, immediate
```

The result written to the register is directly:

```text
immediate
```

Therefore:

```text
result_src = 11
```

The datapath uses:

```text
ALU A = 0
ALU B = immediate
```

although the final writeback comes directly from the immediate through the writeback MUX.

---

# 25. Example — AUIPC

Instruction:

```text
AUIPC x1, immediate
```

The operation is:

```text
PC + immediate
```

Therefore:

```text
ALU A = PC
ALU B = immediate
```

The ALU result is written to `rd`.

Therefore:

```text
result_src = 00
alu_src_a = 01
alu_src = 1
```

---

# 26. Step 14 — Instantiate ALU

Connect:

```text
alu_a
alu_b
alu_control_signal
```

to the ALU.

Outputs:

```text
alu_result
zero
```

The ALU itself has already been tested.

Do not rewrite its internal operations inside the top-level module.

---

# 27. Step 15 — Instantiate Data Memory

Connect:

```text
clk
mem_read
mem_write
alu_result
rs2_data
memory_data
```

Conceptually:

```text
                 ALU result
                     │
                     ↓
                memory address
                     │
                     ↓
               ┌─────────────┐
rs2_data ─────→│ Data Memory │
               └──────┬──────┘
                      │
                      ↓
                 memory_data
```

For SW:

```text
rs2_data → memory
```

For LW:

```text
memory → memory_data
```

---

# 28. Step 16 — Instantiate PC Logic

Inputs:

```text
pc
rs1_data
immediate
branch
zero
jump
jalr
```

Outputs:

```text
pc_plus_4
branch_target
jal_target
jalr_target
pc_next
```

The normal path is:

```text
pc_next = pc + 4
```

Branch path:

```text
pc_next = pc + immediate
```

JAL:

```text
pc_next = pc + immediate
```

JALR:

```text
pc_next = (rs1_data + immediate) & 32'hFFFFFFFE
```

Priority in the existing PC Logic:

```text
1. JALR
2. JAL
3. Taken branch
4. PC + 4
```

---

# 29. Complete Dataflow

Once all modules are instantiated, the complete flow should be:

```text
                         ┌───────────────┐
                  ┌─────→│ Instruction   │
                  │      │ Memory        │
                  │      └───────┬───────┘
                  │              │
                  │              ↓
             ┌────┴────┐    instruction
             │   PC    │────────┬─────────────┐
             └────┬────┘        │             │
                  │             │             │
                  │        ┌────▼────┐   ┌────▼──────────┐
                  │        │ Control │   │ Immediate Gen │
                  │        └────┬────┘   └────┬──────────┘
                  │             │             │
                  │             │             │
                  │        ┌────▼─────────────▼────┐
                  │        │    Register File      │
                  │        └──────┬─────────┬──────┘
                  │               │         │
                  │               │         │
                  │          rs1_data    rs2_data
                  │               │         │
                  │               └────┬────┘
                  │                    │
                  │              ┌─────▼─────┐
                  │              │ Datapath  │
                  │              │   MUXes   │
                  │              └─────┬─────┘
                  │                    │
                  │                  ALU
                  │                    │
                  │                    ↓
                  │              alu_result
                  │                    │
                  │              ┌─────▼─────┐
                  │              │   Data    │
                  │              │  Memory   │
                  │              └─────┬─────┘
                  │                    │
                  │              memory_data
                  │                    │
                  │              ┌─────▼─────┐
                  │              │ Writeback │
                  │              │   MUX     │
                  │              └─────┬─────┘
                  │                    │
                  │              write_back_data
                  │                    │
                  │                    └────────→ Register File
                  │
                  │
                  │       ┌──────────────────────┐
                  └──────→│      PC Logic        │
                          └──────────┬───────────┘
                                     │
                                  pc_next
                                     │
                                     └────────→ PC
```

---

# 30. Important Rule — Don't Create Extra Logic

Do not duplicate logic that already exists.

For example, don't calculate:

```verilog
pc + 4
```

again inside `riscv_cpu.v`.

`pc_logic.v` already does it.

Don't recreate:

```text
instruction[31:20]
```

sign extension inside CPU.

`immediate_generator.v` already does it.

Don't recreate:

```text
funct3/funct7
```

decoding.

`alu_control.v` already does it.

The top-level module should primarily:

```text
declare wires
+
instantiate modules
+
connect ports
```

---

# 31. Clocked vs Combinational Parts

This distinction is important.

## Sequential blocks

These store state and use the clock:

```text
Program Counter
Register File write
Data Memory write
```

They change state on:

```text
posedge clk
```

## Combinational blocks

These continuously calculate outputs:

```text
Instruction Memory
Main Control
Immediate Generator
ALU Control
MUXes
ALU
PC Logic
Data Memory read
```

They do not wait for a clock to calculate their outputs.

---

# 32. One Complete Single-Cycle Example

Suppose:

```text
PC = 0
```

Instruction memory contains:

```text
memory[0] = ADDI x1,x0,5
```

### During the cycle

PC gives:

```text
PC = 0
```

Instruction Memory gives:

```text
instruction = ADDI x1,x0,5
```

Main Control gives:

```text
reg_write = 1
alu_src = 1
alu_src_a = 00
result_src = 00
alu_op = 11
```

Register File gives:

```text
rs1_data = x0 = 0
```

Immediate Generator gives:

```text
immediate = 5
```

ALU Control gives:

```text
ADD
```

MUXes select:

```text
ALU A = x0 = 0
ALU B = immediate = 5
```

ALU calculates:

```text
0 + 5 = 5
```

Writeback MUX selects:

```text
ALU result
```

Therefore:

```text
write_back_data = 5
```

At the next rising clock edge:

```text
Register File:
x1 = 5
```

PC Logic simultaneously calculates:

```text
PC_next = PC + 4
        = 4
```

At the same rising edge:

```text
PC = 4
```

That is one complete single-cycle instruction.

---

# 33. First Integration Test

Do NOT test every instruction immediately.

Use the instructions already present in Instruction Memory:

```text
Address 0:
ADDI x1, x0, 5

Address 4:
ADDI x2, x0, 10

Address 8:
ADD x3, x1, x2

Address 12:
NOP
```

Expected execution:

### Cycle 1

```text
PC = 0
ADDI x1,x0,5

x1 = 5
```

### Cycle 2

```text
PC = 4
ADDI x2,x0,10

x2 = 10
```

### Cycle 3

```text
PC = 8
ADD x3,x1,x2

x3 = 15
```

### Cycle 4

```text
PC = 12
NOP
```

Final expected register state:

```text
x0 = 0
x1 = 5
x2 = 10
x3 = 15
```

---

# 34. How the CPU Testbench Will Check This

Create:

```text
tb/tb_riscv_cpu.v
```

The testbench needs:

```verilog
reg clk;
reg reset;
```

Instantiate:

```verilog
riscv_cpu dut (
    .clk(clk),
    .reset(reset)
);
```

Generate clock:

```verilog
always #5 clk = ~clk;
```

Apply reset initially:

```text
reset = 1
```

Then release reset:

```text
reset = 0
```

Let the CPU run for several clock cycles.

For debugging, the testbench can inspect internal registers using hierarchical access such as:

```verilog
dut.rf.registers[1]
```

if the Register File instance is named `rf` and its internal array is named `registers`.

If your actual Register File uses a different instance/array name, use that exact name.

---

# 35. First Integration Success Criteria

The first integration test is successful only if:

```text
PC advances:
0 → 4 → 8 → 12 ...

AND

x1 becomes 5

AND

x2 becomes 10

AND

x3 becomes 15

AND

x0 remains 0
```

This proves that:

```text
PC
+
Instruction Memory
+
Control
+
Register File
+
Immediate Generator
+
ALU Control
+
MUXes
+
ALU
+
Writeback
```

are working together.

---

# 36. Second Integration Test — Memory

After the first test passes, add instructions for:

```text
SW
LW
```

Expected behavior:

```text
register → ALU address calculation
         → Data Memory
         → memory read/write
         → Writeback
```

Verify:

```text
SW stores correct value
LW loads the same value
```

---

# 37. Third Integration Test — Branch

Test:

```text
BEQ
```

Use one case where:

```text
rs1 == rs2
```

and one where:

```text
rs1 != rs2
```

Verify:

```text
equal:
PC = PC + immediate

not equal:
PC = PC + 4
```

---

# 38. Fourth Integration Test — Jumps

Test:

```text
JAL
JALR
```

For each one verify two separate things:

### PC target

```text
PC changes to correct target
```

### Return address

```text
rd = old PC + 4
```

---

# 39. Fifth Integration Test — LUI/AUIPC

Verify:

```text
LUI:
rd = immediate
```

and:

```text
AUIPC:
rd = old PC + immediate
```

---

# 40. Final Instruction Coverage

Before declaring the CPU complete, test:

```text
R-type:
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

I-type:
ADDI
ANDI
ORI
XORI
SLTI
SLTIU
SLLI
SRLI
SRAI

Memory:
LW
SW

Branch:
BEQ

Jump:
JAL
JALR

Upper:
LUI
AUIPC
```

---

# 41. Coding Order You Should Follow

When actually writing `riscv_cpu.v`, follow this exact order:

```text
STEP 1
Create module declaration

        ↓

STEP 2
Declare PC wires

        ↓

STEP 3
Declare instruction wire

        ↓

STEP 4
Declare register-file wires

        ↓

STEP 5
Declare immediate wire

        ↓

STEP 6
Declare all control wires

        ↓

STEP 7
Declare ALU wires

        ↓

STEP 8
Declare memory wires

        ↓

STEP 9
Declare PC-target wires

        ↓

STEP 10
Instantiate Program Counter

        ↓

STEP 11
Instantiate Instruction Memory

        ↓

STEP 12
Instantiate Main Control

        ↓

STEP 13
Instantiate Register File

        ↓

STEP 14
Instantiate Immediate Generator

        ↓

STEP 15
Instantiate ALU Control

        ↓

STEP 16
Instantiate Datapath MUXes

        ↓

STEP 17
Instantiate ALU

        ↓

STEP 18
Instantiate Data Memory

        ↓

STEP 19
Instantiate PC Logic

        ↓

STEP 20
Compile

        ↓

STEP 21
Fix connection errors

        ↓

STEP 22
Create CPU testbench

        ↓

STEP 23
Run ADDI + ADD test

        ↓

STEP 24
Verify x1=5, x2=10, x3=15
```

---

# 42. Most Important Connections — Quick Reference

```text
PC
→ Instruction Memory address

Instruction
→ Main Control
→ Register File register numbers
→ Immediate Generator
→ ALU Control

Register File rs1_data
→ Datapath MUX A
→ PC Logic

Register File rs2_data
→ Datapath MUX B
→ Data Memory write_data

Immediate
→ Datapath MUX B
→ Writeback MUX
→ PC Logic

Control
→ MUXes
→ ALU Control
→ Data Memory
→ PC Logic

MUX A
→ ALU A

MUX B
→ ALU B

ALU Control
→ ALU

ALU
→ Data Memory address
→ Writeback MUX
→ PC Logic zero

Data Memory
→ Writeback MUX

PC + 4
→ Writeback MUX
→ PC Logic

Writeback MUX
→ Register File write_data

PC Logic
→ PC_next

PC_next
→ Program Counter
```

---

# 43. Final Mental Model

Before writing the code, remember this:

```text
             WHAT INSTRUCTION?
                    │
                    ↓
             Main Control
                    │
          ┌─────────┼─────────┐
          ↓         ↓         ↓
       Register   ALU      PC Logic
        File      Control
          │         │
          └────┬────┘
               ↓
              MUX
               ↓
              ALU
               ↓
         ┌─────┴─────┐
         ↓           ↓
      Memory      Writeback
         │           │
         └─────┬─────┘
               ↓
          Register File
```

The key idea is:

> **`riscv_cpu.v` is the connection layer. The individual modules already contain the actual hardware behavior.**

Do not add unnecessary logic to the top-level module.

---

# 44. What You Should Do Next

Do **not** write the complete CPU from memory yet.

Use this document while writing it.

Your next coding sequence should be:

```text
1. Create rtl/riscv_cpu.v
2. Write module declaration
3. Declare wires
4. Instantiate Program Counter
5. Instantiate Instruction Memory
6. Stop and compile
7. Add Main Control
8. Compile
9. Add Register File
10. Compile
11. Continue one module at a time
```

This incremental approach makes debugging much easier than writing 150+ lines at once.

