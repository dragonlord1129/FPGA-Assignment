`timescale 1ns / 1ps

module alu_tb;

    // Inputs
    reg [7:0] val1;
    reg [7:0] val2;
    reg [3:0] select;

    // Outputs
    wire [7:0] result;
    wire flag;

    // Integer to iterate through operations
    integer count;

    // Instantiate the Unit Under Test (UUT)
    alu uut (
        .val1(val1), 
        .val2(val2), 
        .select(select), 
        .result(result), 
        .flag(flag)
    );

    initial begin
        // Initialize Inputs
        val1 = 8'h0A;  // 10 in decimal
        val2 = 8'h02;  // 2 in decimal
        select = 4'b0000;  // Start with the addition operation

        // Wait 100 ns for global reset to finish
        #100;
        
        // Dump simulation data to VCD file for waveform analysis
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_tb);  // Start dumping variables

        // Stimulus: Loop through all operations
        for(count = 0; count <= 15; count = count + 1) begin
            select = count;  // Apply the current operation
            #100;  // Wait 100ns for the result
            
            // Display the results for the current operation
            $display("Operation %d, val1 = %h, val2 = %h, result = %h, flag = %b", select, val1, val2, result, flag);
        end

        // End simulation after the loop
        #100;  // Allow enough time to finish the final operation
        $finish;  // End the simulation
    end
      
endmodule
