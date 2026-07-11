`timescale 1ns/1ps

module tb_aes256_vectors;

    parameter LATENCY = 15;

    reg          clk;
    reg          rst;        // active-low reset
    reg          start;
    reg  [127:0] plaintext;
    reg  [255:0] key;

    wire [127:0] ciphertext;
    wire         done;

    integer errors;

    aes_top dut (
        .clk        (clk),
        .rst        (rst),
        .plaintext  (plaintext),
        .key        (key),
        .start      (start),
        .ciphertext (ciphertext),
        .done       (done)
    );

    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;

    task reset_dut;
        begin
            rst       = 1'b0;
            start     = 1'b0;
            plaintext = 128'd0;
            key       = 256'd0;

            repeat (3) @(posedge clk);
            #1;
            rst = 1'b1;

            repeat (1) @(posedge clk);
            #1;
        end
    endtask

    task run_one;
        input [511:0] test_name;
        input [127:0] pt;
        input [255:0] k;
        input [127:0] expected_ct;

        integer i;

        begin
            reset_dut();

            key = k;

            @(negedge clk);
            plaintext = pt;
            start     = 1'b1;

            @(posedge clk);
            #1;

            if (done !== 1'b0) begin
                $display("[FAIL] %0s: done asserted too early at cycle 1", test_name);
                errors = errors + 1;
            end

            start     = 1'b0;
            plaintext = 128'd0;

            for (i = 2; i < LATENCY; i = i + 1) begin
                @(posedge clk);
                #1;

                if (done !== 1'b0) begin
                    $display("[FAIL] %0s: done asserted too early at cycle %0d", test_name, i);
                    errors = errors + 1;
                end
            end

            @(posedge clk);
            #1;

            if (done !== 1'b1) begin
                $display("[FAIL] %0s: done not asserted at expected cycle %0d", test_name, LATENCY);
                errors = errors + 1;
            end

            if (ciphertext !== expected_ct) begin
                $display("[FAIL] %0s", test_name);
                $display("       plaintext  = %032h", pt);
                $display("       key        = %064h", k);
                $display("       expected   = %032h", expected_ct);
                $display("       got        = %032h", ciphertext);
                errors = errors + 1;
            end else begin
                $display("[PASS] %0s : ciphertext = %032h", test_name, ciphertext);
            end

            @(posedge clk);
            #1;

            if (done !== 1'b0) begin
                $display("[FAIL] %0s: done should return LOW after one-cycle pulse", test_name);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_aes256_vectors.vcd");
        $dumpvars(0, tb_aes256_vectors);

        errors = 0;

        // Test 1: plaintext = 128'd0, random key
        run_one(
            "PT_128d0_RANDOM_KEY",
            128'h7472756F6E67646169686F63636E7474,
            256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4,
            128'he568f68194cf76d6174d4cc04310a854
        );

        // Test 2: plaintext = 128'd1, random key
        run_one(
            "PT_128d1_RANDOM_KEY",
            128'd1,
            256'hc47b029dbbbee0f2ec4757f22ffeee35f13a2f829bb43a86b9f7d7e6791b8ad5,
            128'h564e771151065a78f84e2852715266d1
        );

        // Test 3: random plaintext, key = 0
        run_one(
            "RANDOM_PT_KEY_256d0",
            128'h0123456789abcdeffedcba9876543210,
            256'd0,
            128'h7b859fbee6b2d8ba17fcf0dd102d863a
        );

        // Test 4: random plaintext, key = 1
        run_one(
            "RANDOM_PT_KEY_256d1",
            128'hf0e1d2c3b4a5968778695a4b3c2d1e0f,
            256'd1,
            128'hf4971f5c266dc99d87296d9c67d13b46
        );

        if (errors == 0) begin
            $display("========================================");
            $display("ALL AES-256 VECTOR TESTS PASSED");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("AES-256 VECTOR TESTS FAILED: %0d errors", errors);
            $display("========================================");
        end

        $finish;
    end

endmodule
