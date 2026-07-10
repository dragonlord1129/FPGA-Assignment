// ============================================================
// memory8.v -- 256 x 8-bit unified program/data memory
//   - Combinational read (address -> data, same cycle)
//   - Synchronous write on rising clk edge when we=1
//   - Preloaded from a hex file via $readmemh (for simulation /
//     FPGA block-RAM initial-value inference)
// ============================================================
`timescale 1ns/1ps

module memory8 #(
    parameter MEM_INIT_FILE = ""
) (
    input  wire       clk,
    input  wire [7:0] addr,
    input  wire [7:0] wdata,
    input  wire       we,
    output wire [7:0] rdata
);

    reg [7:0] mem [0:255];

    // Runtime program selection: `vvp sim.out +HEXFILE=sw/other.hex`
    // overrides the MEM_INIT_FILE parameter without recompiling, so
    // one compiled simulation + one testbench can run any program.
    integer i;
    string  hexfile_plusarg;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 8'h00;
        if ($value$plusargs("HEXFILE=%s", hexfile_plusarg))
            $readmemh(hexfile_plusarg, mem);
        else if (MEM_INIT_FILE != "")
            $readmemh(MEM_INIT_FILE, mem);
    end

    assign rdata = mem[addr];

    always @(posedge clk) begin
        if (we)
            mem[addr] <= wdata;
    end

endmodule
