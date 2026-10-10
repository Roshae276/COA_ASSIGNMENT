# ALU (Arithmetic Logic Unit) — Complete Step-by-Step Guide
## Single-Cycle RISC-V RV32I Processor in Verilog

This document explains the ALU from the hardware level to the Verilog implementation and testbench.

The goal is to understand the ALU before connecting it to the complete RISC-V processor.

---

# 1. Where We Are

We are building a single-cycle RV32I processor component by component.

```text
[✓] Program Counter
[✓] Instruction Memory
[✓] Register File
[ ] ALU                    <-- CURRENT
[ ] Immediate Generator
[ ] Main Control Unit
[ ] ALU Control Unit
[ ] Data Memory
[ ] MUXes + Branch/Jump Logic
[ ] Top-Level CPU
```

The next major hardware component is the:

```text
ALU = Arithmetic Logic Unit
```

The ALU performs arithmetic and logical operations on 32-bit values.

---

# 2. What Is an ALU?

ALU stands for:

```text
Arithmetic Logic Unit
```

It is the part of the processor that performs operations such as:

```text
Addition
Subtraction
AND
OR
XOR
Comparison
Left shift
Logical right shift
Arithmetic right shift
```

For RV32I, the ALU is needed by many instruction types.

For example:

```text
ADD x3, x1, x2
```

means:

```text
x3 = x1 + x2
```

The Register File gives the ALU:

```text
x1 value
x2 value
```

The ALU performs:

```text
x1 + x2
```

and produces the result.

---

# 3. Basic ALU Hardware Flow

The basic structure is:

```text
              Operand A
                  |
                  v
            +-----------+
            |           |
Operand B -->|    ALU    |----> ALU Result
            |           |
ALU Control->|           |
            +-----------+
```

The ALU has three important inputs:

```text
Operand A
Operand B
ALU Control
```

and one main output:

```text
ALU Result
```

For our 32-bit processor:

```text
Operand A     = 32 bits
Operand B     = 32 bits
ALU Result    = 32 bits
ALU Control   = control code
```

---

# 4. How the ALU Connects to the Register File

We just completed the Register File.

The Register File provides:

```text
read_data1
read_data2
```

These become ALU operands for instructions such as R-type arithmetic instructions.

Conceptually:

```text
             Register File
             +------------+
      rs1 -->|            |--> read_data1 ----+
      rs2 -->|            |--> read_data2 ----+----> ALU
             +------------+                    |
                                               |
                                         ALU operation
                                               |
                                               v
                                         ALU result
```

Example:

```text
ADD x3, x1, x2
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

The ALU performs:

```text
10 + 20 = 30
```

and:

```text
ALU result = 30
```

Later, the result is written into:

```text
x3
```

---

# 5. Why Does the ALU Need a Control Signal?

The ALU can perform many different operations.

Suppose:

```text
A = 10
B = 20
```

The ALU could calculate:

```text
10 + 20 = 30
10 - 20 = -10
10 & 20 = 0
10 | 20 = 30
10 ^ 20 = 30
```

It needs to know which operation the current instruction requests.

Therefore we provide:

```text
ALU Control
```

Conceptually:

```text
             +----------------+
A ---------->|                |
             |                |
B ---------->|      ALU       |----> Result
             |                |
Control ---->|                |
             +----------------+
```

The ALU Control signal selects the operation.

---

# 6. ALU Control Width

For the first ALU implementation, we can use a 4-bit control signal.

That gives:

```text
2^4 = 16
```

possible control codes.

We only need a subset of them.

For example, we can define:

```text
0000 -> ADD
0001 -> SUB
0010 -> AND
0011 -> OR
0100 -> XOR
0101 -> SLT
0110 -> SLL
0111 -> SRL
1000 -> SRA
```

These are internal control codes.

Important:

These 4-bit codes are our ALU's internal design choice. They are not the same thing as the 7-bit RISC-V opcode or the 3-bit `funct3` field.

The later ALU Control Unit will convert instruction fields into these ALU control codes.

---

# 7. RISC-V Operations Relevant to the ALU

The RV32I R-format arithmetic/logical instructions include:

```text
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

