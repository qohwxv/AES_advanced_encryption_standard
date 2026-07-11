# AES_advanced_encryption_standard-
This AES project will perform pipeline 
| File                     | Module                 | Description                                       |
|:-------------------------|:-----------------------|:--------------------------------------------------|
| aes_sbox.v               | aes_sbox               | S-Box lookup table (256 entries)                  |
| aes_subbytes.v           | aes_subbytes           | SubBytes: applies S-Box to 16 bytes               |
| aes_shiftrows.v          | aes_shiftrows          | ShiftRows transformation                          |
| aes_mixcolumns.v         | aes_mixcolumns         | MixColumns transformation                         |
| aes_keyschedule.v        | aes256_keyschedule     | Key expansion: 256-bit to 15 round keys           |
| aes_top.v                | aes_top                | Top-level: 15-stage pipeline implementation       |
| tb_aes256.v              | tb_aes256              | Testbench: processing 100 blocks continuously     |
| tb_aes256_pipeline_gap.v | tb_aes256_pipeline_gap | Testbench: verifies pipeline gaps/stalls          |
| tb_aes256_vector.v       | tb_aes256_vectors      | Testbench: verifies against NIST standard vectors |
