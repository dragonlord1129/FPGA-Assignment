module fft_tb;

    localparam N          = 8;
    localparam DATA_WIDTH = 16;
    localparam LOG2N      = 3;
    localparam real SCALE = 32768.0; // Q1.15 scale factor

    reg                              clk;
    reg                              rst_n;
    reg                              start;
    reg  signed [N*DATA_WIDTH-1:0]   data_in_re;
    reg  signed [N*DATA_WIDTH-1:0]   data_in_im;
    wire signed [N*DATA_WIDTH-1:0]   data_out_re;
    wire signed [N*DATA_WIDTH-1:0]   data_out_im;
    wire                             done;
    wire                             busy;

    integer fh;     // output file handle
    integer i;
    real    sample_re [0:N-1];
    real    sample_im [0:N-1];

    fft_top #(
        .N(N), .DATA_WIDTH(DATA_WIDTH), .LOG2N(LOG2N)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in_re(data_in_re),
        .data_in_im(data_in_im),
        .data_out_re(data_out_re),
        .data_out_im(data_out_im),
        .done(done),
        .busy(busy)
    );

    // 10 ns clock period (100 MHz)
    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    // Task: load N real-valued samples into the flattened input buses
    // ---------------------------------------------------------------
    task load_samples;
        integer k;
        reg signed [DATA_WIDTH-1:0] fixed_re, fixed_im;
        begin
            for (k = 0; k < N; k = k + 1) begin
                fixed_re = $rtoi(sample_re[k] * (SCALE-1));
                fixed_im = $rtoi(sample_im[k] * (SCALE-1));
                data_in_re[k*DATA_WIDTH +: DATA_WIDTH] = fixed_re;
                data_in_im[k*DATA_WIDTH +: DATA_WIDTH] = fixed_im;
            end
        end
    endtask

    // ---------------------------------------------------------------
    // Task: run one FFT transform and dump input/output to the file
    // ---------------------------------------------------------------
    task run_test;
        input [255:0] test_name; // ASCII label
        integer k;
        real out_re, out_im;
        begin
            load_samples;
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            wait (done == 1'b1);
            @(posedge clk);

            $fwrite(fh, "# TEST %0s\n", test_name);
            $fwrite(fh, "N %0d\n", N);
            for (k = 0; k < N; k = k + 1) begin
                out_re = $itor($signed(data_out_re[k*DATA_WIDTH +: DATA_WIDTH])) / SCALE;
                out_im = $itor($signed(data_out_im[k*DATA_WIDTH +: DATA_WIDTH])) / SCALE;
                $fwrite(fh, "%0d %f %f %f %f\n", k, sample_re[k], sample_im[k], out_re, out_im);
            end
            $fwrite(fh, "\n");

            $display("---- %0s ----", test_name);
            for (k = 0; k < N; k = k + 1) begin
                out_re = $itor($signed(data_out_re[k*DATA_WIDTH +: DATA_WIDTH])) / SCALE;
                out_im = $itor($signed(data_out_im[k*DATA_WIDTH +: DATA_WIDTH])) / SCALE;
                $display("bin %0d : re=%f  im=%f  mag=%f", k, out_re, out_im,
                          $sqrt(out_re*out_re + out_im*out_im));
            end
        end
    endtask

    initial begin
        clk   = 0;
        rst_n = 0;
        start = 0;
        data_in_re = 0;
        data_in_im = 0;

        fh = $fopen("fft_results.txt", "w");

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // ---------------- Test 1: unit impulse ----------------
        for (i = 0; i < N; i = i + 1) begin
            sample_re[i] = (i == 0) ? 1.0 : 0.0;
            sample_im[i] = 0.0;
        end
        run_test("impulse");

        repeat (3) @(posedge clk);

        // ---------------- Test 2: sine wave, 2 cycles over N samples ----------------
        for (i = 0; i < N; i = i + 1) begin
            sample_re[i] = 0.5 * $sin(2.0*3.14159265358979*2*i/N);
            sample_im[i] = 0.0;
        end
        run_test("sine_bin2");

        repeat (3) @(posedge clk);

        // ---------------- Test 3: DC + two tones ----------------
        for (i = 0; i < N; i = i + 1) begin
            sample_re[i] = 0.2
                         + 0.3 * $cos(2.0*3.14159265358979*1*i/N)
                         + 0.15* $sin(2.0*3.14159265358979*3*i/N);
            sample_im[i] = 0.0;
        end
        run_test("mixed_tones");

        repeat (3) @(posedge clk);

        $fclose(fh);
        $display("All tests complete. Results written to fft_results.txt");
        $finish;
    end

    // safety timeout
    initial begin
        #100000;
        $display("ERROR: simulation timeout");
        $finish;
    end

endmodule