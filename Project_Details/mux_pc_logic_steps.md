# MUXes + PC / Branch / Jump Logic — Step-by-Step Guide
## Single-Cycle RISC-V RV32I Processor

> **Project stage:** PC → Instruction Memory → Register File → ALU → Immediate Generator → Main Control → ALU Control → Data Memory → **MUXes + PC/Branch/Jump Logic**
>
> This stage connects the individual components. We are still not writing the complete `riscv_cpu.v`; first we test the selection/next-PC logic independently.

---

# 1. Why do we need MUXes?

A MUX (Multiplexer) selects one of several inputs.

Think:

```text
          input 0 ───┐
                     │
          input 1 ───┤
                     ├──→ selected output
          input 2 ───┤
                     │
          input 3 ───┘
```

The control signal tells the MUX which input to select.

Our single-cycle processor needs MUXes because the same ALU and write-back path are used by different instruction types.

---

# 2. MUXes we need

We need to handle:

1. ALU input A selection
2. ALU input B selection
3. Register write-back selection
4. Next-PC selection

These are not all the same MUX.

---

# 3. ALU input A MUX

Our ALU's first input can be:

```text
rs1 data
PC
0
```

This is why our Main Control Unit has:

```text
ALUSrcA
```

We defined:

```text
00 → rs1
01 → PC
10 → 0
```

So:

```text
                  rs1_data
                     |
                     |
PC ------------------+----+
                     |    |
0 -------------------+    |
                          v
                       ALU A
```

Conceptually this is a 3-input MUX.

---

# 4. Why does AUIPC need PC?

AUIPC means:

```text
rd = PC + immediate
```

Therefore:

```text
ALU A = PC
ALU B = immediate
```

So:

```text
ALUSrcA = 01
ALUSrc  = 1
```

The ALU performs:

```text
PC + immediate
```

---

# 5. Why does normal arithmetic use rs1?

For:

```text
ADD x3, x1, x2
```

we need:

```text
ALU A = x1
ALU B = x2
```

Therefore:

```text
ALUSrcA = 00
ALUSrc = 0
```

For:

```text
ADDI x3, x1, 5
```

we need:

```text
ALU A = x1
ALU B = 5
```

Therefore:

```text
ALUSrcA = 00
ALUSrc = 1
```

---

# 6. Why did we include zero?

For LUI:

```text
LUI x5, 0x12345
```

the required result is:

```text
0x12345000
```

Our Immediate Generator already produces:

```text
0x12345000
```

So the final write-back path can select the immediate directly.

The zero option is useful if the ALU datapath is used to form:

```text
0 + immediate
```

It is therefore an available datapath choice, even though the final design can choose the direct-immediate write-back path for LUI.

---

# 7. ALU input B MUX

The second ALU input can be:

```text
rs2_data
immediate
```

Our Main Control signal is:

```text
ALUSrc
```

Meaning:

```text
ALUSrc = 0 → rs2
ALUSrc = 1 → immediate
```

---

# 8. Examples of ALU B selection

### R-type

```text
ADD x3, x1, x2
```

```text
ALUSrc = 0
```

Therefore:

```text
ALU B = x2
```

### ADDI

```text
ADDI x3, x1, 5
```

```text
ALUSrc = 1
```

Therefore:

```text
ALU B = immediate
```

### LW

```text
LW x5, 8(x2)
```

Address:

```text
x2 + 8
```

Therefore:

```text
ALUSrc = 1
```

### SW

```text
SW x5, 8(x2)
```

Address:

```text
x2 + 8
```

Therefore:

```text
ALUSrc = 1
```

---

# 9. PC + 4

RV32I base instructions are 32 bits and aligned on four-byte boundaries.

Therefore, for normal sequential execution:

```text
PC_next = PC + 4
```

This is the default path.

Example:

```text
PC = 0
next = 4

PC = 4
next = 8

PC = 8
next = 12
```

This is why your Program Counter earlier received values such as:

