`timescale 1ns/1ps

module tb_aes256_pipeline_gap;

    parameter LATENCY = 15;

    reg          clk;
    reg          rst;        // active-low reset
    reg          start;
    reg  [127:0] plaintext;
    reg  [255:0] key;

    wire [127:0] ciphertext;
    wire         done;

    integer errors;
    integer edge_count;

    parameter [255:0] K_COMMON =
        256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;

    parameter [127:0] PT_A =
        128'h00112233445566778899aabbccddeeff;

    parameter [127:0] CT_A_EXPECTED =
        128'hd83414223d20a0c928b136c884d07ea2;

    parameter [127:0] PT_B =
        128'hffeeddccbbaa99887766554433221100;

    parameter [127:0] CT_B_EXPECTED =
        128'h576436b0ed2a75ef808213d478aa53c1;

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
            rst        = 1'b0;
            start      = 1'b0;
            plaintext  = 128'd0;
            key        = 256'd0;
            edge_count = 0;

            repeat (3) @(posedge clk);
            #1;
            rst = 1'b1;

            repeat (1) @(posedge clk);
            #1;
        end
    endtask

    task check_done_low;
        input integer edge_id;
        begin
            if (done !== 1'b0) begin
                $display("[FAIL] Edge %0d: done should be LOW, got %b", edge_id, done);
                errors = errors + 1;
            end else begin
                $display("[OK]   Edge %0d: done LOW", edge_id);
            end
        end
    endtask

    task check_done_high;
        input integer edge_id;
        input [127:0] expected_ct;
        input [511:0] label;
        begin
            if (done !== 1'b1) begin
                $display("[FAIL] Edge %0d: done should be HIGH for %0s", edge_id, label);
                errors = errors + 1;
            end

            if (ciphertext !== expected_ct) begin
                $display("[FAIL] Edge %0d: wrong ciphertext for %0s", edge_id, label);
                $display("       expected = %032h", expected_ct);
                $display("       got      = %032h", ciphertext);
                errors = errors + 1;
            end else begin
                $display("[PASS] Edge %0d: %0s ciphertext = %032h", edge_id, label, ciphertext);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_aes256_pipeline_gap.vcd");
        $dumpvars(0, tb_aes256_pipeline_gap);

        errors = 0;

        reset_dut();

        // Keep key constant while two plaintext blocks are inside pipeline.
        key = K_COMMON;

        // ============================================================
        // EDGE 1: first input
        // ============================================================
        @(negedge clk);
        plaintext = PT_A;
        start     = 1'b1;

        @(posedge clk);
        #1;
        edge_count = 1;
        $display("[INPUT] Edge 1: accepted block A");
        check_done_low(edge_count);

        start     = 1'b0;
        plaintext = 128'd0;

        // ============================================================
        // EDGE 2: no input
        // ============================================================
        @(posedge clk);
        #1;
        edge_count = 2;
        $display("[IDLE ] Edge 2: no input");
        check_done_low(edge_count);

        // ============================================================
        // EDGE 3: no input
        // ============================================================
        @(posedge clk);
        #1;
        edge_count = 3;
        $display("[IDLE ] Edge 3: no input");
        check_done_low(edge_count);

        // ============================================================
        // EDGE 4: no input
        // ============================================================
        @(posedge clk);
        #1;
        edge_count = 4;
        $display("[IDLE ] Edge 4: no input");
        check_done_low(edge_count);

        // ============================================================
        // EDGE 5: second input
        // ============================================================
        plaintext = PT_B;
        start     = 1'b1;

        @(posedge clk);
        #1;
        edge_count = 5;
        $display("[INPUT] Edge 5: accepted block B");
        check_done_low(edge_count);

        start     = 1'b0;
        plaintext = 128'd0;

        // ============================================================
        // EDGE 6 to EDGE 14: no valid output yet
        // ============================================================
        repeat (9) begin
            @(posedge clk);
            #1;
            edge_count = edge_count + 1;
            check_done_low(edge_count);
        end

        // ============================================================
        // EDGE 15: output for block A
        // ============================================================
        @(posedge clk);
        #1;
        edge_count = 15;
        check_done_high(edge_count, CT_A_EXPECTED, "BLOCK_A");

        // ============================================================
        // EDGE 16, 17, 18: gap
        // ============================================================
        @(posedge clk);
        #1;
        edge_count = 16;
        check_done_low(edge_count);

        @(posedge clk);
        #1;
        edge_count = 17;
        check_done_low(edge_count);

        @(posedge clk);
        #1;
        edge_count = 18;
        check_done_low(edge_count);

        // ============================================================
        // EDGE 19: output for block B
        // ============================================================
        @(posedge clk);
        #1;
        edge_count = 19;
        check_done_high(edge_count, CT_B_EXPECTED, "BLOCK_B");

        if (errors == 0) begin
            $display("========================================");
            $display("PIPELINE GAP TEST PASSED");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("PIPELINE GAP TEST FAILED: %0d errors", errors);
            $display("========================================");
        end

        $finish;
    end

endmodule