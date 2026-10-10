# We have to design RISCV Processor so first we will see its ISA 
# Phase 1
- first we will design hardware components
- first will be program counter(pc)
- second will be Instruction Memory
- third will be Register file
- ALU
- Immediate generator
- Main control unit
- ALU Control unit
- Data memory
- Muxs/branch jump logic
  
```
1. Program Counter (PC)
          ↓
2. Instruction Memory
          ↓
3. Register File
          ↓
4. ALU
          ↓
5. Immediate Generator
          ↓
6. Main Control Unit
          ↓
7. ALU Control Unit
          ↓
8. Data Memory
          ↓
9. MUXes + Branch/Jump logic
```

## For each component
```
Theory
  ↓
Inputs / Outputs
  ↓
Hardware behavior
  ↓
Example
  ↓
Verilog
  ↓
Line-by-line explanation
  ↓
Testbench
  ↓
Simulation / expected result
```

# Phase 2 Connect each component
```
             ┌────────────────────┐
             │ Instruction Memory │
             └──────────┬─────────┘
                        │
                        ▼
                 ┌─────────────┐
                 │   Control   │
                 │    Unit     │
                 └─────────────┘
                        │
          ┌─────────────┼──────────────┐
          ▼             ▼              ▼
    Register File   Immediate       ALU Control
          │          Generator           │
          └────────────┬─────────────────┘
                       ▼
                      ALU
                       │
                       ▼
                 Data Memory
                       │
                       ▼
                   Writeback
                       │
                       ▼
                 Register File
```

# Final Processor
- we will create a top_level file where we will connect components together
```
PC
Instruction Memory
Register File
Immediate Generator
ALU
ALU Control
Main Control
Data Memory
MUXes
Branch/Jump logic
```

# Now we will include ISA logic RV32I instructions
## R-type Instructions
```
funct7 | rs2 | rs1 | funct3 | rd | opcode
```

### Total 10 Instructions
```
ADD
SUB
SLL
SLT
SLTU
XOR
SRL
SRA
OR
AND
```

## I- type Instructions
```
ADDI
SLLI
SLTI
SLTIU
XORI
SRLI
SRAI
ORI
ANDI
```
### We have also load instructions in I format

## S-type Instructions
```
SB
SH
SW
```

## SB-type Instructions
```
BEQ
BNE
BLT
BGE
BLTU
BGEU
```

## U-type Instructions
```
LUI
AUIPC
```

## UJ/jump-type Instructions
```
JAL
JALR
```

# Whole Project Hierarchy 
```
                 RV32I
                   │
                   ▼
          SINGLE-CYCLE CPU
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
 HARDWARE COMPONENTS      ISA SUPPORT
        │                     │
        │              ┌──────┴──────┐
        │              │             │
        ▼              ▼             ▼
       PC           R-type        I-type
       IMEM         S-type        SB-type
       RegFile      U-type        UJ-type
       ALU
       ImmGen
       Control
       ALUControl
       DataMem
       MUXes
        │
        ▼
   TEST EACH ONE
        │
        ▼
  CONNECT EVERYTHING
        │
        ▼
   riscv_cpu.v
        │
        ▼
    TESTBENCH
        │
        ▼
   COMPLETE CPU
```


## 1. Designing PC(program Counter)
PC (Program Counter) current instruction ka address store karta hai, next instruction ka address directly nahi. Jaise agar PC = 0 hai, toh instruction memory address 0 wali instruction fetch karegi; saath hi processor calculate karega ki normal case mein next instruction ka address PC + 4 = 4 hoga, jise hum PC_next bolenge. Clock edge aane par PC ← PC_next ho jayega, yani PC ab 4 ho jayega aur address 4 wali instruction fetch hogi. Isliye PC = current instruction address aur PC_next = next instruction address. Normal instruction ke liye PC_next = PC + 4, lekin branch/jump mein PC_next branch ya jump target ho sakta hai. Tumhare notes mein bhi PC ko current instruction ka address hold karne wala register define kiya gaya hai.     6. RISC V ISA.pptx

- Program Counter is a Register inside the processor that stores 
- The memory address of the instruction currently being executed

### Suppose our instruction memory contains

```
Address       Instruction
────────────────────────────
0             ADDI x1,x0,10
4             ADDI x2,x0,20
8             ADD  x3,x1,x2
12            SUB  x4,x3,x1
```

### Then our PC will move like
```
PC = 0
   ↓
fetch instruction at address 0

PC = 4
   ↓
fetch instruction at address 4

PC = 8
   ↓
fetch instruction at address 8

PC = 12
   ↓
fetch instruction at address 12
```

- RV32I me Integer registers 32 bits wide hote hai yaani ki 4 bytes 
- Therefore in verilog
```
reg [31:0] pc;
```

- Yanni ki PC = 32 bits