```text
0 → 4 → 8 → 12
```

---

# 10. Branch target

For a conditional branch such as:

```text
BEQ x1, x2, offset
```

the branch target is PC-relative.

Our Immediate Generator reconstructs the branch immediate with bit 0 equal to zero.

The target is:

```text
branch_target = PC + immediate
```

So we need an adder:

```text
PC -----------+
              |
              v
             ADD ----→ branch_target
              ^
              |
          immediate
```

---

# 11. Branch decision

For BEQ, the processor must check:

```text
x1 == x2
```

Our ALU can do:

```text
x1 - x2
```

and provides:

```text
zero
```

If:

```text
x1 - x2 = 0
```

then:

```text
zero = 1
```

Therefore the branch is taken when:

```text
Branch AND zero
```

is true.

---

# 12. Branch PC selection

We have two possible PC values:

```text
PC + 4
branch_target
```

So:

```text
if (Branch && zero)
    pc_next = branch_target;
else
    pc_next = PC + 4;
```

Hardware:

```text
                 PC + 4
                   |
                   |
                   v
                 +---+
                 |MUX|----→ PC_next
                 +---+
                   ^
                   |
             branch_target

             select =
             Branch & zero
```

---

# 13. JAL

JAL means:

```text
rd = PC + 4
PC = PC + immediate
```

Therefore there are TWO effects:

### Effect 1

Jump the PC:

```text
PC_next = PC + immediate
```

### Effect 2

Save return address:

```text
rd = PC + 4
```

The PC target and write-back value are separate paths.

---

# 14. JAL target

The JAL immediate is produced by the Immediate Generator.

Therefore:

```text
jal_target = PC + immediate
```

This uses the same basic PC-relative addition idea as a branch.

---

# 15. JALR

JALR means:

```text
rd = PC + 4
PC = rs1 + immediate
```

Therefore its target is different:

```text
jalr_target = rs1 + immediate
```

So:

```text
JAL:
    PC + immediate

JALR:
    rs1 + immediate
```

---

# 16. JALR LSB rule

For JALR, the target address has its least-significant bit cleared.

So:

```text
jalr_target = (rs1 + immediate) & 32'hFFFFFFFE
```

This means:

```text
bit 0 = 0
```

after calculating the target.

---

# 17. Next-PC choices

Our processor eventually needs to select among:

```text
PC + 4
branch target
JAL target
JALR target
```

Conceptually:

```text
                    +--------+
PC + 4 ------------>|        |
Branch target ------>|        |
JAL target --------->|  MUX   |----→ PC_next
JALR target -------->|        |
                    +--------+
                         ^
                         |
                   PC control
```

The exact selection can be implemented using conditional logic rather than one literal 4-input MUX.

---

# 18. Priority of PC selection

We need a deterministic order.

A clean priority is:

```text
1. JALR
2. JAL
3. taken branch
4. PC + 4
```

So:

```text
if (jalr)
    pc_next = jalr_target;
else if (jump)
    pc_next = jal_target;
else if (branch && zero)
    pc_next = branch_target;
else
    pc_next = pc_plus_4;
```

Why check JALR before JAL?

Because both use the `jump` concept, but JALR has a different target source.

---

# 19. Why is JALR checked first?

Our Main Control signals are:

For JAL:

```text
jump = 1
jalr = 0
```

For JALR:

```text
jump = 1
jalr = 1
```

Therefore:

```text
if (jalr)
```

must be checked before:

```text
else if (jump)
```

Otherwise every JALR could accidentally be treated as JAL.

---

# 20. Write-back MUX

Now we have another important MUX.

What can be written into `rd`?

Depending on the instruction, it can be:

```text
ALU result
memory read_data
PC + 4
immediate
```

Examples:

### ADD

```text
rd = ALU result
```

### LW

```text
rd = memory data
```

### JAL/JALR

```text
rd = PC + 4
```

### LUI

```text
rd = immediate
```

