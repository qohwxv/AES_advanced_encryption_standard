`timescale 1ns/1ps

// DUT-only testbench.  It deliberately does not instantiate aes_top as an
// oracle: Python/OpenSSL verifies the [RESULT] lines after simulation.
module tb_aes256_pipeline_dynamic_100keys_log;
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
    reg [127:0] pt_vec [0:N-1];
    reg [255:0] key_vec [0:N-1];
    integer errors;
    integer i;

    aes256_pipeline_dynamic_key dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .plaintext(plaintext), .key(key), .in_ready(in_ready),
        .ciphertext(ciphertext), .out_valid(out_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_aes256_pipeline_dynamic_100keys_log.vcd");
        $dumpvars(0, tb_aes256_pipeline_dynamic_100keys_log);
        errors = 0;
        rst_n = 1'b0;
        in_valid = 1'b0;
        plaintext = 128'd0;
        key = 256'd0;

        for (i = 0; i < N; i = i + 1) begin
            key_vec[i] = 256'h00112233445566778899aabbccddeeff102132435465768798a9babcbddcedfe + i;
            pt_vec[i]  = 128'hfedcba98765432100123456789abcdef + (i * 128'h01010101010101010101010101010101);
        end

        repeat (3) @(posedge clk);
        #1 rst_n = 1'b1;

        // 100 different keys/plaintexts on consecutive clocks, then flush 14 stages.
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
                    $display("[FAIL] early output at sample %0d", i + 1);
                    errors = errors + 1;
                end
            end else if (out_valid !== 1'b1) begin
                $display("[FAIL] missing output at sample %0d (block %0d)", i + 1, i - LATENCY_SAMPLES + 1);
                errors = errors + 1;
            end else begin
                $display("[RESULT] time=%0t output_sample=%0d input_sample=%0d block=%0d key=%064h plaintext=%032h ciphertext=%032h",
                         $time, i + 1, i - LATENCY_SAMPLES + 2, i - LATENCY_SAMPLES + 1,
                         key_vec[i - LATENCY_SAMPLES + 1],
                         pt_vec[i - LATENCY_SAMPLES + 1], ciphertext);
            end
            @(negedge clk);
        end

        if (errors == 0) $display("DUT LOG TEST PRODUCED 100 RESULTS");
        else             $display("DUT LOG TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
