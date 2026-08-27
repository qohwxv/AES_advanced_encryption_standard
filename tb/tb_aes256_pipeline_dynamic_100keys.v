`timescale 1ns/1ps

// Fully-pipelined dynamic-key test: 100 different keys are accepted on 100
// consecutive clocks.  Output must be the corresponding golden ciphertext on
// 100 consecutive clocks after the 15-sample pipeline latency.
module tb_aes256_pipeline_dynamic_100keys;
    parameter N = 100;
    parameter LATENCY_SAMPLES = 15;
    reg clk;
    reg rst_n;
    reg in_valid;
    reg [127:0] plaintext;
    reg [255:0] key;
    wire in_ready;
    wire [127:0] ciphertext;
    wire out_valid;
    integer errors;
    integer i;

    reg [127:0] pt_vec [0:N-1];
    reg [255:0] key_vec [0:N-1];
    reg [127:0] expected_vec [0:N-1];
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

    aes256_pipeline_dynamic_key dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .plaintext(plaintext), .key(key), .in_ready(in_ready),
        .ciphertext(ciphertext), .out_valid(out_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_aes256_pipeline_dynamic_100keys.vcd");
        $dumpvars(0, tb_aes256_pipeline_dynamic_100keys);
        errors = 0;
        rst_n = 1'b0;
        in_valid = 1'b0;
        oracle_start = 1'b0;
        plaintext = 128'd0;
        key = 256'd0;

        for (i = 0; i < N; i = i + 1) begin
            key_vec[i] = 256'h00112233445566778899aabbccddeeff102132435465768798a9babcbddcedfe + i;
            pt_vec[i]  = 128'hfedcba98765432100123456789abcdef + (i * 128'h01010101010101010101010101010101);
        end

        repeat (3) @(posedge clk);
        #1 rst_n = 1'b1;

        // Golden results from fixed-key oracle copies.
        @(negedge clk);
        oracle_start = 1'b1;
        @(posedge clk); #1 oracle_start = 1'b0;
        for (i = 1; i < LATENCY_SAMPLES; i = i + 1) @(posedge clk);
        #1;
        for (i = 0; i < N; i = i + 1) begin
            if (oracle_done[i] !== 1'b1) begin
                $display("[FAIL] oracle %0d did not assert done", i);
                errors = errors + 1;
            end
            expected_vec[i] = oracle_ct[i];
        end

        // Feed 100 different keys on consecutive rising edges.
        @(negedge clk);
        for (i = 0; i < N + LATENCY_SAMPLES - 1; i = i + 1) begin
            if (i < N) begin
                plaintext = pt_vec[i];
                key = key_vec[i];
                in_valid = 1'b1;
            end else begin
                plaintext = 128'd0;
                key = 256'd0;
                in_valid = 1'b0;
            end

            @(posedge clk); #1;
            if (i < LATENCY_SAMPLES - 1) begin
                if (out_valid !== 1'b0) begin
                    $display("[FAIL] early output at input sample %0d", i + 1);
                    errors = errors + 1;
                end
            end else begin
                if (out_valid !== 1'b1 || ciphertext !== expected_vec[i - LATENCY_SAMPLES + 1]) begin
                    $display("[FAIL] pipeline vector %0d: expected=%032h got=%032h valid=%b",
                             i - LATENCY_SAMPLES + 1, expected_vec[i - LATENCY_SAMPLES + 1], ciphertext, out_valid);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] time=%0t output_sample=%0d input_sample=%0d block=%0d key=%064h plaintext=%032h ciphertext=%032h",
                             $time, i + 1, i - LATENCY_SAMPLES + 2, i - LATENCY_SAMPLES + 1,
                             key_vec[i - LATENCY_SAMPLES + 1],
                             pt_vec[i - LATENCY_SAMPLES + 1], ciphertext);
                end
            end
            @(negedge clk);
        end

        if (errors == 0) $display("ALL 100 FULL-PIPELINE DYNAMIC-KEY VECTORS PASSED");
        else             $display("FULL-PIPELINE DYNAMIC-KEY TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