Therefore a simple two-input:

```text
MemToReg
```

is not enough for the complete processor.

We need a multi-way write-back selection.

---

# 21. Write-back source

For the complete processor, we will use a new conceptual signal:

```text
ResultSrc
```

with:

```text
00 → ALU result
01 → Memory data
10 → PC + 4
11 → Immediate
```

This is an implementation decision for our final datapath.

It replaces the earlier simple two-way `MemToReg` concept.

---

# 22. Why are we changing from MemToReg?

Earlier, `MemToReg` was useful for explaining:

```text
ALU result vs memory result
```

But after considering the complete RV32I datapath, we discovered that JAL/JALR and LUI require additional write-back sources.

So a 4-way `ResultSrc` is cleaner:

```text
ALU
Memory
PC+4
Immediate
```

This is not a correction to the RISC-V ISA. It is simply a better implementation interface for our processor.

---

# 23. ResultSrc table

| Instruction | ResultSrc |
|---|---|
| R-type | `00` ALU |
| I-type arithmetic | `00` ALU |
| LW | `01` Memory |
| SW | no register write |
| BEQ | no register write |
| JAL | `10` PC+4 |
| JALR | `10` PC+4 |
| LUI | `11` Immediate |
| AUIPC | `00` ALU |

For AUIPC:

```text
ALU = PC + immediate
```

so the ALU result is written back.

---

# 24. Important consequence for Main Control

Our previous Main Control Unit has:

```text
MemToReg
```

For the final integrated processor, we should eventually replace that with:

```text
ResultSrc[1:0]
```

This is because:

```text
MemToReg
```

can only describe:

```text
ALU vs memory
```

while:

```text
ResultSrc
```

can describe:

```text
ALU
Memory
PC+4
Immediate
```

We will make this change when integrating the final top-level CPU.

---

# 25. Complete datapath idea

The processor is now becoming:

```text
                         PC
                         |
              +----------+----------+
              |                     |
              v                     v
      Instruction Memory          PC + 4
              |
              v
         Instruction
          /       \
         /         \
        v           v
 Main Control   Immediate Gen.
      |              |
      |              |
      v              |
 Register File       |
   |       |         |
 rs1     rs2         |
   |       |         |
   |       +----+----+
   |            |
   v            v
 ALU A MUX    ALU B MUX
      \          /
       \        /
        v      v
          ALU
           |
           +----------→ Data Memory
           |                |
           |                v
           |            read_data
           |
           v
      Write-back MUX
           |
           v
      Register File
```

And separately:

```text
PC + immediate → branch/JAL target
rs1 + immediate → JALR target

branch & zero
      |
      v
 PC selection
      |
      v
   PC_next
      |
      v
       PC
```

---

# 26. Why do we not put everything into one ALU?

We could calculate many things with the ALU, but the processor still needs multiple values in the same cycle.

For example:

```text
PC + 4
```

is needed for normal execution and for JAL/JALR write-back.

At the same time:

```text
ALU
```

may be calculating:

```text
rs1 + immediate
```

for a load/store.

Therefore separate small adders or equivalent combinational logic are useful in a single-cycle datapath.

---

# 27. PC + 4 adder

We can simply write:

```verilog
assign pc_plus_4 = pc + 32'd4;
```

This is combinational.

No separate clock is needed.

The PC itself is still the sequential element.

---

# 28. Branch/JAL target adder

We can write:

```verilog
assign branch_target = pc + immediate;
```

Because the immediate generator already produces the properly reconstructed 32-bit branch/JAL immediate.

For JAL:

```text
jal_target = pc + immediate
```

The same arithmetic can be reused.

---

# 29. JALR target

We can write:

```verilog
assign jalr_target =
    (rs1_data + immediate) & 32'hFFFFFFFE;
```

The mask clears bit 0.

---

# 30. Next-PC logic module

We can make a small combinational module:

Inputs:

```text
pc
immediate
rs1_data
branch
zero
jump
jalr
```