The ALU therefore needs to support these operations for the processor.

There are also immediate versions such as:

```text
ADDI
SLTI
SLTIU
XORI
ORI
ANDI
SLLI
SRLI
SRAI
```

The same ALU can perform the actual arithmetic/logic operation; only the source of the second operand changes.

For example:

```text
ADD:
    A = register value
    B = register value

ADDI:
    A = register value
    B = immediate value
```

The ALU itself can still perform:

```text
A + B
```

---

# 8. First Understand the ALU Inputs

We will define:

```verilog
input wire [31:0] a
```

This is the first 32-bit operand.

And:

```verilog
input wire [31:0] b
```

This is the second 32-bit operand.

And:

```verilog
input wire [3:0] alu_control
```

This tells the ALU which operation to perform.

Output:

```verilog
output reg [31:0] result
```

This contains the 32-bit result.

---

# 9. Why Is `result` a `reg`?

We will implement the ALU using:

```verilog
always @(*)
```

Inside that block, we assign:

```verilog
result = ...
```

A variable assigned inside a procedural `always` block is declared as `reg` in traditional Verilog.

So:

```verilog
output reg [31:0] result;
```

is appropriate.

This does NOT mean the ALU result is a physical storage register.

The ALU is combinational.

The `reg` keyword here is a Verilog variable type.

---

# 10. What Is `always @(*)`?

We want the ALU to react whenever any input changes.

The inputs are:

```text
a
b
alu_control
```

So instead of writing:

```verilog
always @(a or b or alu_control)
```

we can write:

```verilog
always @(*)
```

The `*` tells Verilog:

> Include all signals used by this combinational block in the sensitivity list.

So:

```verilog
always @(*) begin
```

is commonly used for combinational logic.

---

# 11. Combinational Logic vs Sequential Logic

This distinction is extremely important.

## Register File write

We used:

```verilog
always @(posedge clk)
```

because writing a register is clocked.

## ALU

The ALU does not need to store a value.

If:

```text
a = 10
b = 20
control = ADD
```

the result should simply be:

```text
result = 30
```

There is no reason to wait for a clock.

Therefore:

```verilog
always @(*)
```

is appropriate.

So remember:

```text
Register storage:
    always @(posedge clk)

Combinational ALU:
    always @(*)
```

---

# 12. ALU Operation Table

We can define our internal ALU control table as:

| ALU Control | Operation |
|---|---|
| `0000` | ADD |
| `0001` | SUB |
| `0010` | AND |
| `0011` | OR |
| `0100` | XOR |
| `0101` | SLT |
| `0110` | SLL |
| `0111` | SRL |
| `1000` | SRA |

We can later add:

```text
SLTU
```

if needed.

For a complete RV32I ALU, supporting `SLTU` is recommended.

We can assign:

```text
1001 -> SLTU
```

Then:

```text
0000 -> ADD
0001 -> SUB
0010 -> AND
0011 -> OR
0100 -> XOR
0101 -> SLT
0110 -> SLL
0111 -> SRL
1000 -> SRA
1001 -> SLTU
```

---

# 13. ADD Operation

The simplest operation:

```verilog
result = a + b;
```

Example:

```text
a = 10
b = 20

result = 30
```

For:

```text
ADD x3, x1, x2
```

the ALU receives:

```text
a = x1
b = x2
```

and produces:

```text
x1 + x2
```

---

# 14. SUB Operation

Subtraction:

```verilog
result = a - b;
```

Example:

```text
a = 20
b = 10

result = 10
```

For:

```text
SUB x3, x1, x2
```

the ALU performs:

```text
x1 - x2
```

---

# 15. AND Operation

Bitwise AND:

```verilog
result = a & b;
```

This operates independently on each bit.

Example:

```text
a = 1100
b = 1010

a & b
  = 1000
```

For 32-bit values, the same operation happens across all 32 bit positions.

