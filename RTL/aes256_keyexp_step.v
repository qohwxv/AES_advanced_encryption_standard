`timescale 1ns/1ps

// One AES-256 key-schedule step.
// prev_key = round key N-1, curr_key = round key N.
// even_step = 1 generates round key N+1 for an even N+1 (g-function + Rcon).
// even_step = 0 generates round key N+1 for an odd  N+1 (SubWord only).
module aes256_keyexp_step (
    input  [127:0] prev_key,
    input  [127:0] curr_key,
    input          even_step,
    input  [7:0]   rcon,
    output [127:0] next_key
);
    wire [31:0] last_word = curr_key[31:0];
    wire [7:0] sb0, sb1, sb2, sb3;
    wire [31:0] transformed_word;
    wire [31:0] nw0, nw1, nw2, nw3;

    // AES-256 has two alternating expansion operations.  For an even round
    // key, SubWord is applied after RotWord and the Rcon is XORed into byte 0.
    aes_sbox u_sb0 (.in(even_step ? last_word[23:16] : last_word[31:24]), .out(sb0));
    aes_sbox u_sb1 (.in(even_step ? last_word[15:8]  : last_word[23:16]), .out(sb1));
    aes_sbox u_sb2 (.in(even_step ? last_word[7:0]   : last_word[15:8]),  .out(sb2));
    aes_sbox u_sb3 (.in(even_step ? last_word[31:24] : last_word[7:0]),   .out(sb3));

    assign transformed_word = even_step ? {sb0 ^ rcon, sb1, sb2, sb3}
                                        : {sb0,        sb1, sb2, sb3};

    assign nw0 = prev_key[127:96] ^ transformed_word;
    assign nw1 = prev_key[95:64]   ^ nw0;
    assign nw2 = prev_key[63:32]   ^ nw1;
    assign nw3 = prev_key[31:0]    ^ nw2;
    assign next_key = {nw0, nw1, nw2, nw3};
endmodule
