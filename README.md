## ASSIGNMENT ##

## Overview

This project implements a **parameterized Arithmetic Logic Unit (ALU)** in Verilog using **dataflow modeling**. The ALU supports a variety of arithmetic, logical, shift, rotate, and comparison operations selected through a 4-bit control signal.

The design is parameterized by the data width (`N`), making it scalable for different operand sizes. By default, the ALU operates on **8-bit** inputs.

---

## Features

* Parameterized operand width (`N = 8` by default)
* Pure dataflow implementation using continuous assignments
* Supports 16 ALU operations
* Overflow flag generation for addition
* Division-by-zero protection
* Logical shift and rotate operations
* Comparison operations

---

## Module Interface

```verilog
module alu (
    input  [N-1:0] val1,
    input  [N-1:0] val2,
    input  [3:0]   select,
    output [N-1:0] result,
    output         flag
);
```

### Inputs

| Signal   | Width | Description           |
| -------- | ----: | --------------------- |
| `val1`   |     N | First operand         |
| `val2`   |     N | Second operand        |
| `select` |     4 | Operation select code |

### Outputs

| Signal   | Width | Description                  |
| -------- | ----: | ---------------------------- |
| `result` |     N | Result of selected operation |
| `flag`   |     1 | Overflow flag for addition   |

---

## Supported Operations

| Select Code | Operation               |
| ----------- | ----------------------- |
| `0000`      | Addition                |
| `0001`      | Subtraction             |
| `0010`      | Multiplication          |
| `0011`      | Division                |
| `0100`      | Logical Left Shift      |
| `0101`      | Logical Right Shift     |
| `0110`      | Rotate Left             |
| `0111`      | Rotate Right            |
| `1000`      | Logical AND             |
| `1001`      | Logical OR              |
| `1010`      | Logical XOR             |
| `1011`      | Logical NOR             |
| `1100`      | Logical NAND            |
| `1101`      | Logical XNOR            |
| `1110`      | Greater-than Comparison |
| `1111`      | Equality Comparison     |

---

## Design Details

### Arithmetic Operations

* Addition
* Subtraction
* Multiplication
* Division

For division, if `val2` is zero, the ALU returns **0** to avoid undefined behavior.

### Shift Operations

* Logical left shift by one bit
* Logical right shift by one bit

### Rotate Operations

* Rotate left by one bit
* Rotate right by one bit

### Logical Operations

* AND
* OR
* XOR
* NOR
* NAND
* XNOR

### Comparison Operations

* Greater-than comparison
* Equality comparison

Both comparison operations return:

* `8'd1` if the condition is true
* `8'd0` otherwise

---

## Overflow Detection

Overflow detection is implemented using an intermediate wire one bit wider than the operands.

```verilog
wire [N:0] tmp;

assign tmp = {1'b0, val1} + {1'b0, val2};
assign flag = tmp[N];
```

The overflow flag is valid for the addition operation.

---

## Simulation

Compile the design and testbench using your preferred Verilog simulator.

Example using Icarus Verilog:

```bash
iverilog -o alu_tb alu.v alu_tb.v
vvp alu_tb
```

To view the waveform:

```bash
gtkwave alu.vcd
```

---

## GTKWave Output

The following waveform shows the ALU simulation results.

![GTKWave Simulation](Pasted\ image.png)

---

## Project Structure

```text
.
├── alu.v
├── alu_tb.v
├── alu.vcd
├── gtkwave.png
└── README.md
```

---

## Notes

* The ALU is implemented entirely using **dataflow modeling**.
* Operand width can be changed by modifying the parameter `N`.
* Comparison outputs are represented as `1` or `0`.
* Division by zero safely returns zero.
* Overflow detection is provided for addition using an extra carry bit.

---

## Author

Parameterized ALU implemented in Verilog HDL for digital logic and computer architecture laboratory experiments.
