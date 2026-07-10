// ============================================================
// alu8.v -- 8-bit Arithmetic/Logic Unit (combinational)
// ============================================================
`timescale 1ns/1ps

module alu8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [3:0] op,
    output reg  [7:0] result,
    output wire       zero,      // result == 0
    output reg        carry      // carry-out / borrow / shift-out bit
);

    // ALU operation codes
    localparam ALU_ADD = 4'h0;
    localparam ALU_SUB = 4'h1;
    localparam ALU_AND = 4'h2;
    localparam ALU_OR  = 4'h3;
    localparam ALU_XOR = 4'h4;
    localparam ALU_NOT = 4'h5;  // result = ~a
    localparam ALU_SHL = 4'h6;  // result = a << 1
    localparam ALU_SHR = 4'h7;  // result = a >> 1
    localparam ALU_PASS_A = 4'h8; // result = a (used for LDA/LDI/IN/MOVBA)
    localparam ALU_INC = 4'h9;  // result = a + 1
    localparam ALU_DEC = 4'hA;  // result = a - 1

    reg [8:0] wide; // 9-bit for carry/borrow detection

    always @(*) begin
        wide   = 9'd0;
        carry  = 1'b0;
        result = 8'h00;
        case (op)
            ALU_ADD: begin
                wide   = {1'b0, a} + {1'b0, b};
                result = wide[7:0];
                carry  = wide[8];
            end
            ALU_SUB: begin
                wide   = {1'b0, a} - {1'b0, b};
                result = wide[7:0];
                carry  = wide[8]; // 1 = borrow occurred
            end
            ALU_AND: result = a & b;
            ALU_OR : result = a | b;
            ALU_XOR: result = a ^ b;
            ALU_NOT: result = ~a;
            ALU_SHL: begin
                result = {a[6:0], 1'b0};
                carry  = a[7];
            end
            ALU_SHR: begin
                result = {1'b0, a[7:1]};
                carry  = a[0];
            end
            ALU_PASS_A: result = a;
            ALU_INC: begin
                wide   = {1'b0, a} + 9'd1;
                result = wide[7:0];
                carry  = wide[8];
            end
            ALU_DEC: begin
                wide   = {1'b0, a} - 9'd1;
                result = wide[7:0];
                carry  = wide[8];
            end
            default: result = 8'h00;
        endcase
    end

    assign zero = (result == 8'h00);

endmodule
