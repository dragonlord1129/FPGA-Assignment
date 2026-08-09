module fft_top #(
    parameter N          = 8,
    parameter DATA_WIDTH = 16,
    parameter LOG2N      = 3
)(
    input  wire                                clk,
    input  wire                                rst_n,
    input  wire                                start,      // pulse high 1 cycle to begin
    input  wire signed [N*DATA_WIDTH-1:0]      data_in_re, // flattened array, sample 0 in LSBs
    input  wire signed [N*DATA_WIDTH-1:0]      data_in_im,
    output reg  signed [N*DATA_WIDTH-1:0]      data_out_re,
    output reg  signed [N*DATA_WIDTH-1:0]      data_out_im,
    output reg                                 done,
    output reg                                 busy
);

    // -------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------
    localparam S_IDLE    = 3'd0,
               S_LOAD     = 3'd1,
               S_COMPUTE  = 3'd2,
               S_NEXT     = 3'd3,
               S_OUTPUT   = 3'd4,
               S_DONE     = 3'd5;

    reg [2:0] state;
    reg [$clog2(LOG2N+1)-1:0] stage; // current stage index 0..LOG2N-1

    // -------------------------------------------------------------------
    // In-place sample memory (real / imaginary)
    // -------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] mem_re [0:N-1];
    reg signed [DATA_WIDTH-1:0] mem_im [0:N-1];

    // -------------------------------------------------------------------
    // Twiddle factor ROM: W_N^k = cos(-2*pi*k/N) + j*sin(-2*pi*k/N)
    // for k = 0 .. N/2-1, stored in Q1.15
    // -------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] twiddle_re [0:N/2-1];
    reg signed [DATA_WIDTH-1:0] twiddle_im [0:N/2-1];

    integer t;
    initial begin
        for (t = 0; t < N/2; t = t + 1) begin
            twiddle_re[t] = $rtoi($cos(2.0*3.14159265358979*t/N) * 32767.0);
            twiddle_im[t] = $rtoi(-1.0*$sin(2.0*3.14159265358979*t/N) * 32767.0);
        end
    end

    // -------------------------------------------------------------------
    // Bit-reversal helper (LOG2N bits)
    // -------------------------------------------------------------------
    function [31:0] bit_reverse;
        input [31:0] value;
        input [31:0] width;
        integer i;
        begin
            bit_reverse = 0;
            for (i = 0; i < width; i = i + 1) begin
                bit_reverse = bit_reverse | (((value >> i) & 1) << (width-1-i));
            end
        end
    endfunction

    // -------------------------------------------------------------------
    // Butterfly network: N/2 butterflies computed in parallel per stage
    // -------------------------------------------------------------------
    genvar b;
    generate
        for (b = 0; b < N/2; b = b + 1) begin : BUTTERFLIES

            wire [$clog2(N)-1:0] half_size    = (1 << stage);
            wire [$clog2(N)-1:0] group        = b >> stage;
            wire [$clog2(N)-1:0] pos          = b & ((1 << stage) - 1);
            wire [$clog2(N)-1:0] idx1         = (group << (stage+1)) + pos;
            wire [$clog2(N)-1:0] idx2         = idx1 + half_size;
            wire [$clog2(N)-1:0] tw_idx       = pos << (LOG2N - stage - 1);

            wire signed [DATA_WIDTH-1:0] a_re = mem_re[idx1];
            wire signed [DATA_WIDTH-1:0] a_im = mem_im[idx1];
            wire signed [DATA_WIDTH-1:0] b_re = mem_re[idx2];
            wire signed [DATA_WIDTH-1:0] b_im = mem_im[idx2];
            wire signed [DATA_WIDTH-1:0] w_re = twiddle_re[tw_idx];
            wire signed [DATA_WIDTH-1:0] w_im = twiddle_im[tw_idx];

            // complex multiply: (w_re + j*w_im) * (b_re + j*b_im)
            wire signed [2*DATA_WIDTH-1:0] mult_rr = w_re * b_re;
            wire signed [2*DATA_WIDTH-1:0] mult_ii = w_im * b_im;
            wire signed [2*DATA_WIDTH-1:0] mult_ri = w_re * b_im;
            wire signed [2*DATA_WIDTH-1:0] mult_ir = w_im * b_re;

            // requantize back to Q1.15 (shift right by DATA_WIDTH-1)
            wire signed [DATA_WIDTH-1:0] wb_re = (mult_rr - mult_ii) >>> (DATA_WIDTH-1);
            wire signed [DATA_WIDTH-1:0] wb_im = (mult_ri + mult_ir) >>> (DATA_WIDTH-1);

            // butterfly combine, with /2 scaling each stage to avoid overflow
            wire signed [DATA_WIDTH-1:0] x_re = (a_re + wb_re) >>> 1;
            wire signed [DATA_WIDTH-1:0] x_im = (a_im + wb_im) >>> 1;
            wire signed [DATA_WIDTH-1:0] y_re = (a_re - wb_re) >>> 1;
            wire signed [DATA_WIDTH-1:0] y_im = (a_im - wb_im) >>> 1;

            always @(posedge clk) begin
                if (state == S_COMPUTE) begin
                    mem_re[idx1] <= x_re;
                    mem_im[idx1] <= x_im;
                    mem_re[idx2] <= y_re;
                    mem_im[idx2] <= y_im;
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------------
    // Main control FSM
    // -------------------------------------------------------------------
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            stage       <= 0;
            done        <= 1'b0;
            busy        <= 1'b0;
            data_out_re <= 0;
            data_out_im <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy  <= 1'b1;
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    // load inputs in bit-reversed order for in-place computation
                    for (i = 0; i < N; i = i + 1) begin
                        mem_re[bit_reverse(i, LOG2N)] <= $signed(data_in_re[i*DATA_WIDTH +: DATA_WIDTH]);
                        mem_im[bit_reverse(i, LOG2N)] <= $signed(data_in_im[i*DATA_WIDTH +: DATA_WIDTH]);
                    end
                    stage <= 0;
                    state <= S_COMPUTE;
                end

                S_COMPUTE: begin
                    // one clock cycle per stage; BUTTERFLIES generate blocks
                    // update mem_re/mem_im on this same edge
                    state <= S_NEXT;
                end

                S_NEXT: begin
                    if (stage == LOG2N-1) begin
                        state <= S_OUTPUT;
                    end else begin
                        stage <= stage + 1;
                        state <= S_COMPUTE;
                    end
                end

                S_OUTPUT: begin
                    for (i = 0; i < N; i = i + 1) begin
                        data_out_re[i*DATA_WIDTH +: DATA_WIDTH] <= mem_re[i];
                        data_out_im[i*DATA_WIDTH +: DATA_WIDTH] <= mem_im[i];
                    end
                    state <= S_DONE;
                end

                S_DONE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule