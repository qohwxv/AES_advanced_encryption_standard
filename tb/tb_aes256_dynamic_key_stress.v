`timescale 1ns/1ps

// Deterministic AES-256-ECB stress vectors generated with OpenSSL.
// Every vector has a different key, exercising the per-transaction key capture.
module tb_aes256_dynamic_key_stress;
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
    integer passed;

    aes256_iterative_dynamic_key dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
        .plaintext(plaintext), .key(key), .ciphertext(ciphertext), .out_valid(out_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task run_one;
        input [127:0] pt;
        input [255:0] k;
        input [127:0] expected_ct;
        integer sample;
        begin
            while (in_ready !== 1'b1) @(posedge clk);
            @(negedge clk);
            plaintext = pt;
            key = k;
            in_valid = 1'b1;
            @(posedge clk);
            #1 in_valid = 1'b0;

            for (sample = 2; sample < LATENCY; sample = sample + 1) begin
                @(posedge clk); #1;
                if (out_valid !== 1'b0) begin
                    $display("[FAIL] vector %0d: early out_valid at sample %0d", passed + errors + 1, sample);
                    errors = errors + 1;
                end
            end
            @(posedge clk); #1;
            if (out_valid !== 1'b1 || ciphertext !== expected_ct) begin
                $display("[FAIL] vector %0d: expected %032h, got %032h", passed + errors + 1, expected_ct, ciphertext);
                errors = errors + 1;
            end else begin
                passed = passed + 1;
                $display("[PASS] stress vector %0d", passed);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_aes256_dynamic_key_stress.vcd");
        $dumpvars(0, tb_aes256_dynamic_key_stress);
        errors = 0;
        passed = 0;
        rst_n = 1'b0;
        in_valid = 1'b0;
        plaintext = 128'd0;
        key = 256'd0;
        repeat (2) @(posedge clk);
        #1 rst_n = 1'b1;

        run_one(128'h00000000000000000000000000000000, 256'h0000000000000000000000000000000000000000000000000000000000000000, 128'hdc95c078a2408989ad48a21492842087);
        run_one(128'hffffffffffffffffffffffffffffffff, 256'hffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 128'hd5f93d6d3311cb309f23621b02fbd5e2);
        run_one(128'h0123456789abcdef0011223344556677, 256'h00112233445566778899aabbccddeeff102132435465768798a9babcbddcedfe, 128'h3e53a93e538d89a264d246f13fe10cba);
        run_one(128'h89abcdef01234567fedcba9876543210, 256'hdeadbeefcafebabefeedface0123456789abcdef012345670123456789abcdef, 128'hbbc3781273ea917df861c8c2a3f598f6);
        run_one(128'h13579bdf2468ace00123456789abcdef, 256'h3141592653589793238462643383279502718281828459045235360287471352, 128'hb15a8521cc452e3ad76526d60b504762);
        run_one(128'haaaaaaaa55555555aaaaaaaa55555555, 256'h55555555aaaaaaaa55555555aaaaaaaa0123456789abcdef0123456789abcdef, 128'h2511243e93853c8e8b4b63b10153f028);
        run_one(128'h00000000000000000000000000000080, 256'h8000000000000000000000000000000000000000000000000000000000000001, 128'h24985dbdad265bb8f343877a07e4b2b2);
        run_one(128'hfedcba98765432100123456789abcdef, 256'h1234567890abcdef1234567890abcdef0f1e2d3c4b5a69788796a5b4c3d2e1f0, 128'h46c673f176327859efe3cac9a58332f3);

        if (errors == 0) $display("ALL %0d DYNAMIC-KEY STRESS VECTORS PASSED", passed);
        else             $display("DYNAMIC-KEY STRESS FAILED: %0d errors", errors);
        $finish;
    end
endmodule