Output:

```text
pc_next
```

It calculates:

```text
pc_plus_4
branch_target
jal_target
jalr_target
```

and chooses one.

---

# 31. Why test this separately?

Because PC logic is critical.

If the PC logic is wrong, even a correct ALU, memory, register file and control unit will not make the processor work.

We should therefore test:

1. Normal PC + 4
2. Taken branch
3. Not-taken branch
4. JAL
5. JALR
6. JALR LSB clearing

before integrating the entire CPU.

---

# 32. Example — normal instruction

Suppose:

```text
PC = 0
```

and the instruction is ADD.

No branch:

```text
branch = 0
```

No jump:

```text
jump = 0
```

Therefore:

```text
PC_next = PC + 4
        = 4
```

Next cycle:

```text
PC = 4
```

---

# 33. Example — taken BEQ

Suppose:

```text
PC = 100
immediate = 8
branch = 1
zero = 1
```

Then:

```text
branch_target = 100 + 8
              = 108
```

and:

```text
branch && zero = 1
```

Therefore:

```text
PC_next = 108
```

---

# 34. Example — not-taken BEQ

Suppose:

```text
PC = 100
immediate = 8
branch = 1
zero = 0
```

Then:

```text
branch && zero = 0
```

Therefore:

```text
PC_next = 104
```

The branch is not taken.

---

# 35. Example — JAL

Suppose:

```text
PC = 100
immediate = 20
jump = 1
jalr = 0
```

Then:

```text
jal_target = 120
```

Therefore:

```text
PC_next = 120
```

At the same time, the write-back value is:

```text
PC + 4 = 104
```

which goes into `rd`.

---

# 36. Example — JALR

Suppose:

```text
PC = 100
rs1 = 200
immediate = 16
jump = 1
jalr = 1
```

Then:

```text
jalr_target = 200 + 16
            = 216
```

Therefore:

```text
PC_next = 216
```

and:

```text
rd = 104
```

because:

```text
PC + 4 = 104
```

---

# 37. JALR alignment example

Suppose:

```text
rs1 + immediate = 217
```

Binary ends in:

```text
...0001
```

The JALR target must have bit 0 cleared:

```text
217 → 216
```

Therefore:

```verilog
target = target & 32'hFFFFFFFE;
```

---

# 38. Testbench plan

The next code will contain two small combinational modules:

### Module 1

```text
datapath_muxes
```

This handles:

- ALU A selection
- ALU B selection
- write-back selection

### Module 2

```text
pc_logic
```

This handles:

- PC + 4
- branch target
- JAL target
- JALR target
- next PC

We will test them independently.

---

# 39. Why separate modules instead of one huge module?

Because you are learning the processor architecture.

Small modules let us verify:

```text
MUX logic
```

and:

```text
PC logic
```

independently.

Then `riscv_cpu.v` will connect them.

This is also much easier to debug.

---

# 40. Summary

At this stage, remember:

### ALU A

```text
ALUSrcA:
00 → rs1
01 → PC
10 → 0
```

### ALU B

```text
ALUSrc:
0 → rs2
1 → immediate
```

### Write-back

```text
ResultSrc:
00 → ALU
01 → Memory
10 → PC+4
11 → Immediate
```

### PC selection

```text
JALR → rs1 + immediate
JAL  → PC + immediate
BEQ  → PC + immediate if branch && zero
else → PC + 4
```

---

# 41. Next step

After testing these modules, the final integration becomes much easier:

```text
riscv_cpu.v
```

will connect:

```text
PC
Instruction Memory
Register File
Immediate Generator
Main Control
ALU Control
ALU
Data Memory
MUXes
PC Logic
```

At that point we can run actual instruction sequences such as:

```text
ADDI x1, x0, 5
ADDI x2, x0, 10
ADD  x3, x1, x2
```

and eventually:

```text
SW
LW
BEQ
JAL
JALR
LUI
AUIPC
```

through the complete processor.
