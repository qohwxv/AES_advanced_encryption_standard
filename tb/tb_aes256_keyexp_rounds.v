`timescale 1ns/1ps

// Unit test for the sequential AES-256 key-expansion primitive.
module tb_aes256_keyexp_rounds;
    reg [127:0] prev_key;
    reg [127:0] curr_key;
    reg         even_step;
    reg [7:0]   rcon;
    wire [127:0] next_key;
    integer errors;

    aes256_keyexp_step dut (
        .prev_key(prev_key), .curr_key(curr_key), .even_step(even_step),
        .rcon(rcon), .next_key(next_key)
    );

    task check_step;
        input expected_even;
        input [7:0] expected_rcon;
        input [127:0] expected_key;
        begin
            even_step = expected_even;
            rcon = expected_rcon;
            #1;
            if (next_key !== expected_key) begin
                $display("[FAIL] key expansion: expected %032h, got %032h", expected_key, next_key);
                errors = errors + 1;
            end else begin
                $display("[PASS] round key = %032h", next_key);
            end
            prev_key = curr_key;
            curr_key = next_key;
        end
    endtask

    initial begin
        $dumpfile("tb_aes256_keyexp_rounds.vcd");
        $dumpvars(0, tb_aes256_keyexp_rounds);
        errors = 0;
        prev_key = 128'h000102030405060708090a0b0c0d0e0f;
        curr_key = 128'h101112131415161718191a1b1c1d1e1f;

        // FIPS-197 AES-256 Appendix A.3, round keys 2 through 14.
        check_step(1'b1, 8'h01, 128'ha573c29fa176c498a97fce93a572c09c);
        check_step(1'b0, 8'h00, 128'h1651a8cd0244beda1a5da4c10640bade);
        check_step(1'b1, 8'h02, 128'hae87dff00ff11b68a68ed5fb03fc1567);
        check_step(1'b0, 8'h00, 128'h6de1f1486fa54f9275f8eb5373b8518d);
        check_step(1'b1, 8'h04, 128'hc656827fc9a799176f294cec6cd5598b);
        check_step(1'b0, 8'h00, 128'h3de23a75524775e727bf9eb45407cf39);
        check_step(1'b1, 8'h08, 128'h0bdc905fc27b0948ad5245a4c1871c2f);
        check_step(1'b0, 8'h00, 128'h45f5a66017b2d387300d4d33640a820a);
        check_step(1'b1, 8'h10, 128'h7ccff71cbeb4fe5413e6bbf0d261a7df);
        check_step(1'b0, 8'h00, 128'hf01afafee7a82979d7a5644ab3afe640);
        check_step(1'b1, 8'h20, 128'h2541fe719bf500258813bbd55a721c0a);
        check_step(1'b0, 8'h00, 128'h4e5a6699a9f24fe07e572baacdf8cdea);
        check_step(1'b1, 8'h40, 128'h24fc79ccbf0979e9371ac23c6d68de36);

        if (errors == 0) $display("ALL KEY-EXPANSION ROUND TESTS PASSED");
        else             $display("KEY-EXPANSION ROUND TESTS FAILED: %0d", errors);
        $finish;
    end
endmodule
