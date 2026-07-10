# 8-bit Single-Core CPU (Verilog)

A complete, simulation-verified 8-bit accumulator-based CPU written in
synthesizable Verilog, split into a classic **Control Unit + Datapath**
structure.

## Files

```
alu8.v          - Combinational 8-bit ALU (add/sub/and/or/xor/not/shift/inc/dec)
memory8.v       - 256 x 8-bit unified program+data memory (comb. read, sync write)
control_unit.v  - Control Unit: FSM state register + all control-signal generation
cpu8.v          - Datapath: registers, muxes, ALU/memory instantiation, top level
tb_cpu8.v        - ONE testbench, reused for every program (see "Running" below)
program.hex      - Demo machine code (loop + arithmetic, sums 1..5 -> 15)
program2.hex     - Demo machine code (subroutine call + stack, -> 20)
run_tests.sh        - Compiles once, runs the same testbench against both programs
```

## Architecture

- **Data width:** 8 bits. **Address width:** 8 bits (256-byte unified memory,
  von Neumann style — code and data share the same space).
- **Registers:** `A` (accumulator), `B` (general purpose), `PC` (program
  counter), `SP` (stack pointer, grows downward from 0xFF), `IR`
  (instruction register), `OPR` (operand register), flags `Z` (zero) and
  `C` (carry/borrow).
- **Instruction encoding:** 1-byte opcode, optionally followed by 1 operand
  byte (an 8-bit immediate or an 8-bit memory address). Every instruction is
  therefore 1 or 2 bytes.
- **Execution model:** classic multi-cycle fetch/decode/execute FSM (not
  pipelined) — simple to understand, verify, and extend. A single
  instruction takes 2–5 clock cycles depending on its class.

## Control Unit + Datapath split

The design is now separated the way a textbook CPU block diagram usually
draws it:

- **`control_unit.v`** owns the FSM state register and *only* sequencing
  logic. Every cycle it looks at the current state, the opcode sitting in
  `IR`, and the `Z`/`C` flags, and outputs a bundle of control signals: mux
  selects (`mem_addr_sel`, `alu_a_sel`, `alu_b_sel`, `a_sel`,
  `pc_load_sel`), load enables (`ir_ld`, `opr_ld`, `a_ld`, `b_ld`, `out_ld`,
  `flag_z_we`, `flag_c_we`), counters (`pc_inc`, `sp_inc`, `sp_dec`), the
  ALU opcode (`alu_op`), and `mem_we`/`mem_wdata_sel`. It holds no data
  registers of its own.
- **`cpu8.v`** is the datapath: it holds `PC/SP/A/B/IR/OPR`/flags, the
  muxes those control signals steer, and instantiates the ALU and memory.
  Every register update in its single sequential `always @(posedge clk)`
  block is gated purely by a control-unit signal — the datapath makes no
  sequencing decisions itself.

This mirrors the classic two-block CPU diagram (control unit sends control
signals down to the datapath; the datapath sends status — opcode and
condition flags — back up to the control unit) and makes it straightforward
to, e.g., swap in a microcoded control unit later without touching the
datapath at all.

## Instruction Set

| Opcode | Mnemonic  | Bytes | Operation                              |
|--------|-----------|-------|-----------------------------------------|
| 0x00   | NOP       | 1     | no operation                            |
| 0x01   | LDA addr  | 2     | A ← MEM[addr]                           |
| 0x02   | STA addr  | 2     | MEM[addr] ← A                           |
| 0x03   | LDI imm   | 2     | A ← imm                                 |
| 0x04   | ADD addr  | 2     | A ← A + MEM[addr]  (Z, C)               |
| 0x05   | ADI imm   | 2     | A ← A + imm        (Z, C)               |
| 0x06   | SUB addr  | 2     | A ← A − MEM[addr]  (Z, C=borrow)        |
| 0x07   | SBI imm   | 2     | A ← A − imm        (Z, C=borrow)        |
| 0x08   | ANDA addr | 2     | A ← A & MEM[addr]  (Z)                  |
| 0x09   | ORA addr  | 2     | A ← A \| MEM[addr] (Z)                  |
| 0x0A   | XORA addr | 2     | A ← A ^ MEM[addr]  (Z)                  |
| 0x0B   | JMP addr  | 2     | PC ← addr                               |
| 0x0C   | JZ addr   | 2     | if (Z) PC ← addr                        |
| 0x0D   | JNZ addr  | 2     | if (!Z) PC ← addr                       |
| 0x0E   | JC addr   | 2     | if (C) PC ← addr                        |
| 0x0F   | CALL addr | 2     | MEM[SP] ← PC; SP--; PC ← addr           |
| 0x10   | RET       | 1     | SP++; PC ← MEM[SP]                      |
| 0x11   | OUT       | 1     | OUT_PORT ← A                            |
| 0x12   | IN        | 1     | A ← IN_PORT                             |
| 0x13   | MOVAB     | 1     | B ← A                                   |
| 0x14   | MOVBA     | 1     | A ← B                                   |
| 0x15   | INC       | 1     | A ← A + 1          (Z, C)               |
| 0x16   | DEC       | 1     | A ← A − 1          (Z, C)               |
| 0x17   | CMA       | 1     | A ← ~A                                  |
| 0x18   | SHL       | 1     | A ← A << 1  (C ← old bit 7)             |
| 0x19   | SHR       | 1     | A ← A >> 1  (C ← old bit 0)             |
| 0x1A   | PUSH      | 1     | MEM[SP] ← A; SP--                       |
| 0x1B   | POP       | 1     | SP++; A ← MEM[SP]                       |
| 0xFF   | HLT       | 1     | stop fetching (CPU freezes)             |