---

# 16. OR Operation

Bitwise OR:

```verilog
result = a | b;
```

Example:

```text
a = 1100
b = 1010

a | b
  = 1110
```

---

# 17. XOR Operation

Bitwise XOR:

```verilog
result = a ^ b;
```

Example:

```text
a = 1100
b = 1010

a ^ b
  = 0110
```

XOR produces 1 when the two corresponding bits are different.

---

# 18. SLT — Set Less Than

RISC-V has:

```text
SLT
```

which means:

```text
Set Less Than
```

It compares two signed values.

The result is:

```text
1 if a < b
0 otherwise
```

In Verilog:

```verilog
result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
```

Example:

```text
a = 5
b = 10
```

Since:

```text
5 < 10
```

the result is:

```text
1
```

As a 32-bit value:

```text
00000001
```

If:

```text
a = 10
b = 5
```

then:

```text
result = 0
```

---

# 19. Why Do We Need `$signed`?

This is an important Verilog concept.

A 32-bit binary pattern can be interpreted as:

```text
unsigned
```

or:

```text
signed
```

For example:

```text
11111111...
```

can represent a very large unsigned number or a negative signed number.

RISC-V's `SLT` performs a signed comparison.

Therefore:

```verilog
$signed(a)
```

tells Verilog to interpret `a` as signed.

Similarly:

```verilog
$signed(b)
```

interprets `b` as signed.

So:

```verilog
$signed(a) < $signed(b)
```

performs the required signed comparison.

---

# 20. SLTU — Unsigned Less Than

RISC-V also has:

```text
SLTU
```

This means:

```text
Set Less Than Unsigned
```

For unsigned comparison:

```verilog
result = (a < b) ? 32'd1 : 32'd0;
```

Do not use `$signed()` here.

Example:

```text
a = 5
b = 10
```

result:

```text
1
```

---

# 21. SLL — Shift Left Logical

SLL means:

```text
Shift Left Logical
```

Verilog operator:

```verilog
<<
```

So:

```verilog
result = a << b[4:0];
```

Example:

```text
a = 00000101
```

which is:

```text
5
```

Shift left by 1:

```text
00001010
```

which is:

```text
10
```

For RV32, the shift amount for register-register shifts uses the lower 5 bits of the second operand.

Therefore:

```verilog
b[4:0]
```

is used as the shift amount.

---

# 22. Why `b[4:0]` for Shifts?

The ALU operands are 32 bits.

But a 32-bit value only needs a shift amount from:

```text
0 to 31
```

How many bits are needed?

```text
2^5 = 32
```

Therefore 5 bits are enough.

So:

```verilog
b[4:0]
```

provides a shift amount in:

```text
0–31
```

---

# 23. SRL — Shift Right Logical

SRL means:

```text
Shift Right Logical
```

Verilog:

```verilog
result = a >> b[4:0];
```

Logical right shift fills the left side with zeros.

Example:

```text
a = 10100000
```

shift right by 2:

```text
00101000
```

---

# 24. SRA — Shift Right Arithmetic

SRA means:

```text
Shift Right Arithmetic
```

The difference from SRL is how the left side is filled.

SRL:

```text
fill with 0
```

SRA:

```text
preserve the sign bit
```

This matters for signed negative numbers.

We can write:

```verilog
result = $signed(a) >>> b[4:0];
```

The `>>>` operator is arithmetic right shift.

---

# 25. `>>` vs `>>>`

Remember:

```text
>>   = logical right shift behavior for an unsigned value
>>>  = arithmetic right shift
```

For SRA, we want:

```verilog
$signed(a) >>> b[4:0]
```

because the operand must be treated as signed.

---

# 26. Complete ALU Module

After understanding the operations, the ALU can be implemented as:

