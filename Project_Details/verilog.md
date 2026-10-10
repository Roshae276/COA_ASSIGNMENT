# Module
- module is basically a hardware block
- socho jaise ki physical IC / Hardware component hai
- isme input pins aur output pins hai
```
             Program Counter
          ┌──────────────────┐
clk ─────►│                  │
reset ──► │                  │────► pc
pc_next ─►│                  │
          └──────────────────┘
```

# Input
- input ek signal hai jo ki hamari module/block ke andar aata hai

```verilog
input wire clk;

matlab ki hamara program counter recievs a clock signal
```

# Output
- output ek aisa signal hai jo ki hamari module se baahr aata hai

```verilog
output reg [31:0] pc;
```

matlab ki hamara output jo hai vo 32 bit ka hai yaani ki pc 32 bit ka output generate krta hai


# Wire
- wire matlab ek electrical connection
  ```verilog
  input wire clk;
  ```
- yaani ki clock ek signal hai jo ki ek connection ke through hamare pass aarahi hai

```verilog
input wire [31:0] pc_next
```
- yaani ki pc_next 32-bit ka input connection hai
- ham wire ka bohot use karenge kyuki hamare signals hai vo generate hote hai combinational hardware se.

# reg
- reg ka matlab physical register nahi samajna hai
- ye ek data type hai
- hamara pc ek value store karta hai right?
- aur program counter ek register hota hai hardware me
- isko purana pc ki value bhi yaad rkhni pdti hai
- aur kab tak yaad rakhni pdti hai jab tak ki next rising clock edge na aajaye
- reg is basically verilog data type for signals assigned procedurally
- is case mai ham clock storage describe kar rahe hai isliye it synthesizes to actual flip flop/register hardware.

# always
```verilog
always @(posedge clk)
```
- iska matlab hai ki ye hardware execute hoga jab clock ka positive/rising edge aayega
- posedge means 0->1
- to hamara PC tabhi update hoga jab rising edge aayega
  
# Why do we use clock?
- dekh hota ye hai ki hamara processor synchronously kaam karta hai
- synchronously matlab single clock sab ke liye 


# If
```verilog
if(reset)
    pc <= 32'b0

else
    pc<=pc_next
```
- yaani ki 
  
```
IF reset is active
       ↓
    PC = 0

ELSE
       ↓
    PC = pc_next
 ```

- hardware-wise multiplexer ki tarah sonch sakte ho isko
- jaha par hamari reset select line hai jiske base par yaa to pc me 0 jayega ya fir pc_next ki value jayegi
  
# 32b'0
- iska matlab hai 32 bit binary value containing zero

# 32d'0
- iska matlab hai ki 32 bit decimal value containing zero
- similary 32 h'0 for hexadecimal

# <= operator
- iska matlab normal value assign karna nahi hota hai iska use ham clock/sequencial logic ke liye krte hai
- iska matlab hota hai non blocking assignment
- The idea is 
  ```
  At clock edge:
    capture pc_next
    update PC
  ```

# end
- beign and end multiple statements ko combine karte hai

# endmodule
- endmodule ka matlab hai hardware module is finished
  

# what is testbench?
- ek hoti hai main hardware module jo ki hamne program counter ke liye banayi 
- testbench hamare processor ka part nahi hoti
- ye ek simulation environment hai
- jo ki test karta hai ki hardware kya output produce krega
```
                 TESTBENCH
             ┌───────────────┐
             │               │
             │ clk           │
             │ reset         │
             │ pc_next       │
             │               │
             └───────┬───────┘
                     │
                     ▼
             ┌───────────────┐
             │ PROGRAM       │
             │ COUNTER       │
             └───────┬───────┘
                     │
                     ▼
                     PC
```

# `timescale 1ns/1ps
- first of all lets understand what is simulation environment
- dekh simulation environment hota hai ek artificial computer generated setting jo ki real world conditions, systems,processes ko mimic krta hai.
- ab timescake 1ns/1ps simulator ko batata hai ki simulation time ko kaise interpret karna hai
- yaha 1ns = time unit
- 1ps = precision
- #5 matlab 5 ns
  
# why clk , reset, pc_next are reg?
- ye reg hai kyuki hamara testbench inko value de raha hai fir change bhi kr rha hai
  
# pc reg kyu nahi hai testbench me?
- kyuki usko testbench value nahi de rha hai

# DUT ?
- iska matlab hai device under test
- dut creates an instance of our hardware
- us hardware ke instance ko ham apne testbench me test kr sakte hai
  
# Ab testbench ke harware instance ko original hardware se kaise connect krenge?
```
Testbench                 PC

clk       ───────────────► clk

reset     ───────────────► reset

pc_next   ───────────────► pc_next

pc        ◄─────────────── pc
```

```verilog
.port_name(signal_name)

example:
.clk(clk)
means Connect this module port to this signal.
PC's clk port ← testbench's clk signal
```

# Generating the clock
- always #5 clk = ~clk
- yaani ki har 5ns ki clock par hame bitwise not krna hai
- 0->1
- 1->0

# initial
- iska matlab hai simulation setup ko ek baar execute karo at time 0
- ham iska use isliye karte hai kyuki hame time 0 par initially clk ,reset , pc_next ka input dena hai

# 12
- is 12ns ka matlab hai ki wait karo 12ns in simulation
- is time pr clock chlti rehti hai
- dekho 5 ns tak ek rising edge aaya 
- 10ns ek falling edge hai
- to hamara reset 0 hota hai 11ns , 12ns , 13ns kisi bhi time par
- Clock edge ke baad PC change hota hai, aur uske baad baaki logic ko settle hone ka time chahiye.
- isliye hamne 10ns ke baad wali value li vrna 10ns bhi le skate hai

# $finish
- matlab stop the simulation
  

# How to compile ?
```
iverilog -o pc_sim rtl/program_counter.v tb/tb_program_counter.v

vvp pc_sim
```

- iverilog is icarus verilog compiler
- -o pc_sim matlab ki output file ka name kya rkhna hai
- rtl folder ke andar jaao aur waha program_counter.v file hai usko compile kro
- tb folder ke andar jaao waha bhi ek file hai usko compile kro
- vvp pc_sim matlab simulation ko run kro

  