## FSM overview

```
S_FETCH   -> S_DECODE                         (fetch opcode byte, PC++)
S_DECODE  -> S_OPERAND / S_EXEC1 / S_PUSHWR /
             S_STACKRD / S_HALT               (route by opcode class)
S_OPERAND -> S_MEMOP / S_MEMWR / S_PUSHWR /
             S_EXEC1                          (fetch operand byte, PC++)
S_MEMOP   -> S_FETCH   (ALU op using MEM[OPR], e.g. LDA/ADD/SUB/AND/OR/XOR)
S_MEMWR   -> S_FETCH   (STA: write A to MEM[OPR])
S_PUSHWR  -> S_FETCH / S_CALLJUMP  (PUSH, or first half of CALL)
S_CALLJUMP-> S_FETCH   (second half of CALL: PC <- OPR)
S_STACKRD -> S_FETCH   (POP or RET: read MEM[SP+1])
S_EXEC1   -> S_FETCH   (single-cycle ops: immediates, jumps, ALU/reg ops)
S_HALT    -> S_HALT    (terminal)
```

## Running the simulation (Icarus Verilog)

The testbench (`tb/tb_cpu8.v`) is **the same file for every program** — it
takes the hex file to load and the expected result as *runtime* plusargs,
not compile-time parameters, so you compile once and re-run as many times
as you like:

Running sw/program.hex  (loop sum 1..5, expect out_port=15)
CPU halted after 209 clock cycles
OUT_PORT  = 15 (0x0f)
RESULT: PASS (sum_1_to_5) -- out_port == 15 as expected

Running sw/program2.hex (CALL/RET/PUSH/POP/SHL, expect out_port=20)
CPU halted after 34 clock cycles
OUT_PORT  = 20 (0x14)
RESULT: PASS (call_ret_stack) -- out_port == 20 as expected
```

Plusargs supported by `tb_cpu8.v`:

| Plusarg      | Required | Meaning                                            |
|--------------|----------|-----------------------------------------------------|
| `+HEXFILE=`  | no (defaults to `sw/program.hex`) | machine code to load |
| `+EXPECTED=` | no       | expected final `out_port` value (decimal); enables PASS/FAIL |
| `+TESTNAME=` | no       | label used in the printed report                    |
| `+MAXCYCLES=`| no (default 2000) | safety timeout in clock cycles              |

A `cpu8_<testname>.vcd` waveform file is produced per run and can be opened
with GTKWave for cycle-by-cycle inspection (includes `dbg_state`, so you can
watch the control unit's FSM step through `S_FETCH -> S_DECODE -> ...`
alongside the datapath registers).

## Writing your own programs

`sw/program.hex` shows the format expected by `$readmemh`: `@00` sets the
starting address, followed by whitespace/newline-separated hex bytes (one
byte per opcode or operand). To assemble a new program, look up each
mnemonic in the ISA table above and lay out the bytes by hand (or write a
small script/assembler — the encoding is intentionally simple: opcode byte
+ optional operand byte).

## Extending the design

Some natural next steps if you want to grow this further:
- Pipe the design through Yosys (`read_verilog` + `synth`) to check gate
  counts and get a synthesized netlist for an FPGA target.
- Add more registers (C, D, ...) and register-to-register ALU ops.
- Add interrupt support (an `INT`/`IRET` pair and an interrupt-enable flag).
- Widen the address bus (e.g., 12/16-bit) if 256 bytes of memory is too
  small for your programs.
- Pipeline fetch/decode/execute for higher throughput (adds hazard logic).
