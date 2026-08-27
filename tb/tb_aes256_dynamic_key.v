`timescale 1ns/1ps

// Integration test: every request supplies its own key and is checked against
// an AES-256-ECB golden result.  Includes a reset that aborts an in-flight block.
module tb_aes256_dynamic_key;
    parameter LATENCY = 15;
    reg clk;
    reg rst_n;
    reg in_valid;
    wire in_ready;
    reg [127:0] plaintext;
    reg [255:0] key;
    wire [127:0] ciphertext;
    wire out_valid;
    integer errors;
    integer cycles;

    aes256_iterative_dynamic_key dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
        .plaintext(plaintext), .key(key), .ciphertext(ciphertext), .out_valid(out_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;
    always @(posedge clk) cycles = cycles + 1;

    task reset_dut;
        begin
            rst_n = 1'b0; in_valid = 1'b0; plaintext = 128'd0; key = 256'd0;
            repeat (2) @(posedge clk);
            #1 rst_n = 1'b1;
            @(posedge clk); #1;
            if (in_ready !== 1'b1) begin
                $display("[FAIL] core not ready after reset"); errors = errors + 1;
            end
        end
    endtask

    task run_one;
        input [127:0] pt;
        input [255:0] k;
        input [127:0] expected_ct;
        integer wait_cycles;
        begin
            while (in_ready !== 1'b1) @(posedge clk);
            @(negedge clk);
            plaintext = pt; key = k; in_valid = 1'b1;
            @(posedge clk); #1;
            in_valid = 1'b0;
            // Deliberately change input buses after acceptance: the result must not change.
            plaintext = ~pt; key = ~k;
            if (in_ready !== 1'b0) begin
                $display("[FAIL] core accepted a second block while busy"); errors = errors + 1;
            end
            // The acceptance edge is sample 1.  out_valid is due at sample 15.
            for (wait_cycles = 2; wait_cycles < LATENCY; wait_cycles = wait_cycles + 1) begin
                @(posedge clk); #1;
                if (out_valid !== 1'b0) begin
                    $display("[FAIL] output arrived early after %0d cycles", wait_cycles);
                    errors = errors + 1;
                end
            end
            @(posedge clk); #1;
            if (out_valid !== 1'b1 || ciphertext !== expected_ct) begin
                $display("[FAIL] dynamic-key vector");
                $display("       expected=%032h got=%032h valid=%b", expected_ct, ciphertext, out_valid);
                errors = errors + 1;
            end else begin
                $display("[PASS] dynamic key ciphertext=%032h", ciphertext);
            end
            @(posedge clk); #1;
            if (out_valid !== 1'b0 || in_ready !== 1'b1) begin
                $display("[FAIL] output/ready protocol after completion"); errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_aes256_dynamic_key.vcd");
        $dumpvars(0, tb_aes256_dynamic_key);
        errors = 0; cycles = 0;
        reset_dut();

        // FIPS-197 Appendix C.3 AES-256 known-answer test.
        run_one(128'h00112233445566778899aabbccddeeff,
                256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f,
                128'h8ea2b7ca516745bfeafc49904b496089);
        run_one(128'h7472756f6e67646169686f63636e7474,
                256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4,
                128'hc8fdbcaee2ca7cfdfc40ddf1bab1d0e0);
        run_one(128'h00000000000000000000000000000001,
                256'hc47b029dbbbee0f2ec4757f22ffeee35f13a2f829bb43a86b9f7d7e6791b8ad5,
                128'h564e771151065a78f84e2852715266d1);

        // Reset must discard a transaction and never produce its ciphertext.
        @(negedge clk);
        plaintext = 128'h0123456789abcdeffedcba9876543210;
        key = 256'd0; in_valid = 1'b1;
        @(posedge clk); #1 in_valid = 1'b0;
        repeat (5) @(posedge clk);
        #1 rst_n = 1'b0;
        #2;
        if (out_valid !== 1'b0) begin
            $display("[FAIL] out_valid asserted during reset"); errors = errors + 1;
        end
        #2 rst_n = 1'b1;
        repeat (16) begin
            @(posedge clk); #1;
            if (out_valid !== 1'b0) begin
                $display("[FAIL] reset did not flush in-flight transaction"); errors = errors + 1;
            end
        end

        if (errors == 0) $display("ALL DYNAMIC-KEY TESTS PASSED");
        else             $display("DYNAMIC-KEY TESTS FAILED: %0d", errors);
        $finish;
    end
endmodule
