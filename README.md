# Project Summary: Implementation of AES-256 with Pipeline Architecture
This project focuses on the research, design, and simulation of the AES-256 encryption algorithm on digital hardware platforms (FPGA), using the Verilog language to optimize performance through Pipeline techniques.
<img width="1139" height="276" alt="image" src="https://github.com/user-attachments/assets/ac62d61a-16c4-4949-8730-223bc80bfa53" />


## Key Features:
- Algorithm: Implemented AES-256 (256-bit key, 14 processing rounds) based on the Substitution-Permutation Network (SPN) model.

- Architecture: Utilized Full Pipelining by dividing the computational process into multiple logic stages, allowing for continuous data processing and increased throughput.

## Core Modules:

- SubBytes: Non-linear transformation (S-box).

- ShiftRows & MixColumns: Data diffusion transformations.

- Key Expansion: Expansion of the 256-bit key into 15 round keys.

- AddRoundKey: XOR operation between data and round keys.

## Environment:

- Simulation: Used ModelSim to verify the design's accuracy.

- Synthesis: Used Quartus II to evaluate hardware resources (LUTs, Registers) and operating frequency (Fmax) on FPGA.

## Result:
- Accuracy: Verified against all NIST standard test vectors for AES-256.

- Operating Frequency (Fmax): 67.77 MHz.

- Throughput: 8.67 Gbps.

- Latency: 15 clock cycles.

- Limitations: The cipher key is static during the encryption phase and cannot be updated dynamically while the pipeline is active.

# File structure 
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

This project was conducted as part of the HDL Digital System Design course at the University of Information Technology (UIT).

