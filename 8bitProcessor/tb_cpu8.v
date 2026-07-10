
module tb_cpu8;

    reg clk;
    reg reset;
    reg  [7:0] in_port;
    wire [7:0] out_port;
    wire       halted;
    wire [7:0] dbg_pc, dbg_a, dbg_b, dbg_sp, dbg_ir;
    wire [3:0] dbg_state;
    wire       dbg_zero, dbg_carry;


    cpu8 dut (
        .clk      (clk),
        .reset    (reset),
        .in_port  (in_port),
        .out_port (out_port),
        .halted   (halted),
        .dbg_pc   (dbg_pc),
        .dbg_a    (dbg_a),
        .dbg_b    (dbg_b),
        .dbg_sp   (dbg_sp),
        .dbg_ir   (dbg_ir),
        .dbg_state(dbg_state),
        .dbg_zero (dbg_zero),
        .dbg_carry(dbg_carry)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    string  hexfile;
    string  testname;
    integer expected;
    integer have_expected;
    integer max_cycles;
    integer cycle_count;

    initial begin
        if (!$value$plusargs("HEXFILE=%s", hexfile))
            hexfile = "sw/program.hex";
        if (!$value$plusargs("TESTNAME=%s", testname))
            testname = "unnamed_test";
        if (!$value$plusargs("MAXCYCLES=%d", max_cycles))
            max_cycles = 2000;
        have_expected = $value$plusargs("EXPECTED=%d", expected);

        $dumpfile({"cpu8_", testname, ".vcd"});
        $dumpvars(0, tb_cpu8);

        $display("====================================================");
        $display("TEST: %s", testname);
        $display("HEXFILE: %s", hexfile);
        $display("====================================================");

        reset       = 1;
        in_port     = 8'h00;
        cycle_count = 0;
        repeat (2) @(posedge clk);
        reset = 0;

        while (!halted && cycle_count < max_cycles) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        if (halted) begin
            $display("CPU halted after %0d clock cycles", cycle_count);
            $display("Final A   = %0d (0x%02h)", dbg_a, dbg_a);
            $display("Final B   = %0d (0x%02h)", dbg_b, dbg_b);
            $display("Final PC  = 0x%02h", dbg_pc);
            $display("Final SP  = 0x%02h", dbg_sp);
            $display("OUT_PORT  = %0d (0x%02h)", out_port, out_port);
            $display("Flags     = Z:%0b C:%0b", dbg_zero, dbg_carry);
            if (have_expected) begin
                if (out_port == expected[7:0])
                    $display("RESULT: PASS (%s) -- out_port == %0d as expected", testname, expected);
                else
                    $display("RESULT: FAIL (%s) -- expected %0d, got %0d", testname, expected, out_port);
            end else begin
                $display("RESULT: DONE (%s) -- no +EXPECTED given, reporting only", testname);
            end
        end else begin
            $display("RESULT: TIMEOUT (%s) -- CPU never halted after %0d cycles", testname, cycle_count);
        end
        $display("====================================================");

        $finish;
    end

    // Cycle-by-cycle trace (visible with $display, also captured in VCD)
    initial begin
        $monitor("t=%0t state=%0d PC=0x%02h IR=0x%02h A=0x%02h B=0x%02h SP=0x%02h Z=%b C=%b OUT=0x%02h",
                 $time, dbg_state, dbg_pc, dbg_ir, dbg_a, dbg_b, dbg_sp, dbg_zero, dbg_carry, out_port);
    end

endmodule
