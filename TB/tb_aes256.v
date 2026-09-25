`timescale 1ns/1ps

module tb_aes256();
    reg clk;
    reg rst;
    reg start;
    reg [255:0] key;
    reg [127:0] plaintext;

    wire [127:0] ciphertext;
    wire done;

    // Cac bien dieu khien va dem chu ky
    integer cycle = 0;
    integer i = 0;
    integer cnt_internal = 0; // Bien dem an chay theo chu ky thuc (hardware)
    integer cnt_out = 0;      // Bien hien thi, cap nhat tuc thoi theo tin hieu 'done'
    
    // Ma Hex chuan cua chuoi: "leminhnghiavatranquochungce213q2" (Dung 256 bits)
    localparam [255:0] MY_AES_KEY = 256'h6c656d696e686e6768696176617472616e71756f6368756e6763653231337132;

    // Instantiate DUT (Device Under Test)
    aes_top dut(
        .clk(clk),
        .rst(rst),
        .plaintext(plaintext),
        .start(start),
        .key(key),
        .ciphertext(ciphertext),
        .done(done)
    );

    // ==================== Generation Xung Nhip (Chu ky 20ns) ====================
    initial begin
        clk = 0;
        // #10 lat trang thai 1 lan => 1 chu ky = 20ns (10ns HIGH, 10ns LOW)
        forever #10 clk = ~clk; 
    end

    // ==================== Tien Trinh Dem Chu Ky He Thong ====================
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end

    // ==================== Tien Trinh Dem So Luong Ket Qua Tra Ve ====================
    // 1. Bien dem noi bo chuan dong bo
    always @(posedge clk) begin
        if (rst == 1'b0) begin
            cnt_internal <= 0;
        end else if (done) begin
            cnt_internal <= cnt_internal + 1;
        end
    end

    // 2. Cap nhat tuc thoi (Combinational) cho bien cnt_out ngay khi done = 1
    always @(*) begin
        if (rst == 1'b0) begin
            cnt_out = 0;
        end else begin
            // Neu done=1, nay so ngay lap tuc. Neu khong, giu nguyen gia tri cu.
            cnt_out = (done) ? (cnt_internal + 1) : cnt_internal;
        end
    end

    // ==================== Kich Ban Kiem Tra Chinh (Main Sequence) ====================
    initial begin
        $display("====================================================");
        $display("   AES-256 PIPELINE TESTBENCH  ");
        $display("====================================================");

        // Khoi tao cac gia tri ban dau tai thoi diem 0
        plaintext = 128'h0;
        key       = MY_AES_KEY;
        start     = 0;
        
        // -----------------------------------------------------------------
        // Trinh tu Reset: Giu tich cuc muc thap (Active-Low) trong 2 chu ky dau
        // -----------------------------------------------------------------
        rst = 0;         
        #40;             // Doi het 2 chu ky dau tien (2 * 20ns = 40ns)
        
        @(negedge clk);  // Dong bo du lieu tai suon xuong de an toan Timing
        rst   = 1;       // Nha Reset
        start = 1;       // Kich hoat tin hieu Start lien tuc cho che do Pipeline

        // -----------------------------------------------------------------
        // Tien trinh nap lien tuc 100 Plaintext (Tu 1 den 100)
        // -----------------------------------------------------------------
        $display("\n[INFO] Bat dau nap lien tuc 100 Plaintext vao duong ong...");
        for (i = 1; i <= 100; i = i + 1) begin
            plaintext = i; 
            @(negedge clk);       // Cho het chu ky hien tai de nap block tiep theo
        end

        // Sau khi nap du 100 block, tat tin hieu start va ha plaintext
        start     = 0;
        plaintext = 128'h0;
        $display("[INFO] Da nap xong du lieu (i = 100). Cho duong ong xa ket qua...");

        // -----------------------------------------------------------------
        // Doi tu dong cho den khi nhan du 100 khoi dau ra
        // -----------------------------------------------------------------
        while (cnt_out < 100) begin
            @(posedge clk);
        end

        #2; // Tre nhe 2ns sau canh clock cuoi cung de hien thi log dep mat
        $display("\n====================================================");
        $display(" HOAN THANH MO PHONG!");
        $display(" Tong so khoi du lieu da nap: 100");
        $display(" Tong so khoi ket qua thu ve (cnt_out): %d", cnt_out);
        $display(" Tong so chu ky tieu ton: %d", cycle);
        $display("====================================================");
        #1000;
        $finish;
    end

    // ==================== Bo Giam Sat Dau Ra (Monitor) ====================
    always @(posedge clk) begin
        if (done) begin
            // Su dung truc tiep cnt_out vi no da duoc cap nhat so dung ngay tuc thi
            $display("Cycle: %4d | DONE=1 | Khoi: %3d | Plaintext = %0h | Ciphertext = %h", 
                     cycle, cnt_out, cnt_out, ciphertext);
        end
    end

    // ==================== Xuat File Song De Xem Tren ModelSim/GTKWave ====================
    initial begin
        $dumpfile("aes256_pipeline_100blocks.vcd");
        $dumpvars(0, tb_aes256);
    end

endmodule