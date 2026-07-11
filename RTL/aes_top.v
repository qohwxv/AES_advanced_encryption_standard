// Design Name: AES-256 Hardware Design (converted from AES-128)
// Module Name: aes256_pipeline_top
// Project Name: High Performance AES-256 Hardware Accelerator
// Tool Versions: Icarus Verilog (iverilog-v12), GTKWave 3.3.126
//
// AES-256 changes vs AES-128:
//   - Key:        128-bit  ->  256-bit
//   - Rounds:     10       ->  14
//   - Pipeline stages: 11  ->  15  (stage 0 + 14 rounds)
//   - rkey_flat:  1408-bit ->  1920-bit  (15 x 128)
//   - done_sr:    11-bit   ->  15-bit
//////////////////////////////////////////////////////////////////////////////////

// =============================================================================
// TOP — AES-256 fully-pipelined (1 block per cycle throughput)
// =============================================================================
module aes_top (
    input          clk,
    input          rst,        // Active-LOW Asynchronous Reset (rst = 0 de reset)
    input  [127:0] plaintext,
    input  [255:0] key,        // 256-bit key
    input          start,
    output [127:0] ciphertext,
    output         done
);

    // -------------------------------------------------------------------------
    // Key Schedule: combinational, generates all 15 round keys simultaneously
    // rkey_flat[k*128 +: 128] = round key k  (k = 0..14)
    // -------------------------------------------------------------------------
    wire [1919:0] rkey_flat;   // 15 x 128 = 1920 bits

    aes256_keyschedule u_ks (
        .key      (key),
        .rkey_flat(rkey_flat)
    );

    wire [127:0] rkey0  = rkey_flat[  0*128 +: 128];
    wire [127:0] rkey1  = rkey_flat[  1*128 +: 128];
    wire [127:0] rkey2  = rkey_flat[  2*128 +: 128];
    wire [127:0] rkey3  = rkey_flat[  3*128 +: 128];
    wire [127:0] rkey4  = rkey_flat[  4*128 +: 128];
    wire [127:0] rkey5  = rkey_flat[  5*128 +: 128];
    wire [127:0] rkey6  = rkey_flat[  6*128 +: 128];
    wire [127:0] rkey7  = rkey_flat[  7*128 +: 128];
    wire [127:0] rkey8  = rkey_flat[  8*128 +: 128];
    wire [127:0] rkey9  = rkey_flat[  9*128 +: 128];
    wire [127:0] rkey10 = rkey_flat[ 10*128 +: 128];
    wire [127:0] rkey11 = rkey_flat[ 11*128 +: 128];
    wire [127:0] rkey12 = rkey_flat[ 12*128 +: 128];
    wire [127:0] rkey13 = rkey_flat[ 13*128 +: 128];
    wire [127:0] rkey14 = rkey_flat[ 14*128 +: 128];

    // -------------------------------------------------------------------------
    // 'done' shift register — 15 cycles latency (stage 0 + 14 rounds)
    // -------------------------------------------------------------------------
    reg [14:0] done_sr;   // 15 bits

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            done_sr <= 15'b0;
        end else begin
            done_sr[0]  <= start;
            done_sr[1]  <= done_sr[0];
            done_sr[2]  <= done_sr[1];
            done_sr[3]  <= done_sr[2];
            done_sr[4]  <= done_sr[3];
            done_sr[5]  <= done_sr[4];
            done_sr[6]  <= done_sr[5];
            done_sr[7]  <= done_sr[6];
            done_sr[8]  <= done_sr[7];
            done_sr[9]  <= done_sr[8];
            done_sr[10] <= done_sr[9];
            done_sr[11] <= done_sr[10];
            done_sr[12] <= done_sr[11];
            done_sr[13] <= done_sr[12];
            done_sr[14] <= done_sr[13];
        end
    end

    assign done = done_sr[14];

    // -------------------------------------------------------------------------
    // STAGE 0 — Initial AddRoundKey  (plaintext XOR rkey0)
    // -------------------------------------------------------------------------
    wire [127:0] s0_out;
    reg  [127:0] pr0;

    assign s0_out = plaintext ^ rkey0;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr0 <= 128'b0;
        else      pr0 <= s0_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 1 — Full round 1 (SubBytes -> ShiftRows -> MixCols -> AddRK1)
    // -------------------------------------------------------------------------
    wire [127:0] s1_sub, s1_shift, s1_mix, s1_out;
    reg  [127:0] pr1;

    aes_subbytes   u_s1_sub (.state_in(pr0),      .state_out(s1_sub));
    aes_shiftrows  u_s1_sr  (.state_in(s1_sub),   .state_out(s1_shift));
    aes_mixcolumns u_s1_mc  (.state_in(s1_shift), .state_out(s1_mix));
    assign s1_out = s1_mix ^ rkey1;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr1 <= 128'b0;
        else      pr1 <= s1_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 2
    // -------------------------------------------------------------------------
    wire [127:0] s2_sub, s2_shift, s2_mix, s2_out;
    reg  [127:0] pr2;

    aes_subbytes   u_s2_sub (.state_in(pr1),      .state_out(s2_sub));
    aes_shiftrows  u_s2_sr  (.state_in(s2_sub),   .state_out(s2_shift));
    aes_mixcolumns u_s2_mc  (.state_in(s2_shift), .state_out(s2_mix));
    assign s2_out = s2_mix ^ rkey2;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr2 <= 128'b0;
        else      pr2 <= s2_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 3
    // -------------------------------------------------------------------------
    wire [127:0] s3_sub, s3_shift, s3_mix, s3_out;
    reg  [127:0] pr3;

    aes_subbytes   u_s3_sub (.state_in(pr2),      .state_out(s3_sub));
    aes_shiftrows  u_s3_sr  (.state_in(s3_sub),   .state_out(s3_shift));
    aes_mixcolumns u_s3_mc  (.state_in(s3_shift), .state_out(s3_mix));
    assign s3_out = s3_mix ^ rkey3;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr3 <= 128'b0;
        else      pr3 <= s3_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 4
    // -------------------------------------------------------------------------
    wire [127:0] s4_sub, s4_shift, s4_mix, s4_out;
    reg  [127:0] pr4;

    aes_subbytes   u_s4_sub (.state_in(pr3),      .state_out(s4_sub));
    aes_shiftrows  u_s4_sr  (.state_in(s4_sub),   .state_out(s4_shift));
    aes_mixcolumns u_s4_mc  (.state_in(s4_shift), .state_out(s4_mix));
    assign s4_out = s4_mix ^ rkey4;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr4 <= 128'b0;
        else      pr4 <= s4_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 5
    // -------------------------------------------------------------------------
    wire [127:0] s5_sub, s5_shift, s5_mix, s5_out;
    reg  [127:0] pr5;

    aes_subbytes   u_s5_sub (.state_in(pr4),      .state_out(s5_sub));
    aes_shiftrows  u_s5_sr  (.state_in(s5_sub),   .state_out(s5_shift));
    aes_mixcolumns u_s5_mc  (.state_in(s5_shift), .state_out(s5_mix));
    assign s5_out = s5_mix ^ rkey5;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr5 <= 128'b0;
        else      pr5 <= s5_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 6
    // -------------------------------------------------------------------------
    wire [127:0] s6_sub, s6_shift, s6_mix, s6_out;
    reg  [127:0] pr6;

    aes_subbytes   u_s6_sub (.state_in(pr5),      .state_out(s6_sub));
    aes_shiftrows  u_s6_sr  (.state_in(s6_sub),   .state_out(s6_shift));
    aes_mixcolumns u_s6_mc  (.state_in(s6_shift), .state_out(s6_mix));
    assign s6_out = s6_mix ^ rkey6;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr6 <= 128'b0;
        else      pr6 <= s6_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 7
    // -------------------------------------------------------------------------
    wire [127:0] s7_sub, s7_shift, s7_mix, s7_out;
    reg  [127:0] pr7;

    aes_subbytes   u_s7_sub (.state_in(pr6),      .state_out(s7_sub));
    aes_shiftrows  u_s7_sr  (.state_in(s7_sub),   .state_out(s7_shift));
    aes_mixcolumns u_s7_mc  (.state_in(s7_shift), .state_out(s7_mix));
    assign s7_out = s7_mix ^ rkey7;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr7 <= 128'b0;
        else      pr7 <= s7_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 8
    // -------------------------------------------------------------------------
    wire [127:0] s8_sub, s8_shift, s8_mix, s8_out;
    reg  [127:0] pr8;

    aes_subbytes   u_s8_sub (.state_in(pr7),      .state_out(s8_sub));
    aes_shiftrows  u_s8_sr  (.state_in(s8_sub),   .state_out(s8_shift));
    aes_mixcolumns u_s8_mc  (.state_in(s8_shift), .state_out(s8_mix));
    assign s8_out = s8_mix ^ rkey8;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr8 <= 128'b0;
        else      pr8 <= s8_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 9
    // -------------------------------------------------------------------------
    wire [127:0] s9_sub, s9_shift, s9_mix, s9_out;
    reg  [127:0] pr9;

    aes_subbytes   u_s9_sub (.state_in(pr8),      .state_out(s9_sub));
    aes_shiftrows  u_s9_sr  (.state_in(s9_sub),   .state_out(s9_shift));
    aes_mixcolumns u_s9_mc  (.state_in(s9_shift), .state_out(s9_mix));
    assign s9_out = s9_mix ^ rkey9;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr9 <= 128'b0;
        else      pr9 <= s9_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 10
    // -------------------------------------------------------------------------
    wire [127:0] s10_sub, s10_shift, s10_mix, s10_out;
    reg  [127:0] pr10;

    aes_subbytes   u_s10_sub (.state_in(pr9),       .state_out(s10_sub));
    aes_shiftrows  u_s10_sr  (.state_in(s10_sub),   .state_out(s10_shift));
    aes_mixcolumns u_s10_mc  (.state_in(s10_shift), .state_out(s10_mix));
    assign s10_out = s10_mix ^ rkey10;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr10 <= 128'b0;
        else      pr10 <= s10_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 11
    // -------------------------------------------------------------------------
    wire [127:0] s11_sub, s11_shift, s11_mix, s11_out;
    reg  [127:0] pr11;

    aes_subbytes   u_s11_sub (.state_in(pr10),      .state_out(s11_sub));
    aes_shiftrows  u_s11_sr  (.state_in(s11_sub),   .state_out(s11_shift));
    aes_mixcolumns u_s11_mc  (.state_in(s11_shift), .state_out(s11_mix));
    assign s11_out = s11_mix ^ rkey11;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr11 <= 128'b0;
        else      pr11 <= s11_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 12
    // -------------------------------------------------------------------------
    wire [127:0] s12_sub, s12_shift, s12_mix, s12_out;
    reg  [127:0] pr12;

    aes_subbytes   u_s12_sub (.state_in(pr11),      .state_out(s12_sub));
    aes_shiftrows  u_s12_sr  (.state_in(s12_sub),   .state_out(s12_shift));
    aes_mixcolumns u_s12_mc  (.state_in(s12_shift), .state_out(s12_mix));
    assign s12_out = s12_mix ^ rkey12;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr12 <= 128'b0;
        else      pr12 <= s12_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 13
    // -------------------------------------------------------------------------
    wire [127:0] s13_sub, s13_shift, s13_mix, s13_out;
    reg  [127:0] pr13;

    aes_subbytes   u_s13_sub (.state_in(pr12),      .state_out(s13_sub));
    aes_shiftrows  u_s13_sr  (.state_in(s13_sub),   .state_out(s13_shift));
    aes_mixcolumns u_s13_mc  (.state_in(s13_shift), .state_out(s13_mix));
    assign s13_out = s13_mix ^ rkey13;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr13 <= 128'b0;
        else      pr13 <= s13_out;
    end

    // -------------------------------------------------------------------------
    // STAGE 14 — Final round (SubBytes -> ShiftRows -> AddRK14, NO MixCols)
    // -------------------------------------------------------------------------
    wire [127:0] s14_sub, s14_shift, s14_out;
    reg  [127:0] pr14;

    aes_subbytes  u_s14_sub (.state_in(pr13),      .state_out(s14_sub));
    aes_shiftrows u_s14_sr  (.state_in(s14_sub),   .state_out(s14_shift));
    assign s14_out = s14_shift ^ rkey14;

    always @(posedge clk or negedge rst) begin
        if (!rst) pr14 <= 128'b0;
        else      pr14 <= s14_out;
    end

    assign ciphertext = pr14;

endmodule