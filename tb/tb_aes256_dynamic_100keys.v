`timescale 1ns/1ps

// 100 independent keys/plaintexts.  The legacy AES pipeline instances are
// used only as per-vector golden oracles; the DUT under test is the new
// iterative dynamic-key core.  This catches key/state carry-over between
// transactions while retaining known-answer coverage in the other TBs.
module tb_aes256_dynamic_100keys;
    parameter N = 100;
    parameter SAMPLES = 15;
    reg clk;
    reg rst_n;
    reg in_valid;
    wire in_ready;
    reg [127:0] plaintext;
    reg [255:0] key;
    wire [127:0] ciphertext;
    wire out_valid;
    integer errors;
    integer i;
    integer j;

    reg [127:0] pt_vec [0:N-1];
    reg [255:0] key_vec [0:N-1];
    reg [127:0] expected_vec [0:N-1];

    // Golden oracles: each instance sees one fixed key and one pulse.
    reg oracle_start;
    wire [127:0] oracle_ct [0:N-1];
    wire [N-1:0] oracle_done;
    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : oracle_gen
            aes_top oracle (
                .clk(clk), .rst(rst_n), .plaintext(pt_vec[g]),
                .key(key_vec[g]), .start(oracle_start),
                .ciphertext(oracle_ct[g]), .done(oracle_done[g])
            );
        end
    endgenerate

    aes256_iterative_dynamic_key dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
        .plaintext(plaintext), .key(key), .ciphertext(ciphertext), .out_valid(out_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task run_one;
        input [127:0] pt;
        input [255:0] k;
        input [127:0] expected;
        input integer index;
        begin
            while (in_ready !== 1'b1) @(posedge clk);
            @(negedge clk);
            plaintext = pt;
            key = k;
            in_valid = 1'b1;
            @(posedge clk); #1;
            in_valid = 1'b0;
            for (j = 2; j < SAMPLES; j = j + 1) begin
                @(posedge clk); #1;
                if (out_valid !== 1'b0) begin
                    $display("[FAIL] vector %0d: early out_valid at sample %0d", index, j);
                    errors = errors + 1;
                end
            end
            @(posedge clk); #1;
            if (out_valid !== 1'b1 || ciphertext !== expected) begin
                $display("[FAIL] vector %0d: expected=%032h got=%032h valid=%b", index, expected, ciphertext, out_valid);
                errors = errors + 1;
            end else begin
                $display("[PASS] dynamic 100-key vector %0d", index);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_aes256_dynamic_100keys.vcd");
        $dumpvars(0, tb_aes256_dynamic_100keys);
        errors = 0;
        rst_n = 1'b0;
        in_valid = 1'b0;
        oracle_start = 1'b0;
        plaintext = 128'd0;
        key = 256'd0;

        // Deterministic, mutually different 256-bit keys and 128-bit blocks.
        for (i = 0; i < N; i = i + 1) begin
            key_vec[i] = 256'h00112233445566778899aabbccddeeff102132435465768798a9babcbddcedfe + i;
            pt_vec[i]  = 128'hfedcba98765432100123456789abcdef + (i * 128'h01010101010101010101010101010101);
        end

        repeat (3) @(posedge clk);
        #1 rst_n = 1'b1;

        // Produce all golden outputs concurrently through fixed-key oracle copies.
        @(negedge clk);
        oracle_start = 1'b1;
        @(posedge clk); #1 oracle_start = 1'b0;
        for (i = 1; i < SAMPLES; i = i + 1) @(posedge clk);
        #1;
        for (i = 0; i < N; i = i + 1) begin
            if (oracle_done[i] !== 1'b1) begin
                $display("[FAIL] oracle %0d did not assert done", i);
                errors = errors + 1;
            end
            expected_vec[i] = oracle_ct[i];
        end

        // Feed the same 100 vectors to the dynamic-key DUT, one at a time.
        for (i = 0; i < N; i = i + 1)
            run_one(pt_vec[i], key_vec[i], expected_vec[i], i);

        if (errors == 0) $display("ALL 100 DYNAMIC-KEY VECTORS PASSED");
        else             $display("100 DYNAMIC-KEY TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
