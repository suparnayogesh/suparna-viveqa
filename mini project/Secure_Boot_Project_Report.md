# FPGA-Based Mini Secure Boot System Using SHA-256 Integrity Verification

**Platform:** AT-STLN-ARTIX7-001 (Xilinx XC7A35T-FTG256-1 Artix-7 FPGA), Anmaya Technologies
**Co-processor:** ESP32-C3-MINI-1
**Hash Core:** secworks/sha256 (open-source, BSD-licensed Verilog SHA-256 core)

---

## 1. Abstract

This project implements a simplified **secure boot** mechanism on an FPGA development board to demonstrate the fundamental principle of firmware integrity verification: a system should check that firmware has not been altered before it is trusted or executed. A known "firmware image" is transmitted from an onboard ESP32-C3 microcontroller to the FPGA over a UART link. The FPGA independently computes the SHA-256 cryptographic hash of the received data using a dedicated hardware SHA-256 core, compares it against a pre-stored reference hash, and reports the result — PASS or FAIL — on a 16×2 character LCD and status LEDs. A single-bit change anywhere in the firmware image is sufficient to produce a completely different hash and trigger a FAIL indication, illustrating the avalanche property of cryptographic hash functions and its use in tamper detection.

---

## 2. Objectives

- Demonstrate the core principle of secure boot — *verify before you trust* — on real FPGA hardware.
- Integrate a third-party, open-source cryptographic IP core (SHA-256) into a custom Verilog design.
- Establish a reliable communication link between two separate processors on the same board (ESP32-C3 and the FPGA) over UART.
- Provide clear, human-readable pass/fail feedback via an LCD and LEDs, suitable for a live demonstration.
- Understand and work around real-world hardware/firmware issues (UART framing, competing bus traffic, board-level constraints) that arise when integrating independently-designed subsystems.

---

## 3. System Architecture

```
 ┌────────────────────┐        UART (115200, 8N1)        ┌─────────────────────────────┐
 │   ESP32-C3-MINI-1   │ ───────────────────────────────► │        Artix-7 FPGA         │
 │  (firmware source)  │   0xAA 0x55 + 32 firmware bytes  │  (verifier / secure boot)   │
 └────────────────────┘                                   │                              │
                                                            │  UART RX → Sync Detect       │
                                                            │      → SHA-256 Core          │
                                                            │      → Compare vs Reference  │
                                                            │      → LCD + LED status      │
                                                            └─────────────────────────────┘
```

The ESP32-C3 plays the role of an untrusted "firmware delivery" channel — analogous to an external flash chip, network update, or removable storage in a real embedded system. The FPGA plays the role of a **root of trust**: it independently recomputes the hash of whatever it receives and only reports "PASS" if that hash matches a value that was fixed into the FPGA's own bitstream at build time (i.e., established through a trusted channel — the Vivado toolchain — rather than being sent alongside the firmware itself, which would defeat the purpose).

---

## 4. Hardware Components Used

| Component | Part | Role |
|---|---|---|
| FPGA | Xilinx XC7A35T-FTG256-1 (Artix-7) | Runs the verifier logic and SHA-256 core |
| Co-processor | ESP32-C3-MINI-1 | Sends the firmware image over UART |
| Display | 16×2 character LCD (DS1WC1602A) | Shows live status text |
| LEDs | 2 of the 16 onboard user LEDs | PASS / FAIL / BUSY indicators |
| Programming | FT232H (USB-JTAG) for FPGA, native USB-CDC for ESP32-C3 | Independent programming paths |
| Interconnect | 1 jumper wire (PMOD ↔ ESP32 header) | UART signal path between the two chips |

Note: ground is shared implicitly through the common PCB ground plane — no separate ground jumper was required since both chips reside on the same board.

---

## 5. Software / Firmware Components

### 5.1 ESP32-C3 (Arduino/C++)
- Runs on the ESP32's own hardware UART0 (GPIO20/21), independent of its USB-CDC serial monitor link.
- On command (`n` or `t` typed into the Serial Monitor), transmits:
  1. A 2-byte **sync header** (`0xAA 0x55`)
  2. 32 bytes representing a fixed "firmware image" — either the genuine trusted image, or a 1-bit-tampered version, used to demonstrate both outcomes.

### 5.2 FPGA (Verilog, Vivado)