```verilog
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control,
    output reg  [31:0] result
);

    always @(*) begin

        case (alu_control)

            4'b0000: begin
                result = a + b;
            end

            4'b0001: begin
                result = a - b;
            end

            4'b0010: begin
                result = a & b;
            end

            4'b0011: begin
                result = a | b;
            end

            4'b0100: begin
                result = a ^ b;
            end

            4'b0101: begin
                result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            end

            4'b0110: begin
                result = a << b[4:0];
            end

            4'b0111: begin
                result = a >> b[4:0];
            end

            4'b1000: begin
                result = $signed(a) >>> b[4:0];
            end

            4'b1001: begin
                result = (a < b) ? 32'd1 : 32'd0;
            end

            default: begin
                result = 32'd0;
            end

        endcase

    end

endmodule
```

---

# 27. Understand `case`

The ALU needs to select one operation based on `alu_control`.

Instead of writing many `if` statements, we can use:

```verilog
case (alu_control)
```

For example:

```verilog
4'b0000:
```

means:

```text
if alu_control = 0000
```

then perform ADD.

```verilog
4'b0001:
```

means:

```text
if alu_control = 0001
```

then perform SUB.

And so on.

---

# 28. Why Do We Have a `default`?

We include:

```verilog
default:
    result = 32'd0;
```

If an unsupported control code appears, the ALU gets a known output.

Without a default assignment, a combinational block can accidentally infer unwanted storage/latch behavior if some paths do not assign `result`.

The default makes the intended behavior explicit.

---

# 29. Why Do We Not Need a Clock?

Notice the ALU module has:

```text
a
b
alu_control
result
```

but no:

```text
clk
```

That is intentional.

The ALU is combinational.

For example:

```text
a = 10
b = 20
control = ADD
```

produces:

```text
result = 30
```

without waiting for a clock edge.

The clock is needed by storage elements such as:

```text
Program Counter
Register File write
```

but not by the basic combinational ALU.

---

# 30. ALU Testbench

We should test the ALU independently before connecting it to the Register File.

Since the ALU is combinational:

```text
No clock is required.
```

We can simply change inputs and observe the result.

Create:

```text
tb/tb_alu.v
```

Use:

```verilog
`timescale 1ns/1ps

module tb_alu;

    reg [31:0] a;
    reg [31:0] b;
    reg [3:0] alu_control;

    wire [31:0] result;

    alu dut (
        .a(a),
        .b(b),
        .alu_control(alu_control),
        .result(result)
    );

    initial begin

        $monitor("Time=%0t | A=%0d | B=%0d | Control=%b | Result=%0d",
                 $time, a, b, alu_control, result);

        // ADD
        a = 32'd10;
        b = 32'd20;
        alu_control = 4'b0000;
        #10;

        // SUB
        a = 32'd20;
        b = 32'd10;
        alu_control = 4'b0001;
        #10;

        // AND
        a = 32'h0F0F0F0F;
        b = 32'h00FF00FF;
        alu_control = 4'b0010;
        #10;

        // OR
        a = 32'h0F0F0F0F;
        b = 32'h00FF00FF;
        alu_control = 4'b0011;
        #10;

        // XOR
        a = 32'h0F0F0F0F;
        b = 32'h00FF00FF;
        alu_control = 4'b0100;
        #10;

        // SLT signed
        a = 32'd5;
        b = 32'd10;
        alu_control = 4'b0101;
        #10;

        // SLTU unsigned
        a = 32'd5;
        b = 32'd10;
        alu_control = 4'b1001;
        #10;

        // SLL
        a = 32'd5;
        b = 32'd1;
        alu_control = 4'b0110;
        #10;

        // SRL
        a = 32'd20;
        b = 32'd2;
        alu_control = 4'b0111;
        #10;

        // SRA positive number
        a = 32'd20;
        b = 32'd2;
        alu_control = 4'b1000;
        #10;

        // SRA negative number
        a = -32'sd20;
        b = 32'd2;
        alu_control = 4'b1000;
        #10;

        $finish;

    end

