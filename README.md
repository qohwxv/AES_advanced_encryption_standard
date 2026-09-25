# AES-256 Dynamic-Key Fully Pipelined Hardware Core

This project implements AES-256 encryption in synthesizable Verilog for FPGA targets. The primary design is a 15-stage fully pipelined core in which both the data state and the AES-256 key schedule travel through the pipeline. As a result, the core can accept a new 128-bit plaintext block with a different 256-bit key on every clock cycle.

<img width="1139" height="276" alt="AES-256 pipeline architecture" src="https://github.com/user-attachments/assets/ac62d61a-16c4-4949-8730-223bc80bfa53" />

## Key Features

- **Algorithm:** AES-256 encryption as defined by FIPS 197.
- **Block size:** 128 bits.
- **Key size:** 256 bits.
- **Rounds:** Initial AddRoundKey followed by 14 AES rounds.
- **Architecture:** 15 registered pipeline stages.
- **Dynamic key support:** Every accepted block may use a different 256-bit key.
- **Throughput:** One 128-bit block per clock after the pipeline is filled.
- **Handshake:** `in_valid`, constant-high `in_ready`, and `out_valid`.
- **Reset:** Active-low asynchronous reset (`rst_n`).

The primary synthesis top is:

```text
aes256_pipeline_dynamic_key
```

The primary simulation top is:

```text
tb_aes256_pipeline_dynamic_100keys_log
```

## Pipeline Operation

Stage 0 performs the initial AddRoundKey operation. Stages 1 through 13 perform the normal AES transformations:

```text
SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
```

Stage 14 performs the final AES round without MixColumns:

```text
SubBytes -> ShiftRows -> AddRoundKey
```

The AES-256 round keys are generated progressively by `aes256_keyexp_step` and registered alongside the associated data block. The testbench counts the input acceptance edge as sample 1 and observes the corresponding output at sample 15.

## Core Modules

| File | Module | Description |
|:---|:---|:---|
| `src/aes_sbox.v` | `aes_sbox` | AES S-box lookup table with 256 entries |
| `src/aes_subbytes.v` | `aes_subbytes` | Applies the S-box to all 16 state bytes |
| `src/aes_shiftrows.v` | `aes_shiftrows` | AES ShiftRows transformation |
| `src/aes_mixcolumns.v` | `aes_mixcolumns` | AES MixColumns transformation |
| `src/aes256_keyexp_step.v` | `aes256_keyexp_step` | Generates the next 128-bit AES-256 round key |
| `src/aes256_pipeline_dynamic_key.v` | `aes256_pipeline_dynamic_key` | Primary dynamic-key, fully pipelined AES-256 core |
| `src/dynamic_core_clock.xdc` | -- | 20 ns (50 MHz) clock constraint for the standalone core |

## Legacy Modules

| File | Module | Description |
|:---|:---|:---|
| `src/aes_keyschedule.v` | `aes256_keyschedule` | Combinational generation of all 15 round keys |
| `src/aes_top.v` | `aes_top` | Earlier 15-stage pipeline intended for a key held constant while data is in flight |

`aes_top` is retained for legacy tests and fixed-key operation. It must not be used for per-cycle dynamic keys because its round keys are shared across all pipeline stages. New designs should use `aes256_pipeline_dynamic_key`.

## Testbenches

| File | Purpose |
|:---|:---|
| `tb/tb_aes256_keyexp_rounds.v` | Checks round keys 2 through 14 against the FIPS 197 AES-256 key schedule |
| `tb/tb_aes256_pipeline_dynamic_100keys_log.v` | Sends 100 different plaintext/key pairs on consecutive clocks and logs all results |
| `tb/test_all_100.py` | Independently verifies the 100 logged ciphertexts using PyCryptodome or OpenSSL |
| `tb/tb_aes256_vector.v` | Checks the legacy core against four known AES-256 ciphertexts |
| `tb/tb_aes256_pipeline_gap.v` | Checks valid-data gaps in the legacy pipeline |
| `tb/tb_aes256.v` | Demonstrates continuous processing of 100 blocks with a fixed key |

## Verified Results

The current design has been tested with Icarus Verilog and Vivado XSim. The Vivado XSim log was independently checked by `tb/test_all_100.py`.

| Test | Result |
|:---|:---|
| AES-256 key-expansion round test | Passed all round keys |
| Known-answer AES-256 vector test | Passed 4/4 vectors |
| Fixed-key pipeline gap test | Passed |
| Dynamic-key continuous pipeline test | Produced 100/100 outputs |
| Independent PyCryptodome/OpenSSL verification | Passed 100/100 ciphertexts |

The 100-vector test changes both the plaintext and the 256-bit key on every input clock. All outputs matched an independent software AES-256 implementation.

## Current Synthesis Results

Synthesis was performed with Vivado 2023.2 using:

```text
Target device: xcvu29p-fsga2577-2L-e
Board family:  VCU129
Clock constraint: 20 ns (50 MHz)
```

Post-synthesis resource usage:

| Resource | Used | Device utilization |
|:---|---:|---:|
| CLB LUTs | 13,145 | 0.76% |
| CLB registers | 5,391 | 0.16% |
| F7 multiplexers | 4,288 | 0.50% |
| F8 multiplexers | 2,080 | 0.48% |
| Block RAM | 0 | 0% |

Post-synthesis setup timing at the 50 MHz constraint reported:

```text
WNS = +18.786 ns
TNS =   0.000 ns
```

At 50 MHz, the theoretical streaming throughput is:

```text
128 bits x 50 MHz = 6.4 Gbit/s
```

This is a constraint-based throughput value, not a verified maximum operating frequency. A valid Fmax must be obtained from a successful post-route implementation.


## Environment

- **RTL:** Verilog
- **Simulation:** Vivado XSim and Icarus Verilog
- **Independent reference:** PyCryptodome or OpenSSL AES-256-ECB
- **Synthesis:** AMD/Xilinx Vivado 2023.2
- **Current FPGA target:** `xcvu29p-fsga2577-2L-e`

## Project Structure

```text
AES_256_main/
|-- src/                         # Synthesizable AES RTL and clock constraint
|-- tb/                          # Verilog testbenches and Python verifier
|-- reports/                     # Generated timing/resource reports
|-- vivado_synth/AES_encryption/ # Vivado project and generated run data
`-- README.md
```

## Scope

This repository implements the AES-256 encryption primitive. It does not currently provide AES decryption, padding, authentication, or higher-level modes such as CBC, CTR, or GCM.
