`timescale 1ns/1ps

`define addition 4'b0000
`define subtraction 4'b0001
`define multiplication 4'b0010
`define division 4'b0011
`define logicalleft 4'b0100
`define logicalright 4'b0101
`define rotateleft 4'b0110
`define rotateright 4'b0111
`define logicaland 4'b1000
`define logicalor 4'b1001
`define logicalxor 4'b1010
`define logicalnor 4'b1011
`define logicalnand 4'b1100
`define logicalxnor 4'b1101
`define greatercomparison 4'b1110
`define equalcomparison 4'b1111

module alu (
  input [N-1:0] val1, val2,
  input [3:0] select,
  output [N-1:0] result,
  output flag
);
  parameter N = 8;
  wire [N:0] tmp;  // Used for overflow detection in arithmetic operations

  // Dataflow: overflow detection
  assign tmp = {1'b0, val1} + {1'b0, val2};
  assign flag = tmp[N];

  // Dataflow: result computed using nested ternary operators
  assign result =
    (select == `addition)          ? (val1 + val2) :
    (select == `subtraction)       ? (val1 - val2) :
    (select == `multiplication)    ? (val1 * val2) :
    (select == `division)          ? ((val2 != 0) ? (val1 / val2) : {N{1'b0}}) :
    (select == `logicalleft)       ? (val1 << 1) :
    (select == `logicalright)      ? (val1 >> 1) :
    (select == `rotateleft)        ? {val1[N-2:0], val1[N-1]} :
    (select == `rotateright)       ? {val1[0], val1[N-1:1]} :
    (select == `logicaland)        ? (val1 & val2) :
    (select == `logicalor)         ? (val1 | val2) :
    (select == `logicalxor)        ? (val1 ^ val2) :
    (select == `logicalnor)        ? ~(val1 | val2) :
    (select == `logicalnand)       ? ~(val1 & val2) :
    (select == `logicalxnor)       ? ~(val1 ^ val2) :
    (select == `greatercomparison) ? ((val1 > val2) ? 8'd1 : 8'd0) :
    (select == `equalcomparison)   ? ((val1 == val2) ? 8'd1 : 8'd0) :
    {N{1'b0}};  // Default value set to 0, N bits wide

endmodule
