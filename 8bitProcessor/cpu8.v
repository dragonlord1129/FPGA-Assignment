module cpu8 #(
    parameter MEM_INIT_FILE = ""
) (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] in_port,
    output reg  [7:0] out_port,
    output wire       halted,
    // debug/observation
    output wire [7:0] dbg_pc,
    output wire [7:0] dbg_a,
    output wire [7:0] dbg_b,
    output wire [7:0] dbg_sp,
    output wire [7:0] dbg_ir,
    output wire [3:0] dbg_state,
    output wire       dbg_zero,
    output wire       dbg_carry
);

    // ---------------- Architectural registers ----------------
    reg [7:0] PC, SP, A, B, IR, OPR;
    reg       flagZ, flagC;

    // ---------------- Control <-> Datapath wires ----------------
    wire [1:0] mem_addr_sel;
    wire       mem_we;
    wire       mem_wdata_sel;
    wire       ir_ld, opr_ld;
    wire       pc_inc, pc_ld, pc_load_sel;
    wire       sp_inc, sp_dec;
    wire       a_ld;
    wire [2:0] a_sel;
    wire       b_ld;
    wire       out_ld;
    wire       flag_z_we, flag_c_we;
    wire [3:0] alu_op;
    wire       alu_a_sel, alu_b_sel;
    wire [3:0] cu_state;

    control_unit u_ctrl (
        .clk           (clk),
        .reset         (reset),
        .ir            (IR),
        .flagZ         (flagZ),
        .flagC         (flagC),
        .state         (cu_state),
        .mem_addr_sel  (mem_addr_sel),
        .mem_we        (mem_we),
        .mem_wdata_sel (mem_wdata_sel),
        .ir_ld         (ir_ld),
        .opr_ld        (opr_ld),
        .pc_inc        (pc_inc),
        .pc_ld         (pc_ld),
        .pc_load_sel   (pc_load_sel),
        .sp_inc        (sp_inc),
        .sp_dec        (sp_dec),
        .a_ld          (a_ld),
        .a_sel         (a_sel),
        .b_ld          (b_ld),
        .out_ld        (out_ld),
        .flag_z_we     (flag_z_we),
        .flag_c_we     (flag_c_we),
        .alu_op        (alu_op),
        .alu_a_sel     (alu_a_sel),
        .alu_b_sel     (alu_b_sel),
        .halted        (halted)
    );

    // ---------------- Memory bus mux ----------------
    reg  [7:0] mem_addr;
    wire [7:0] mem_wdata;
    wire [7:0] mem_rdata;

    always @(*) begin
        case (mem_addr_sel)
            2'b00: mem_addr = PC;
            2'b01: mem_addr = OPR;
            2'b10: mem_addr = SP;
            2'b11: mem_addr = SP + 8'd1;
            default: mem_addr = PC;
        endcase
    end

    assign mem_wdata = mem_wdata_sel ? PC : A;

    memory8 #(.MEM_INIT_FILE(MEM_INIT_FILE)) u_mem (
        .clk   (clk),
        .addr  (mem_addr),
        .wdata (mem_wdata),
        .we    (mem_we),
        .rdata (mem_rdata)
    );

    // ---------------- ALU + input muxes ----------------
    wire [7:0] alu_a = alu_a_sel ? mem_rdata : A;
    wire [7:0] alu_b = alu_b_sel ? OPR       : mem_rdata;
    wire [7:0] alu_result;
    wire       alu_zero, alu_carry;

    alu8 u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (alu_op),
        .result (alu_result),
        .zero   (alu_zero),
        .carry  (alu_carry)
    );

    // ---------------- A-register write-back mux ----------------
    reg [7:0] a_next;
    always @(*) begin
        case (a_sel)
            3'd0: a_next = alu_result;
            3'd1: a_next = mem_rdata;
            3'd2: a_next = OPR;
            3'd3: a_next = B;
            3'd4: a_next = in_port;
            default: a_next = alu_result;
        endcase
    end

    // ---------------- PC write-back mux ----------------
    wire [7:0] pc_next = pc_load_sel ? mem_rdata : OPR;

    // ================= Sequential register updates =================
    always @(posedge clk) begin
        if (reset) begin
            PC       <= 8'h00;
            SP       <= 8'hFF;
            A        <= 8'h00;
            B        <= 8'h00;
            IR       <= 8'h00;
            OPR      <= 8'h00;
            flagZ    <= 1'b0;
            flagC    <= 1'b0;
            out_port <= 8'h00;
        end else begin
            if (ir_ld)  IR  <= mem_rdata;
            if (opr_ld) OPR <= mem_rdata;

            if (pc_inc)      PC <= PC + 8'd1;
            else if (pc_ld)  PC <= pc_next;

            if (sp_dec)      SP <= SP - 8'd1;
            else if (sp_inc) SP <= SP + 8'd1;

            if (a_ld) A <= a_next;
            if (b_ld) B <= A;

            if (out_ld) out_port <= A;

            if (flag_z_we) flagZ <= alu_zero;
            if (flag_c_we) flagC <= alu_carry;
        end
    end

    assign dbg_pc    = PC;
    assign dbg_a     = A;
    assign dbg_b     = B;
    assign dbg_sp    = SP;
    assign dbg_ir    = IR;
    assign dbg_state = cu_state;
    assign dbg_zero  = flagZ;
    assign dbg_carry = flagC;

endmodule
