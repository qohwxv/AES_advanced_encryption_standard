`timescale 1ns/1ps

// AES-256 encryption core with a per-transaction 256-bit key.
// The key schedule creates exactly one 128-bit round key each active cycle.
// Latency: out_valid occurs at sample 15 when the accepted input is sample 1.
// Throughput: one block per 15 cycles (a deliberate area/key-flexibility trade-off).
module aes256_iterative_dynamic_key (
    input           clk,
    input           rst_n,
    input           in_valid,
    output          in_ready,
    input  [127:0]  plaintext,
    input  [255:0]  key,
    output reg [127:0] ciphertext,
    output reg      out_valid
);
    reg         busy;
    reg [3:0]   round;
    reg [127:0] state_reg;
    reg [127:0] prev_key_reg;
    reg [127:0] curr_key_reg;

    // After odd round N comes even round N+1, which uses g-function + Rcon.
    wire even_next = round[0];
    wire [7:0] rcon = (round == 4'd1)  ? 8'h01 :
                      (round == 4'd3)  ? 8'h02 :
                      (round == 4'd5)  ? 8'h04 :
                      (round == 4'd7)  ? 8'h08 :
                      (round == 4'd9)  ? 8'h10 :
                      (round == 4'd11) ? 8'h20 :
                      (round == 4'd13) ? 8'h40 : 8'h00;

    wire [127:0] next_key;
    wire [127:0] round_sub;
    wire [127:0] round_shift;
    wire [127:0] round_mix;
    wire [127:0] round_state;

    aes256_keyexp_step u_keyexp (
        .prev_key (prev_key_reg),
        .curr_key (curr_key_reg),
        .even_step(even_next),
        .rcon     (rcon),
        .next_key (next_key)
    );

    aes_subbytes  u_sub   (.state_in(state_reg),  .state_out(round_sub));
    aes_shiftrows u_shift (.state_in(round_sub),  .state_out(round_shift));
    aes_mixcolumns u_mix  (.state_in(round_shift), .state_out(round_mix));

    // curr_key_reg is always the key for the round currently being executed.
    assign round_state = (round == 4'd14) ? (round_shift ^ curr_key_reg)
                                          : (round_mix ^ curr_key_reg);

    assign in_ready = ~busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy         <= 1'b0;
            round        <= 4'd0;
            state_reg    <= 128'd0;
            prev_key_reg <= 128'd0;
            curr_key_reg <= 128'd0;
            ciphertext   <= 128'd0;
            out_valid    <= 1'b0;
        end else begin
            out_valid <= 1'b0;

            if (!busy) begin
                if (in_valid) begin
                    // AES-256 round key 0 and 1 are the two halves of the input key.
                    state_reg    <= plaintext ^ key[255:128];
                    prev_key_reg <= key[255:128];
                    curr_key_reg <= key[127:0];
                    round        <= 4'd1;
                    busy         <= 1'b1;
                end
            end else begin
                state_reg <= round_state;

                if (round == 4'd14) begin
                    ciphertext <= round_state;
                    out_valid  <= 1'b1;
                    busy       <= 1'b0;
                    round      <= 4'd0;
                end else begin
                    prev_key_reg <= curr_key_reg;
                    curr_key_reg <= next_key;
                    round        <= round + 1'b1;
                end
            end
        end
    end
endmodule