endmodule
```

---

# 31. Why Are the Testbench Inputs `reg`?

We are assigning values from the testbench:

```verilog
a = 32'd10;
b = 32'd20;
alu_control = 4'b0000;
```

Therefore these signals are declared as:

```verilog
reg
```

The ALU outputs:

```verilog
result
```

so the testbench declares it as:

```verilog
wire
```

because the ALU drives it.

This follows the same principle used in the Program Counter and Register File testbenches.

---

# 32. Why Does the ALU Testbench Have No Clock?

Because the ALU is combinational.

We do not need:

```verilog
reg clk;
```

and we do not need:

```verilog
always #5 clk = ~clk;
```

The testbench simply does:

```text
set inputs
wait
observe result
set next inputs
wait
observe result
```

The `#10` delays are only there to make the simulation changes easy to see.

---

# 33. Expected ADD Test

Inputs:

```text
A = 10
B = 20
Control = 0000
```

Operation:

```text
ADD
```

Expected:

```text
Result = 30
```

---

# 34. Expected SUB Test

Inputs:

```text
A = 20
B = 10
Control = 0001
```

Expected:

```text
Result = 10
```

---

# 35. Expected AND Test

Inputs:

```text
A = 0F0F0F0F
B = 00FF00FF
```

AND:

```text
0F0F0F0F
&
00FF00FF
=
000F000F
```

Expected:

```text
Result = 000F000F
```

---

# 36. Expected OR Test

```text
0F0F0F0F
|
00FF00FF
=
0FFF0FFF
```

Expected:

```text
Result = 0FFF0FFF
```

---

# 37. Expected XOR Test

```text
0F0F0F0F
^
00FF00FF
=
0FF00FF0
```

Expected:

```text
Result = 0FF00FF0
```

---

# 38. Expected SLT Test

```text
A = 5
B = 10
```

Since:

```text
5 < 10
```

expected:

```text
Result = 1
```

If:

```text
A = 10
B = 5
```

expected:

```text
Result = 0
```

---

# 39. Testing Signed SLT Properly

A very useful additional test is:

```text
A = -5
B = 3
```

Since:

```text
-5 < 3
```

signed SLT should return:

```text
1
```

You can add:

```verilog
a = -32'sd5;
b = 32'd3;
alu_control = 4'b0101;
#10;
```

This confirms that `$signed()` is doing its job.

---

# 40. Testing SLTU

SLTU treats both operands as unsigned.

For ordinary positive numbers:

```text
5 < 10
```

so:

```text
result = 1
```

The difference becomes obvious for bit patterns representing negative signed numbers.

For example:

```text
32'hFFFFFFFF
```

is:

```text
-1
```

when interpreted as signed, but:

```text
4294967295
```

when interpreted as unsigned.

Therefore signed and unsigned comparisons can produce different results.

---

# 41. Shift Tests

## SLL

```text
5 << 1 = 10
```

So:

```text
A = 5
B = 1
Control = 0110
```

Expected:

```text
Result = 10
```

## SRL

```text
20 >> 2 = 5
```

Expected:

```text
Result = 5
```

## SRA

For a positive number:

```text
20 >>> 2 = 5
```

For a negative number, SRA preserves the sign.

---

# 42. Compile the ALU

Assuming:

```text
RISCV/
├── rtl/
│   ├── program_counter.v
│   ├── instruction_memory.v
│   ├── register_file.v
│   └── alu.v
│
└── tb/
    ├── tb_program_counter.v
    ├── tb_instruction_memory.v
    ├── tb_register_file.v
    └── tb_alu.v
```

Run:

```powershell
iverilog -o alu_sim rtl/alu.v tb/tb_alu.v
```

Then:

```powershell
vvp alu_sim
```

---

# 43. Expected Terminal Behavior

You should see values similar to:

```text
Time=0     | A=10 | B=20 | Control=0000 | Result=30
Time=10000  | A=20 | B=10 | Control=0001 | Result=10
...
```

The exact formatting can vary depending on the testbench, but the mathematical results should match the operation.

---

# 44. Important: `$monitor` Shows Decimal by Default

We wrote:

```verilog
$monitor("... A=%0d ... Result=%0d ...");
```

`%0d` displays decimal.

