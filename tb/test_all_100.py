#!/usr/bin/env python3

import argparse
import re
import shutil
import subprocess
import sys

try:
    from Crypto.Cipher import AES
except ImportError:
    AES = None

# Path to your testbench log output file
LOG_FILE = "aes_sim.log"


def encrypt_aes256_ecb(key_bytes, plaintext_bytes):
    """Use PyCryptodome when available, otherwise use the system OpenSSL CLI."""
    if AES is not None:
        return AES.new(key_bytes, AES.MODE_ECB).encrypt(plaintext_bytes)

    if shutil.which("openssl") is None:
        raise RuntimeError("neither PyCryptodome nor openssl is available")
    result = subprocess.run(
        ["openssl", "enc", "-aes-256-ecb", "-K", key_bytes.hex(),
         "-nopad", "-nosalt"],
        input=plaintext_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return result.stdout

def verify_all_vectors():
    # Regex to parse simulation log line format:
    # [RESULT] time=... output_sample=... input_sample=... block=... key=... plaintext=... ciphertext=...
    pattern = re.compile(
        r'\[(?:RESULT|PASS)\].*?block=(\d+).*?key=([0-9a-fA-F]+).*?plaintext=([0-9a-fA-F]+).*?ciphertext=([0-9a-fA-F]+)'
    )

    passed_count = 0
    failed_count = 0
    total_count = 0

    print("--- Verifying All AES-256 Simulation Vectors ---")
    
    seen_blocks = set()
    try:
        with open(LOG_FILE, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                match = pattern.search(line)
                if match:
                    total_count += 1
                    block_num = int(match.group(1))
                    try:
                        key_bytes = bytes.fromhex(match.group(2))
                        pt_bytes = bytes.fromhex(match.group(3))
                        expected_ct = bytes.fromhex(match.group(4))
                    except ValueError as exc:
                        print(f"[FAIL] Block {block_num}: invalid hex ({exc})")
                        failed_count += 1
                        continue

                    if block_num in seen_blocks:
                        print(f"[FAIL] Duplicate block {block_num} in log")
                        failed_count += 1
                        continue
                    seen_blocks.add(block_num)
                    if len(key_bytes) != 32 or len(pt_bytes) != 16 or len(expected_ct) != 16:
                        print(f"[FAIL] Block {block_num} has invalid field width")
                        failed_count += 1
                        continue

                    # Compute standard AES-256 ECB encryption independently.
                    try:
                        computed_ct = encrypt_aes256_ecb(key_bytes, pt_bytes)
                    except (RuntimeError, subprocess.SubprocessError) as exc:
                        print(f"ERROR: AES reference unavailable: {exc}")
                        return 2

                    if computed_ct == expected_ct:
                        passed_count += 1
                    else:
                        failed_count += 1
                        print(f"[FAIL] Block {block_num} mismatch!")
                        print(f"  Log Ciphertext:      {expected_ct.hex()}")
                        print(f"  Python Ciphertext:   {computed_ct.hex()}")

        print(f"\n--- Summary ---")
        print(f"Total Vectors Processed: {total_count}")
        print(f"Passed:                  {passed_count}")
        print(f"Failed:                  {failed_count}")
        
        if total_count == 100 and failed_count == 0 and seen_blocks == set(range(100)):
            print("\nSUCCESS: All 100 dynamic key test vectors match standard AES-256 output!")
            return 0
        print("\nFAILURE: expected exactly 100 unique blocks (0..99) with no mismatches")
        return 1

    except FileNotFoundError:
        print(f"ERROR: Could not find '{LOG_FILE}'. Pass the log path as an argument.")
        return 2

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Verify AES-256 DUT log against PyCryptodome")
    parser.add_argument("log_file", nargs="?", default=LOG_FILE)
    args = parser.parse_args()
    LOG_FILE = args.log_file
    sys.exit(verify_all_vectors())
