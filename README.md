# MIPS-Inspired Pipelined Processor in Verilog

A 5-stage pipelined processor implemented in Verilog HDL, modelled on the MIPS/RISC-V ISA. Computes the integer square root of a given input using an iterative multiplication algorithm running entirely on the pipeline.

---
### Pipeline Stages

| Stage | Clock | Function |
|-------|-------|----------|
| IF — Instruction Fetch | clk1 | Reads instruction from memory using program counter |
| ID — Instruction Decode | clk2 | Decodes opcode, reads register file, generates immediate |
| EX — Execute | clk2 (combinational) | ALU operation, branch condition evaluation |
| MEM — Memory Access | clk1 | Passes result to WB stage |
| WB — Write Back | clk2 | Writes result back to destination register |

### Dual Clock Design

Two phase-shifted clocks are used to avoid structural hazards between adjacent stages:

- `clk1` — drives IF and MEM stages
- `clk2` — drives ID, EX, and WB stages (phase shifted by half a period)

This eliminates the need for stall logic between most stage pairs.

---

## Supported Instructions

| Instruction | Type | Operation |
|-------------|------|-----------|
| `ADDI rd, rs, imm` | I-type | `rd = rs + imm` |
| `ADD rd, rs, rt` | R-type | `rd = rs + rt` |
| `MUL rd, rs, rt` | R-type | `rd = rs * rt` |
| `BEQ rs, rt, offset` | I-type | `if rs == rt: PC = PC + 1 + offset` |
| `SW rt, offset(rs)` | I-type | `mem[rs + offset] = rt` |

---

## Square Root Algorithm

The processor computes integer square root using iterative trial multiplication:

```
guess = 1
loop:
    R3 = guess * guess        (MUL)
    NOP                       (pipeline delay slot)
    NOP                       (pipeline delay slot)
    if R3 == num: exit        (BEQ)
    guess = guess + 1         (ADDI)
    jump back to loop         (BEQ R0, R0, offset)
result = guess
```

### Register Usage

| Register | Role |
|----------|------|
| R0 | Hardwired zero |
| R1 | Input number (loaded from port `num`) |
| R2 | Current guess (output — square root result) |
| R3 | `guess * guess` (intermediate) |

---

## Hazard Handling

### Data Hazards — Forwarding Unit

The ID stage implements forwarding to resolve RAW (Read After Write) hazards:

```
Priority 1: Forward from EX/MEM pipeline register
Priority 2: Forward from MEM/WB pipeline register
Priority 3: Read from register file
```

### Control Hazards — Branch Flushing

When a BEQ branch is taken, the IF stage detects `EXMEM_branch_taken` on the next `clk1` edge and redirects the program counter to the branch target, flushing the incorrectly fetched instruction.

### Structural Hazards — Dual Clock

The dual-clock design ensures IF and ID never conflict on the register file, and EX and WB never conflict on pipeline registers.

---

## How to Simulate

### Requirements

- [Icarus Verilog](http://iverilog.icarus.com/) — `iverilog`, `vvp`
- [GTKWave](http://gtkwave.sourceforge.net/) — for waveform viewing (optional)

### Steps

```bash
# Compile
iverilog -o output risc.v mips_tb.sv

# Run simulation
vvp output

# View waveform
gtkwave processor.vcd
```

### Expected Output

```
sqrt(16) = 4  (expected 4) PASS
sqrt(9)  = 3  (expected 3) PASS
sqrt(4)  = 2  (expected 2) PASS
sqrt(1)  = 1  (expected 1) PASS
```

---

## Testbench

The testbench drives four test cases sequentially, waiting enough clock cycles between each for the pipeline to fully drain:

```systemverilog
run_test(16, 4);   // 4² = 16
run_test(9,  3);   // 3² = 9
run_test(4,  2);   // 2² = 4
run_test(1,  1);   // 1² = 1
```

Each test resets all registers and reloads `num` into `R1` before restarting the pipeline.

---

## Instruction Encoding

Instructions follow standard MIPS 32-bit encoding:

```
R-type:  | opcode[31:26] | rs[25:21] | rt[20:16] | rd[15:11] | shamt[10:6] | funct[5:0] |
I-type:  | opcode[31:26] | rs[25:21] | rt[20:16] | immediate[15:0]                       |
```

---

## Limitations

- Integer perfect squares only (e.g. 1, 4, 9, 16, 25) — non-perfect squares loop indefinitely
- Program counter is 3 bits — supports up to 8 instructions
- No exception or interrupt handling
- No byte or halfword memory access (word-addressed only)
- Subset ISA — not a complete RISC-V or MIPS implementation

---

## What This Demonstrates

- 5-stage pipeline modelling in Verilog
- Dual-clock hazard avoidance
- Data forwarding (RAW hazard resolution)
- Branch detection and PC redirection
- Instruction encoding and decoding
- Register file read/write with priority forwarding
- Iterative algorithm execution on custom hardware

---

## Author

Aditya — B.Tech ECE / VLSI  
Built as a first pipelined processor implementation using Verilog HDL.