For bit patterns, hexadecimal is often more useful.

For example:

```verilog
$monitor("Time=%0t | A=%h | B=%h | Control=%b | Result=%h",
         $time, a, b, alu_control, result);
```

Here:

```text
%0t -> time
%h  -> hexadecimal
%b  -> binary
```

For ALU debugging, hexadecimal output is often easier for 32-bit values.

---

# 45. Why Do We Need Both Decimal and Hexadecimal?

For arithmetic:

```text
10 + 20 = 30
```

decimal is easy to understand.

For bitwise operations:

```text
0F0F0F0F
&
00FF00FF
```

hexadecimal is much easier.

For control signals:

```text
0000
0001
0010
```

binary is useful.

So during testing, choose the format based on what you are checking.

---

# 46. One Important Improvement: ALU Zero Signal

Later, when we build branches such as:

```text
BEQ
```

the processor needs to know whether two values are equal.

A common ALU design therefore provides:

```text
zero
```

signal.

The idea is:

```text
if ALU result == 0:
    zero = 1
else:
    zero = 0
```

For example:

```text
A = 10
B = 10

A - B = 0

zero = 1
```

This is useful for:

```text
BEQ
```

because a branch can check whether the operands are equal.

---

# 47. Should We Add `zero` Now?

Yes, it is useful to include it in the ALU interface because the final single-cycle CPU will need branch comparison.

A slightly expanded ALU interface becomes:

```verilog
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero
);
```

Then:

```verilog
assign zero = (result == 32'd0);
```

This means:

```text
result = 0 -> zero = 1
result != 0 -> zero = 0
```

The zero signal is combinational because the ALU result is combinational.

---

# 48. Recommended Final ALU Module

For the complete CPU project, use:

```verilog
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero
);

    always @(*) begin

        case (alu_control)

            4'b0000: begin
                result = a + b;
            end

            4'b0001: begin
                result = a - b;
            end

            4'b0010: begin
                result = a & b;
            end

            4'b0011: begin
                result = a | b;
            end

            4'b0100: begin
                result = a ^ b;
            end

            4'b0101: begin
                result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            end

            4'b0110: begin
                result = a << b[4:0];
            end

            4'b0111: begin
                result = a >> b[4:0];
            end

            4'b1000: begin
                result = $signed(a) >>> b[4:0];
            end

            4'b1001: begin
                result = (a < b) ? 32'd1 : 32'd0;
            end

            default: begin
                result = 32'd0;
            end

        endcase
    end

    assign zero = (result == 32'd0);

endmodule
```

---

# 49. Updated ALU Testbench With Zero

If using the recommended module, the testbench should have:

```verilog
wire zero;
```

and connect:

```verilog
.zero(zero)
```

Example:

```verilog
`timescale 1ns/1ps

module tb_alu;

    reg [31:0] a;
    reg [31:0] b;
    reg [3:0] alu_control;

    wire [31:0] result;
    wire zero;

    alu dut (
        .a(a),
        .b(b),
        .alu_control(alu_control),
        .result(result),
        .zero(zero)
    );

    initial begin

        $monitor("Time=%0t | A=%0d | B=%0d | Control=%b | Result=%0d | Zero=%b",
                 $time, a, b, alu_control, result, zero);

        // ADD
        a = 32'd10;
        b = 32'd20;
        alu_control = 4'b0000;
        #10;

        // SUB
        a = 32'd20;
        b = 32'd10;
        alu_control = 4'b0001;
        #10;

        // SUB resulting in zero
        a = 32'd10;
        b = 32'd10;
        alu_control = 4'b0001;
        #10;

        // AND
        a = 32'h0F0F0F0F;
        b = 32'h00FF00FF;
        alu_control = 4'b0010;
        #10;

        // OR
        a = 32'h0F0F0F0F;
        b = 32'h00FF00FF;
        alu_control = 4'b0011;
        #10;

        // XOR
        a = 32'h0F0F0F0F;
        b = 32'h00FF00FF;
        alu_control = 4'b0100;
        #10;

        // SLT
        a = 32'd5;
        b = 32'd10;
        alu_control = 4'b0101;
        #10;

        // SLTU
        a = 32'd5;
        b = 32'd10;
        alu_control = 4'b1001;
        #10;

        // SLL
        a = 32'd5;
        b = 32'd1;
        alu_control = 4'b0110;
        #10;

        // SRL
        a = 32'd20;
        b = 32'd2;
        alu_control = 4'b0111;
        #10;

        // SRA positive
        a = 32'd20;
        b = 32'd2;
        alu_control = 4'b1000;
        #10;

        // SRA negative
        a = -32'sd20;
        b = 32'd2;
        alu_control = 4'b1000;
        #10;

        $finish;

    end

