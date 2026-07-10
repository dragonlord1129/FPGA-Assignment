

module control_unit (
    input  wire       clk,
    input  wire       reset,

    // status inputs from the datapath
    input  wire [7:0] ir,        // current opcode 
    input  wire       flagZ,
    input  wire       flagC,

    // ---------------- control outputs ----------------
    output reg  [3:0] state,          // current FSM state 

    // memory bus control
    output reg  [1:0] mem_addr_sel,   // 00=PC 01=OPR 10=SP 11=SP+1
    output reg         mem_we,
    output reg         mem_wdata_sel, // 0 = A, 1 = PC

    // register load/increment enables
    output reg         ir_ld,
    output reg         opr_ld,
    output reg         pc_inc,
    output reg         pc_ld,
    output reg         pc_load_sel,   // 0 = OPR, 1 = mem_rdata (stack)
    output reg         sp_inc,
    output reg         sp_dec,
    output reg         a_ld,
    output reg  [2:0]  a_sel,         // 0=alu_result 1=mem_rdata 2=OPR 3=B 4=in_port
    output reg         b_ld,
    output reg         out_ld,
    output reg         flag_z_we,
    output reg         flag_c_we,

    // ALU control
    output reg  [3:0]  alu_op,
    output reg         alu_a_sel,     // 0 = A, 1 = mem_rdata
    output reg         alu_b_sel,     // 0 = mem_rdata, 1 = OPR

    output wire        halted
);

    // ---------------- Opcodes ----------------
    localparam OP_NOP  = 8'h00;
    localparam OP_LDA  = 8'h01;
    localparam OP_STA  = 8'h02;
    localparam OP_LDI  = 8'h03;
    localparam OP_ADD  = 8'h04;
    localparam OP_ADI  = 8'h05;
    localparam OP_SUB  = 8'h06;
    localparam OP_SBI  = 8'h07;
    localparam OP_ANDA = 8'h08;
    localparam OP_ORA  = 8'h09;
    localparam OP_XORA = 8'h0A;
    localparam OP_JMP  = 8'h0B;
    localparam OP_JZ   = 8'h0C;
    localparam OP_JNZ  = 8'h0D;
    localparam OP_JC   = 8'h0E;
    localparam OP_CALL = 8'h0F;
    localparam OP_RET  = 8'h10;
    localparam OP_OUT  = 8'h11;
    localparam OP_IN   = 8'h12;
    localparam OP_MOVAB= 8'h13;
    localparam OP_MOVBA= 8'h14;
    localparam OP_INC  = 8'h15;
    localparam OP_DEC  = 8'h16;
    localparam OP_CMA  = 8'h17;
    localparam OP_SHL  = 8'h18;
    localparam OP_SHR  = 8'h19;
    localparam OP_PUSH = 8'h1A;
    localparam OP_POP  = 8'h1B;
    localparam OP_HLT  = 8'hFF;

    // ALU op codes (must match alu8.v)
    localparam ALU_ADD=4'h0, ALU_SUB=4'h1, ALU_AND=4'h2, ALU_OR=4'h3,
               ALU_XOR=4'h4, ALU_NOT=4'h5, ALU_SHL=4'h6, ALU_SHR=4'h7,
               ALU_PASS_A=4'h8, ALU_INC=4'h9, ALU_DEC=4'hA;

    // ---------------- FSM states ----------------
    localparam S_FETCH    = 4'd0;
    localparam S_DECODE   = 4'd1;
    localparam S_OPERAND  = 4'd2;
    localparam S_EXEC1    = 4'd3;
    localparam S_MEMOP    = 4'd4;
    localparam S_MEMWR    = 4'd5;
    localparam S_PUSHWR   = 4'd6;
    localparam S_STACKRD  = 4'd7;
    localparam S_CALLJUMP = 4'd8;
    localparam S_HALT     = 4'd9;

    reg [3:0] next_state;

    function is_two_byte;
        input [7:0] opc;
        begin
            case (opc)
                OP_LDA, OP_STA, OP_LDI, OP_ADD, OP_ADI, OP_SUB, OP_SBI,
                OP_ANDA, OP_ORA, OP_XORA, OP_JMP, OP_JZ, OP_JNZ, OP_JC,
                OP_CALL: is_two_byte = 1'b1;
                default: is_two_byte = 1'b0;
            endcase
        end
    endfunction

    // ================= Combinational control signal generation =================
    always @(*) begin
        // ---- safe defaults every cycle ----
        next_state    = state;
        mem_addr_sel  = 2'b00;   // PC
        mem_we        = 1'b0;
        mem_wdata_sel = 1'b0;    // A
        ir_ld         = 1'b0;
        opr_ld        = 1'b0;
        pc_inc        = 1'b0;
        pc_ld         = 1'b0;
        pc_load_sel   = 1'b0;    // OPR
        sp_inc        = 1'b0;
        sp_dec        = 1'b0;
        a_ld          = 1'b0;
        a_sel         = 3'd0;    // alu_result
        b_ld          = 1'b0;
        out_ld        = 1'b0;
        flag_z_we     = 1'b0;
        flag_c_we     = 1'b0;
        alu_op        = ALU_PASS_A;
        alu_a_sel     = 1'b0;    // A
        alu_b_sel     = 1'b0;    // mem_rdata

        case (state)
            // ---- fetch opcode byte ----
            S_FETCH: begin
                mem_addr_sel = 2'b00; // PC
                ir_ld        = 1'b1;
                pc_inc       = 1'b1;
                next_state   = S_DECODE;
            end

            // ---- route by opcode class ----
            S_DECODE: begin
                if (ir == OP_HLT)
                    next_state = S_HALT;
                else if (ir == OP_RET || ir == OP_POP)
                    next_state = S_STACKRD;
                else if (ir == OP_PUSH)
                    next_state = S_PUSHWR;
                else if (is_two_byte(ir))
                    next_state = S_OPERAND;
                else
                    next_state = S_EXEC1;
            end

            // ---- fetch operand byte ----
            S_OPERAND: begin
                mem_addr_sel = 2'b00; // PC
                opr_ld       = 1'b1;
                pc_inc       = 1'b1;
                case (ir)
                    OP_LDA, OP_ADD, OP_SUB, OP_ANDA, OP_ORA, OP_XORA:
                        next_state = S_MEMOP;
                    OP_STA:
                        next_state = S_MEMWR;
                    OP_CALL:
                        next_state = S_PUSHWR;
                    default: // LDI, ADI, SBI, JMP, JZ, JNZ, JC
                        next_state = S_EXEC1;
                endcase
            end

            // ---- ALU op using MEM[OPR] ----
            S_MEMOP: begin
                mem_addr_sel = 2'b01; // OPR
                a_ld         = 1'b1;
                a_sel        = 3'd0;  // alu_result
                flag_z_we    = 1'b1;
                case (ir)
                    OP_LDA:  begin alu_a_sel = 1'b1; alu_op = ALU_PASS_A; end            // alu_a = mem_rdata
                    OP_ADD:  begin alu_a_sel = 1'b0; alu_b_sel = 1'b0; alu_op = ALU_ADD; flag_c_we = 1'b1; end
                    OP_SUB:  begin alu_a_sel = 1'b0; alu_b_sel = 1'b0; alu_op = ALU_SUB; flag_c_we = 1'b1; end
                    OP_ANDA: begin alu_a_sel = 1'b0; alu_b_sel = 1'b0; alu_op = ALU_AND; end
                    OP_ORA:  begin alu_a_sel = 1'b0; alu_b_sel = 1'b0; alu_op = ALU_OR;  end
                    OP_XORA: begin alu_a_sel = 1'b0; alu_b_sel = 1'b0; alu_op = ALU_XOR; end
                    default: ;
                endcase
                next_state = S_FETCH;
            end

            // ---- STA: MEM[OPR] <- A ----
            S_MEMWR: begin
                mem_addr_sel  = 2'b01; // OPR
                mem_we        = 1'b1;
                mem_wdata_sel = 1'b0;  // A
                next_state    = S_FETCH;
            end

            // ---- PUSH data(A) or CALL push(PC) at MEM[SP] ----
            S_PUSHWR: begin
                mem_addr_sel  = 2'b10; // SP
                mem_we        = 1'b1;
                mem_wdata_sel = (ir == OP_CALL) ? 1'b1 : 1'b0; // PC : A
                sp_dec        = 1'b1;
                next_state    = (ir == OP_CALL) ? S_CALLJUMP : S_FETCH;
            end

            // ---- POP / RET : read MEM[SP+1] ----
            S_STACKRD: begin
                mem_addr_sel = 2'b11; // SP+1
                sp_inc       = 1'b1;
                if (ir == OP_POP) begin
                    a_ld  = 1'b1;
                    a_sel = 3'd1; // mem_rdata
                end else if (ir == OP_RET) begin
                    pc_ld       = 1'b1;
                    pc_load_sel = 1'b1; // mem_rdata
                end
                next_state = S_FETCH;
            end

            // ---- second half of CALL: PC <- OPR ----
            S_CALLJUMP: begin
                pc_ld       = 1'b1;
                pc_load_sel = 1'b0; // OPR
                next_state  = S_FETCH;
            end

            // ---- single-cycle execute (immediates / reg-only / jumps) ----
            S_EXEC1: begin
                case (ir)
                    OP_NOP: ;
                    OP_LDI: begin a_ld = 1'b1; a_sel = 3'd2; end // OPR
                    OP_ADI: begin
                        alu_a_sel = 1'b0; alu_b_sel = 1'b1; alu_op = ALU_ADD; // A + OPR
                        a_ld = 1'b1; a_sel = 3'd0; flag_z_we = 1'b1; flag_c_we = 1'b1;
                    end
                    OP_SBI: begin
                        alu_a_sel = 1'b0; alu_b_sel = 1'b1; alu_op = ALU_SUB; // A - OPR
                        a_ld = 1'b1; a_sel = 3'd0; flag_z_we = 1'b1; flag_c_we = 1'b1;
                    end
                    OP_JMP: begin pc_ld = 1'b1; pc_load_sel = 1'b0; end
                    OP_JZ:  begin pc_ld = flagZ;  pc_load_sel = 1'b0; end
                    OP_JNZ: begin pc_ld = !flagZ; pc_load_sel = 1'b0; end
                    OP_JC:  begin pc_ld = flagC;  pc_load_sel = 1'b0; end
                    OP_OUT: out_ld = 1'b1;
                    OP_IN:  begin a_ld = 1'b1; a_sel = 3'd4; end // in_port
                    OP_MOVAB: b_ld = 1'b1;
                    OP_MOVBA: begin a_ld = 1'b1; a_sel = 3'd3; end // B
                    OP_INC: begin
                        alu_a_sel = 1'b0; alu_op = ALU_INC;
                        a_ld = 1'b1; a_sel = 3'd0; flag_z_we = 1'b1; flag_c_we = 1'b1;
                    end
                    OP_DEC: begin
                        alu_a_sel = 1'b0; alu_op = ALU_DEC;
                        a_ld = 1'b1; a_sel = 3'd0; flag_z_we = 1'b1; flag_c_we = 1'b1;
                    end
                    OP_CMA: begin
                        alu_a_sel = 1'b0; alu_op = ALU_NOT;
                        a_ld = 1'b1; a_sel = 3'd0; // no flag update, matches classic CMA behavior
                    end
                    OP_SHL: begin
                        alu_a_sel = 1'b0; alu_op = ALU_SHL;
                        a_ld = 1'b1; a_sel = 3'd0; flag_z_we = 1'b1; flag_c_we = 1'b1;
                    end
                    OP_SHR: begin
                        alu_a_sel = 1'b0; alu_op = ALU_SHR;
                        a_ld = 1'b1; a_sel = 3'd0; flag_z_we = 1'b1; flag_c_we = 1'b1;
                    end
                    default: ;
                endcase
                next_state = S_FETCH;
            end

            S_HALT: next_state = S_HALT;

            default: next_state = S_FETCH;
        endcase
    end

    // ================= Sequential: state register only =================
    always @(posedge clk) begin
        if (reset)
            state <= S_FETCH;
        else
            state <= next_state;
    end

    assign halted = (state == S_HALT);

endmodule
