`timescale 1ns/1ps

// Fully-pipelined AES-256 with a key schedule travelling alongside each block.
// Every pipeline stage performs one AES round and expands exactly one next
// 128-bit round key for that same transaction.  Consequently a new
// plaintext/key pair can be accepted every clock, even when every key differs.
module aes256_pipeline_dynamic_key (
    input           clk,
    input           rst_n,
    input           in_valid,
    input  [127:0]  plaintext,
    input  [255:0]  key,
    output          in_ready,
    output [127:0]  ciphertext,
    output          out_valid
);
    reg [127:0] state_reg [0:14];
    reg [127:0] prev_key_reg [0:14];
    reg [127:0] curr_key_reg [0:14];
    reg [14:0] valid_reg;

    function [7:0] rcon_for_round;
        input integer r;
        begin
            case (r)
                1:  rcon_for_round = 8'h01;
                3:  rcon_for_round = 8'h02;
                5:  rcon_for_round = 8'h04;
                7:  rcon_for_round = 8'h08;
                9:  rcon_for_round = 8'h10;
                11: rcon_for_round = 8'h20;
                13: rcon_for_round = 8'h40;
                default: rcon_for_round = 8'h00;
            endcase
        end
    endfunction

    // Stage 0: initial AddRoundKey.  The two halves of the input key are RK0/RK1.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg[0]    <= 128'd0;
            prev_key_reg[0] <= 128'd0;
            curr_key_reg[0] <= 128'd0;
            valid_reg[0]    <= 1'b0;
        end else begin
            state_reg[0]    <= plaintext ^ key[255:128];
            prev_key_reg[0] <= key[255:128];
            curr_key_reg[0] <= key[127:0];
            valid_reg[0]    <= in_valid;
        end
    end

    genvar g;
    generate
        for (g = 1; g <= 14; g = g + 1) begin : pipeline_stage
            localparam integer IS_EVEN_NEXT = (g % 2); // odd round -> even next round
            wire even_step_wire = IS_EVEN_NEXT ? 1'b1 : 1'b0;
            wire [127:0] sb_out;
            wire [127:0] sr_out;
            wire [127:0] mc_out;
            wire [127:0] round_out;
            wire [127:0] next_key;

            aes_subbytes   u_sub   (.state_in(state_reg[g-1]), .state_out(sb_out));
            aes_shiftrows  u_shift (.state_in(sb_out),          .state_out(sr_out));
            aes_mixcolumns u_mix   (.state_in(sr_out),          .state_out(mc_out));

            assign round_out = (g == 14) ? (sr_out ^ curr_key_reg[g-1])
                                         : (mc_out ^ curr_key_reg[g-1]);

            aes256_keyexp_step u_keyexp (
                .prev_key (prev_key_reg[g-1]),
                .curr_key (curr_key_reg[g-1]),
                .even_step(even_step_wire),
                .rcon     (rcon_for_round(g)),
                .next_key (next_key)
            );

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    state_reg[g]    <= 128'd0;
                    prev_key_reg[g] <= 128'd0;
                    curr_key_reg[g] <= 128'd0;
                    valid_reg[g]    <= 1'b0;
                end else begin
                    state_reg[g]    <= round_out;
                    prev_key_reg[g] <= curr_key_reg[g-1];
                    curr_key_reg[g] <= next_key;
                    valid_reg[g]    <= valid_reg[g-1];
                end
            end
        end
    endgenerate

    assign in_ready  = 1'b1;
    assign ciphertext = state_reg[14];
    assign out_valid = valid_reg[14];
endmodule
