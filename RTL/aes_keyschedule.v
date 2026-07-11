// =============================================================================
// AES-256 Key Schedule
// -----------------------------------------------------------------------------
// Input : 256-bit key  (key[255:128] = first half, key[127:0] = second half)
// Output: 15 round keys × 128-bit = 1920-bit rkey_flat
//
// AES-256 uses 60 words (w[0..59]).
// Expansion rule:
//   i mod 8 == 0 : w[i] = w[i-8] ^ SubWord(RotWord(w[i-1])) ^ Rcon[i/8]
//   i mod 8 == 4 : w[i] = w[i-8] ^ SubWord(w[i-1])          ← extra SubWord!
//   otherwise    : w[i] = w[i-8] ^ w[i-1]
//
// Rcon values needed: rcon[1..7]  (only 7 full AES-256 key-expansion rounds)
// =============================================================================
module aes256_keyschedule (
    input  [255:0]  key,
    output [1919:0] rkey_flat   // 15 × 128 bits
);
    // Rcon[1..7]
    wire [7:0] rcon [1:7];
    assign rcon[1] = 8'h01;
    assign rcon[2] = 8'h02;
    assign rcon[3] = 8'h04;
    assign rcon[4] = 8'h08;
    assign rcon[5] = 8'h10;
    assign rcon[6] = 8'h20;
    assign rcon[7] = 8'h40;

    wire [31:0] w [0:59];

    // Initial 8 words come directly from the 256-bit key
    assign w[0] = key[255:224];
    assign w[1] = key[223:192];
    assign w[2] = key[191:160];
    assign w[3] = key[159:128];
    assign w[4] = key[127:96];
    assign w[5] = key[95:64];
    assign w[6] = key[63:32];
    assign w[7] = key[31:0];

    // -------------------------------------------------------------------------
    // Generate w[8] .. w[59]
    // We unroll by groups of 8 words per key-expansion round (7 rounds total).
    // For each group starting at base = 8*i (i=1..7):
    //   w[base+0] uses RotWord+SubWord+Rcon  (index mod 8 == 0)
    //   w[base+1..3] are simple XOR         (index mod 8 == 1,2,3)
    //   w[base+4] uses SubWord only          (index mod 8 == 4)
    //   w[base+5..7] are simple XOR         (index mod 8 == 5,6,7)
    // -------------------------------------------------------------------------
    genvar i;
    generate
        for (i = 1; i <= 7; i = i + 1) begin : ks256_round

            // --- w[8i+0] : RotWord(w[8i-1]) → SubWord → XOR Rcon → XOR w[8i-8] ---
            wire [7:0] rot0_a, rot1_a, rot2_a, rot3_a;
            wire [7:0] sub0_a, sub1_a, sub2_a, sub3_a;

            // RotWord: rotate left by 8 bits
            assign rot0_a = w[8*i-1][23:16];
            assign rot1_a = w[8*i-1][15:8];
            assign rot2_a = w[8*i-1][7:0];
            assign rot3_a = w[8*i-1][31:24];

            aes_sbox sb0_a(.in(rot0_a),.out(sub0_a));
            aes_sbox sb1_a(.in(rot1_a),.out(sub1_a));
            aes_sbox sb2_a(.in(rot2_a),.out(sub2_a));
            aes_sbox sb3_a(.in(rot3_a),.out(sub3_a));

            assign w[8*i+0] = w[8*i-8] ^ {sub0_a ^ rcon[i], sub1_a, sub2_a, sub3_a};

            // --- w[8i+1..3] : simple XOR ---
            assign w[8*i+1] = w[8*i-7] ^ w[8*i+0];
            assign w[8*i+2] = w[8*i-6] ^ w[8*i+1];
            assign w[8*i+3] = w[8*i-5] ^ w[8*i+2];

            

            // --- w[8i+5..7] : simple XOR ---
            // Guard: only generate if the index is within w[0..59]
            // For i=7: 8*7+5=61 > 59, so only w[56..59] are valid (base+0..3)
            if (i < 7) begin : ks_extra
                // --- w[8i+4] : SubWord(w[8i+3]) XOR w[8i-4]  (NO RotWord, NO Rcon) ---
              wire [7:0] sub0_b, sub1_b, sub2_b, sub3_b;

              aes_sbox sb0_b(.in(w[8*i+3][31:24]),.out(sub0_b));
              aes_sbox sb1_b(.in(w[8*i+3][23:16]),.out(sub1_b));
              aes_sbox sb2_b(.in(w[8*i+3][15:8]), .out(sub2_b));
              aes_sbox sb3_b(.in(w[8*i+3][7:0]),  .out(sub3_b));

                assign w[8*i+4] = w[8*i-4] ^ {sub0_b, sub1_b, sub2_b, sub3_b};
                
                assign w[8*i+5] = w[8*i-3] ^ w[8*i+4];
                assign w[8*i+6] = w[8*i-2] ^ w[8*i+5];
                assign w[8*i+7] = w[8*i-1] ^ w[8*i+6];
            end
        end
    endgenerate

    // Pack 15 round keys: round key r = {w[4r], w[4r+1], w[4r+2], w[4r+3]}
    genvar r;
    generate
        for (r = 0; r <= 14; r = r + 1) begin : rk256_pack
            assign rkey_flat[r*128 +: 128] = {w[4*r], w[4*r+1], w[4*r+2], w[4*r+3]};
        end
    endgenerate

endmodule
