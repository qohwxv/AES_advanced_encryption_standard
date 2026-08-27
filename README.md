# AES-256 Hardware Accelerator

Thiết kế AES-256 fully-pipelined bằng Verilog, mô phỏng trên Icarus Verilog & GTKWave.

---

## Đặc điểm

- **Chuẩn**: AES-256 (FIPS 197)
- **Kiến trúc**: Pipeline 15 stage (1 block/cycle throughput)
- **Độ trễ**: 15 chu kỳ clock
- **Key**: 256-bit → 15 round keys (Key Schedule combinational)

Ngoài core pipeline nguyên bản (`aes_top`), project có core mới
`aes256_iterative_dynamic_key`: mỗi transaction nhận key riêng, key expansion
sinh đúng một round-key cho mỗi clock đang mã hóa. Core này có độ trễ 15 clock
và throughput một block mỗi 15 clock.

---

## Cấu trúc file

| File | Mô tả |
|---|---|
| `src/aes_top.v` | Top-level, pipeline 15 stage |
| `src/aes_keyschedule.v` | Key expansion 256-bit |
| `src/aes_subbytes.v` | SubBytes |
| `src/aes_shiftrows.v` | ShiftRows |
| `src/aes_mixcolumns.v` | MixColumns |
| `src/aes_sbox.v` | S-Box lookup table |
| `tb/tb_aes256.v` | Testbench: 100 block liên tục |
| `tb/tb_aes256_pipeline_gap.v` | Testbench: pipeline có khoảng trống |
| `tb/tb_aes256_vector.v` | Testbench: vector kiểm tra chuẩn |
| `src/aes256_iterative_dynamic_key.v` | AES-256 iterative, key thay đổi theo transaction |
| `src/aes256_pipeline_dynamic_key.v` | Fully-pipelined dynamic-key, 1 block/clock |
| `src/aes256_keyexp_step.v` | Một bước key expansion, tạo một round-key |
| `tb/tb_aes256_keyexp_rounds.v` | Unit test từng round-key theo FIPS-197 |
| `tb/tb_aes256_dynamic_key.v` | FIPS KAT, key thay đổi, protocol và reset-abort |
| `tb/tb_aes256_dynamic_key_stress.v` | 8 vector OpenSSL độc lập, mỗi vector một key |
| `tb/tb_aes256_dynamic_100keys.v` | 100 transaction, 100 key khác nhau, so sánh golden từng block |
| `tb/tb_aes256_pipeline_dynamic_100keys.v` | 100 key khác nhau ở 100 clock liên tiếp, output pipeline liên tiếp |
| `tb/tb_aes256_pipeline_dynamic_100keys_log.v` | DUT-only log TB; Python kiểm golden ciphertext |
| `vivado_synth_dynamic_genesys_zu5ev.tcl` | Vivado synthesis/timing cho Genesys ZU-5EV |
| `vivado_create_project_genesys_zu5ev.tcl` | Tạo lại Vivado project `.xpr` |

---

## Chạy mô phỏng

```bash
# Compile
iverilog -g2005 -o sim src/aes_sbox.v src/aes_subbytes.v src/aes_shiftrows.v \
         src/aes_mixcolumns.v src/aes_keyschedule.v src/aes_top.v tb/tb_aes256_vector.v

# Chạy
vvp sim

# Xem dạng sóng
gtkwave tb_aes256_vectors.vcd
```

## Test core dynamic-key

```bash
# Unit test key expansion (FIPS-197 Appendix A.3)
iverilog -g2005 -o sim_keyexp src/aes_sbox.v src/aes256_keyexp_step.v tb/tb_aes256_keyexp_rounds.v
vvp sim_keyexp

# Integration test: FIPS KAT, thay key ở từng transaction, reset giữa chừng
iverilog -g2005 -o sim_dynamic src/aes_sbox.v src/aes_subbytes.v src/aes_shiftrows.v \
         src/aes_mixcolumns.v src/aes256_keyexp_step.v src/aes256_iterative_dynamic_key.v \
         tb/tb_aes256_dynamic_key.v
vvp sim_dynamic

# Stress: 8 vector AES-256-ECB độc lập, mỗi vector dùng key mới
iverilog -g2005 -o sim_stress src/aes_sbox.v src/aes_subbytes.v src/aes_shiftrows.v \
         src/aes_mixcolumns.v src/aes256_keyexp_step.v src/aes256_iterative_dynamic_key.v \
         tb/tb_aes256_dynamic_key_stress.v
vvp sim_stress

# 100 key khác nhau, kiểm từng ciphertext
iverilog -g2005 -o sim_100keys src/aes_sbox.v src/aes_subbytes.v src/aes_shiftrows.v \
         src/aes_mixcolumns.v src/aes_keyschedule.v src/aes_top.v \
         src/aes256_keyexp_step.v src/aes256_iterative_dynamic_key.v \
         tb/tb_aes256_dynamic_100keys.v
vvp sim_100keys

# Fully-pipelined dynamic-key: 100 key khác nhau ở 100 clock liên tiếp
iverilog -g2005 -o sim_pipeline_100keys src/aes_sbox.v src/aes_subbytes.v src/aes_shiftrows.v \
         src/aes_mixcolumns.v src/aes_keyschedule.v src/aes_top.v \
         src/aes256_keyexp_step.v src/aes256_pipeline_dynamic_key.v \
         tb/tb_aes256_pipeline_dynamic_100keys.v
vvp sim_pipeline_100keys

# DUT-only log test (reference độc lập bằng Python)
iverilog -g2005 -o sim_pipeline_100keys_log src/aes_sbox.v src/aes_subbytes.v src/aes_shiftrows.v \
         src/aes_mixcolumns.v src/aes256_keyexp_step.v src/aes256_pipeline_dynamic_key.v \
         tb/tb_aes256_pipeline_dynamic_100keys_log.v
vvp sim_pipeline_100keys_log > aes_sim.log
python3 tb/test_all_100.py aes_sim.log
```

## Vivado synthesis (Genesys ZU-5EV)

Sau khi nạp `settings64.sh`, chạy từ thư mục project:

```bash
vivado -mode batch -source vivado_synth_dynamic_genesys_zu5ev.tcl
```

Tạo project Vivado để mở GUI hoặc chọn testbench:

```bash
vivado -mode batch -source vivado_create_project_genesys_zu5ev.tcl
vivado vivado_aes256_genesys_zu5ev/aes256_genesys_zu5ev.xpr
```

Lệnh này synthesize core fully-pipelined dynamic-key mới và xuất báo cáo tài nguyên/timing; nó không
program board và không cần file `.xdc` vì top hiện tại chưa phải board wrapper.

---

## Công cụ

- **Icarus Verilog** v12+
- **GTKWave** 3.3+
- **Quartus Prime** (tổng hợp FPGA)