endmodule
```

---

# 50. Understanding the Zero Test

This test is:

```verilog
a = 32'd10;
b = 32'd10;
alu_control = 4'b0001;
```

Control:

```text
0001 = SUB
```

Therefore:

```text
10 - 10 = 0
```

Then:

```verilog
assign zero = (result == 32'd0);
```

becomes:

```text
zero = 1
```

This will later be used by branch logic.

---

# 51. ALU and RISC-V Instruction Examples

## ADD

```text
ADD x3, x1, x2
```

```text
A = x1
B = x2
control = ADD
result = x1 + x2
```

## SUB

```text
SUB x3, x1, x2
```

```text
A = x1
B = x2
control = SUB
result = x1 - x2
```

## AND

```text
AND x3, x1, x2
```

```text
result = x1 & x2
```

## OR

```text
OR x3, x1, x2
```

```text
result = x1 | x2
```

## XOR

```text
XOR x3, x1, x2
```

```text
result = x1 ^ x2
```

## SLT

```text
SLT x3, x1, x2
```

```text
result = 1 if x1 < x2
result = 0 otherwise
```

## SLL

```text
SLL x3, x1, x2
```

```text
result = x1 << x2[4:0]
```

## SRL

```text
SRL x3, x1, x2
```

```text
result = x1 >> x2[4:0]
```

## SRA

```text
SRA x3, x1, x2
```

```text
result = signed(x1) >>> x2[4:0]
```

---

# 52. Important Distinction: ALU vs ALU Control Unit

Do not confuse these two.

## ALU

Actually performs:

```text
ADD
SUB
AND
OR
XOR
SLT
...
```

## ALU Control Unit

Decides which ALU operation is required based on instruction fields and higher-level control signals.

Eventually:

```text
Instruction
     |
     v
Main Control
     |
     +------+
            |
            v
     ALU Control
            |
            v
      ALU Control Code
            |
            v
           ALU
```

For example, for:

```text
ADD
```

the ALU Control Unit might output:

```text
0000
```

For:

```text
SUB
```

it might output:

```text
0001
```

The ALU itself does not need to understand RISC-V opcodes.

It only needs to understand its internal control codes.

---

# 53. Why This Separation Is Useful

Suppose the instruction is:

```text
ADD x3, x1, x2
```

The ALU does not need to know:

```text
opcode = 0110011
funct3 = 000
funct7 = 0000000
```

The ALU Control Unit translates those instruction fields into:

```text
ALU control = 0000
```

Then the ALU simply performs:

```text
A + B
```

This makes the design modular.

---

# 54. ALU Data Flow in the Final CPU

For an R-type instruction:

```text
Instruction
     |
     +--------------------+
     |                    |
    rs1                  rs2
     |                    |
     v                    v
       Register File
        |         |
        |         |
        v         v
       A         B
        \         /
         \       /
          v     v
          +-----+
          | ALU |
          +--+--+
             |
             v
           Result
```

The ALU Control Unit separately provides:

```text
ALU Control
```

---

# 55. Immediate Instructions

For an instruction such as:

```text
ADDI x1, x2, 5
```

the second ALU operand is NOT another register.

Instead:

```text
A = x2
B = immediate 5
```

Therefore the final CPU will need a multiplexer before the ALU:

```text
                   Register Data
                        |
                        |
                        v
                       MUX ----> ALU B
                        ^
                        |
                   Immediate
```

A control signal will choose:

```text
register value
```

or:

```text
immediate value
```

The ALU itself remains unchanged.

---

# 56. Branch Instructions

For:

```text
BEQ x1, x2, label
```

the CPU needs to determine:

```text
x1 == x2?
```

A common way is:

```text
x1 - x2
```

If the result is zero:

```text
x1 == x2
```

Therefore:

```text
ALU:
    A = x1
    B = x2
    operation = SUB
```

If:

```text
zero = 1
```

then the operands were equal.

This is why the ALU's zero output is useful.

---

# 57. Verilog Concepts Learned in the ALU

After completing this component, you should understand:

```text
always @(*)
```

for combinational logic.

```text
case
```

for selecting operations.

```text
?
:
```

conditional operator.

```text
$signed()
```

for signed interpretation.

```text
<<
```

left shift.

```text
>>
```

logical right shift.

```text
>>>
```

arithmetic right shift.

```text
&
```

bitwise AND.

```text
|
```

bitwise OR.

```text
^
```

bitwise XOR.

---

# 58. Common Mistakes

## Mistake 1 — Adding a clock to the ALU

Do not add:

```verilog
input clk;
```

for this basic combinational ALU.

The ALU does not store its result.

---

## Mistake 2 — Using `always @(posedge clk)`

That would make the ALU behave like sequential storage.

Use:

```verilog
always @(*)
```

instead.

---

## Mistake 3 — Forgetting `default`

Always provide a safe default result.

---

## Mistake 4 — Forgetting signed comparison

For:

```text
SLT
```

use signed comparison:

```verilog
$signed(a) < $signed(b)
```

For:

```text
SLTU
```

use unsigned comparison:

```verilog
a < b
```

---

## Mistake 5 — Using `>>` for SRA without considering signedness

For arithmetic right shift:

```verilog
$signed(a) >>> b[4:0]
```

is the appropriate form.

---

## Mistake 6 — Using the entire B operand as shift amount

Use:

```verilog
b[4:0]
```

for RV32 register-register shifts.

---

## Mistake 7 — Confusing ALU control with opcode

For example:

```text
opcode = 0110011
```

is an instruction encoding field.

Our:

```text
alu_control = 0000
```

is an internal ALU control code.

They are different things.

---

# 59. Final ALU Checklist

Before moving to the next hardware component, verify:

- [ ] ALU has two 32-bit inputs.
- [ ] ALU has a 4-bit internal control signal.
- [ ] ALU has a 32-bit result.
- [ ] ALU is combinational.
- [ ] ADD works.
- [ ] SUB works.
- [ ] AND works.
- [ ] OR works.
- [ ] XOR works.
- [ ] SLT works as signed comparison.
- [ ] SLTU works as unsigned comparison.
- [ ] SLL works.
- [ ] SRL works.
- [ ] SRA works.
- [ ] Shift amount uses `b[4:0]`.
- [ ] Zero output works.
- [ ] Testbench has no unnecessary clock.
- [ ] Testbench verifies multiple operations.
- [ ] Testbench verifies a zero-result case.
- [ ] Compilation succeeds.
- [ ] Terminal output matches expected results.

---

# 60. Current Processor Progress

After completing the ALU:

```text
[✓] Program Counter
[✓] Instruction Memory
[✓] Register File
[✓] ALU
[ ] Immediate Generator
[ ] Main Control Unit
[ ] ALU Control Unit
[ ] Data Memory
[ ] MUXes + Branch/Jump Logic
[ ] Top-Level CPU
```

The next component is the:

```text
Immediate Generator
```

It will extract and sign-extend immediate values from different RISC-V instruction formats:

```text
I-type
S-type
SB-type
U-type
UJ-type
```

The Immediate Generator is important because instructions such as:

```text
ADDI
LW
SW
BEQ
JAL
```

do not all store their immediate values in the same bit positions.