| Module | Purpose |
|---|---|
| `uart_rx.v` | Custom 8N1 UART receiver (115200 baud @ 24 MHz system clock) |
| `secure_boot_top.v` | Top-level FSM: sync detection, byte buffering, SHA-256 block construction, result comparison, LCD/LED control |
| `lcd_display.v` | HD44780-compatible LCD driver with 4 switchable status messages |
| `sha256_core.v`, `sha256_k_constants.v`, `sha256_w_mem.v` | Third-party open-source SHA-256 hardware core ([secworks/sha256](https://github.com/secworks/sha256)) — computes the actual hash in hardware |

---

## 6. Working Principle

1. **Idle / Sync wait** — the FPGA continuously monitors its UART input, discarding any incoming byte until it sees the exact 2-byte sequence `0xAA 0x55`. This sync header exists specifically to make the link robust against unrelated traffic on the same wire (see §8, Design Challenges).
2. **Firmware reception** — once synced, the next 32 bytes are captured into an internal buffer, one byte per UART frame.
3. **SHA-256 block construction** — the 32 received bytes (256 bits) are packed into a single 512-bit SHA-256 message block, with the standard Merlin-Damgård padding applied in hardware: an `0x80` byte marking the end of the message, zero-padding, and a 64-bit big-endian bit-length field, per FIPS 180-4.
4. **Hashing** — the block is fed to the `sha256_core`, which computes the 256-bit digest over 64 internal compression rounds.
5. **Comparison** — the computed digest is compared, bit-for-bit, against a 256-bit `REFERENCE_HASH` constant that was computed offline (via `sha256sum`) from the known-good firmware and embedded directly into the FPGA's Verilog source at build time.
6. **Result reporting**
   - **Match →** LED_PASS lights, LCD displays "PASS - FW OK".
   - **Mismatch →** LED_FAIL lights, LCD displays "FAIL - TAMPERED".
7. After a short hold period, the system returns to step 1, ready to verify another transmission.

---

## 7. Why This Demonstrates "Secure Boot"

Real secure boot implementations (e.g., in modern SoCs, TPM-backed PCs, or signed bootloaders) follow the same core pattern shown here, scaled up with cryptographic authenticity rather than plain integrity:

1. A reference value (hash, or in production systems, a public key / certificate) is fixed into trusted, hard-to-modify storage at manufacture time.
2. Before code/firmware is trusted or executed, its hash is independently recomputed by hardware or an immutable first-stage bootloader.
3. Any mismatch — even a single altered bit — halts the boot process instead of running potentially malicious code.

This project reproduces steps 1–3 faithfully, using SHA-256 for integrity checking. It intentionally does **not** implement full production-grade secure boot; see §9 for the specific gaps.

---

## 8. Design Challenges Encountered and Solutions

This section documents real issues encountered during development — useful both for understanding the design and for a viva/demo Q&A.

| Issue | Root Cause | Fix |
|---|---|---|
| Hash always failed, for both genuine and tampered firmware | A transcription error in the `REFERENCE_HASH` constant (2 hex digits truncated) | Recomputed and corrected the constant against `sha256sum` output |
| Digest computed but never matched, even after the hash fix | ESP32 boot-log messages are also transmitted over UART0 — the same physical pins used for the FPGA link — causing the FPGA to lock onto boot noise instead of the real payload whenever both chips were reset together | Added a 2-byte `0xAA 0x55` **sync header**, sent immediately before every firmware transmission; the FPGA ignores everything until it sees this exact sequence, which is statistically very unlikely to appear in printable ASCII boot text |
| Uncertainty around third-party IP core's exact port names/polarity | The `sha256_core` interface was integrated from documentation/memory before hardware testing | Verified the actual `sha256_core.v` and `sha256_w_mem.v` source directly against the GitHub repository to confirm port names, `mode` polarity, and block/padding byte order before debugging further |

The debugging approach used — instrumenting intermediate signals (raw received byte, first byte of digest) directly onto the LEDs — is a general and reusable FPGA debugging technique when no logic analyzer or ILA is set up, and is documented here as part of the project methodology.

---

## 9. Scope and Limitations

This is an educational demonstration, not a production secure-boot implementation. Known simplifications:

- **Fixed 32-byte message size.** Only a single SHA-256 block is supported; a production system would need to handle arbitrary-length firmware images across multiple blocks.
- **Integrity only, not authenticity.** SHA-256 alone proves the data wasn't accidentally or maliciously altered *relative to what the hash was computed over* — but an attacker who can also replace the reference hash (or who controls both the firmware and can recompute a new valid hash) is not stopped by a hash alone. Production secure boot uses **signed** firmware (RSA/ECDSA) or a keyed MAC (HMAC), verified against a public key or secret that the attacker cannot forge.
- **No protection of the reference value itself.** In this demo, `REFERENCE_HASH` lives in the FPGA bitstream, which is reasonably difficult to tamper with in isolation, but there's no additional write-protection, secure element, or fused key storage as would be used in a real root-of-trust design.
- **The firmware is never actually executed.** This project verifies data integrity; it does not gate or control the loading/execution of real, running program code.

---

## 10. Applications and Educational Value

- **Hardware security education** — a compact, hands-on illustration of a concept (secure boot / chain of trust) usually only discussed abstractly in coursework.
- **Cryptographic hash function demonstration** — visibly shows the avalanche effect: flipping a single bit of input produces a completely unrelated output hash.
- **IP core integration practice** — realistic experience integrating a third-party open-source hardware module (not written from scratch) into a larger Verilog design, including reading unfamiliar interface documentation and verifying assumptions against source code.
- **Multi-processor system design** — demonstrates coordinating two independent processors (FPGA + microcontroller) over a shared physical interface, including handling real-world signal contention.
- **Extendable base** — the same architecture generalizes toward more advanced secure-boot concepts: HMAC/signature-based authenticity, multi-block hashing for arbitrary firmware sizes, SD-card-based firmware sourcing, and anti-rollback counters.

---

## 11. Conclusion

The project successfully demonstrates a working, hardware-verified integrity check: firmware transmitted from an ESP32-C3 to an FPGA is independently hashed in dedicated SHA-256 hardware logic, compared against a trusted reference value, and reported via LCD and LED indicators — correctly distinguishing genuine firmware (PASS) from tampered firmware (FAIL) with single-bit sensitivity. Beyond the core cryptographic demonstration, the project also involved practical systems-integration debugging — a UART framing/contention issue between two chips sharing pins — which was diagnosed methodically using LED-based hardware instrumentation and resolved with a synchronization header, reflecting real engineering practice in embedded systems bring-up.

---

## 12. References

1. AT-STLN-ARTIX7-001 Hardware Reference Manual, Anmaya Technologies, ANM-PRD-2025-005 Rev 1.0.
2. secworks/sha256 — open-source Verilog SHA-256 core. https://github.com/secworks/sha256
3. FIPS PUB 180-4, *Secure Hash Standard (SHS)*, National Institute of Standards and Technology.
4. Xilinx 7 Series FPGAs Configuration User Guide (UG470).
