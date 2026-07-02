// ============================================================
// secure_boot_top.v
// Mini Secure-Boot demo for AT-STLN-ARTIX7-001
//
// Flow:
//   1. Wait for 32 bytes of "firmware" over UART (from ESP32-C3)
//   2. Pack them into a single 512-bit SHA-256 block (manual
//      padding since the message length is fixed/known)
//   3. Feed the block to secworks' sha256_core
//   4. Compare the resulting digest to a hardcoded reference hash
//   5. Drive LED_PASS / LED_FAIL, show PASS/FAIL on the 16x2 LCD,
//      and on FAIL sound the buzzer for 3s. Hold for ~3s, then
//      return to listening for the next transmission.
//
// Also requires lcd_display.v and uart_rx.v (provided alongside
// this file).
//
// Requires (download separately from secworks/sha256 GitHub repo,
// add to Vivado project sources - do NOT modify their internals):
//   sha256_core.v
//   sha256_k_constants.v
//   sha256_w_mem.v
//
// NOTE: sha256_core's exact port names/polarity should be checked
// against the version you download - the instantiation below uses
// the port set documented in that repo (clk, reset_n, init, next,
// mode, block, ready, digest, digest_valid). If your checked-out
// copy differs, adjust the port map in the instantiation section.
// ============================================================

module secure_boot_top (
    input  wire clk_24mhz,   // D13 - board 24MHz oscillator
    input  wire uart_rx_pin, // PMOD IO_0 (T2) <- jumper to J13 pin6 (ESP_TX)

    output reg  led_pass,    // LED1 (D5)  - lights when firmware verified OK
    output reg  led_fail,    // LED2 (A3)  - lights when hash mismatch (tamper)
    output reg  led_busy,    // LED3 (B4)  - lights while receiving/hashing

    output wire lcd_rs,      // G4
    output wire lcd_rw,      // H3
    output wire lcd_e,       // E1
    output wire [7:0] lcd_d, // G2,G1,H5,H4,J5,J4,H2,H1

    output reg  buzzer_out   // K5 (BZR_OUT) - active buzzer, high = sound
);

    // ------------------------------------------------------------
    // Reference SHA-256 hash of the trusted 32-byte firmware image
    // "ANMAYA-FPGA-SECUREBOOT-DEMO-001!"
    // Computed on PC with: sha256sum firmware.bin
    // ------------------------------------------------------------
    localparam [255:0] REFERENCE_HASH =
        256'h2edf75d6921db8efcdc79f2e384835356b349e30235b7b5988dd157079f88d77;
        // This is sha256sum of the ASCII bytes "ANMAYA-FPGA-SECUREBOOT-DEMO-001!"
        // (32 bytes exactly). If you change the firmware payload, recompute
        // this with: sha256sum firmware.bin   and replace the constant.

    // ------------------------------------------------------------
    // UART receiver
    // ------------------------------------------------------------
    wire [7:0] uart_data;
    wire       uart_valid;
    reg        uart_rst;

    uart_rx #(
        .CLK_FREQ (24_000_000),
        .BAUD     (115200)
    ) u_uart_rx (
        .clk   (clk_24mhz),
        .rst   (uart_rst),
        .rx    (uart_rx_pin),
        .data  (uart_data),
        .valid (uart_valid)
    );

    // ------------------------------------------------------------
    // LCD status display
    // ------------------------------------------------------------
    reg        lcd_trigger;
    reg [1:0]  lcd_msg_sel; // 0=BOOT, 1=BUSY, 2=PASS, 3=FAIL

    lcd_display u_lcd_display (
        .clk_24mhz (clk_24mhz),
        .trigger   (lcd_trigger),
        .msg_sel   (lcd_msg_sel),
        .lcd_rs    (lcd_rs),
        .lcd_rw    (lcd_rw),
        .lcd_e     (lcd_e),
        .lcd_d     (lcd_d)
    );

    // ------------------------------------------------------------
    // Firmware byte buffer (32 bytes = 256 bits, fits one SHA block)
    // ------------------------------------------------------------
    localparam integer FW_BYTES = 32;
    reg [7:0] fw_buf [0:FW_BYTES-1];
    reg [5:0] byte_cnt;

    // ------------------------------------------------------------
    // SHA-256 core signals
    // ------------------------------------------------------------
    reg         sha_init;
    reg         sha_next;   // unused (single block only)
    reg         sha_mode;   // 1 = SHA-256 mode (per secworks core)
    reg [511:0] sha_block;
    wire        sha_ready;
    wire [255:0] sha_digest;
    wire        sha_digest_valid;

    sha256_core u_sha256_core (
        .clk          (clk_24mhz),
        .reset_n      (~uart_rst),
        .init         (sha_init),
        .next         (sha_next),
        .mode         (sha_mode),
        .block        (sha_block),
        .ready        (sha_ready),
        .digest       (sha_digest),
        .digest_valid (sha_digest_valid)
    );

    // ------------------------------------------------------------
    // Main FSM
    // ------------------------------------------------------------
    localparam S_SYNC1    = 0;
    localparam S_SYNC2    = 1;
    localparam S_RECEIVE  = 2;
    localparam S_BUILD    = 3;
    localparam S_HASH_GO  = 4;
    localparam S_HASH_WAIT= 5;
    localparam S_RESULT   = 6;
    localparam S_HOLD     = 7;

    reg [2:0]  state;
    reg [26:0] hold_cnt;          // ~3s hold @ 24MHz (also buzzer duration on FAIL)
    localparam integer HOLD_TIME = 24_000_000 * 3;

    integer i;

    always @(posedge clk_24mhz) begin
        uart_rst    <= 1'b0;
        sha_init    <= 1'b0;
        sha_next    <= 1'b0;
        lcd_trigger <= 1'b0; // default: no LCD update this cycle

        case (state)

            S_SYNC1: begin
                led_pass   <= 1'b0;
                led_fail   <= 1'b0;
                led_busy   <= 1'b0;
                buzzer_out <= 1'b0;
                if (uart_valid && uart_data == 8'hAA)
                    state <= S_SYNC2;
            end

            S_SYNC2: begin
                if (uart_valid) begin
                    if (uart_data == 8'h55) begin
                        byte_cnt    <= 0;
                        state       <= S_RECEIVE;
                        led_busy    <= 1'b1;
                        lcd_msg_sel <= 2'd1; // "VERIFYING FW..."
                        lcd_trigger <= 1'b1;
                    end else if (uart_data != 8'hAA) begin
                        state <= S_SYNC1; // false alarm, resync
                    end
                    // if uart_data==0xAA again, just stay in S_SYNC2
                end
            end

            S_RECEIVE: begin
                led_busy <= 1'b1;
                if (uart_valid) begin
                    fw_buf[byte_cnt] <= uart_data;
                    if (byte_cnt == FW_BYTES-1)
                        state <= S_BUILD;
                    else
                        byte_cnt <= byte_cnt + 1'b1;
                end
            end

            S_BUILD: begin
                // Pack 32 firmware bytes (MSB-first) + 0x80 pad +
                // zero padding + 64-bit big-endian bit length (256 = 0x100)
                sha_block <= { fw_buf[0],  fw_buf[1],  fw_buf[2],  fw_buf[3],
                               fw_buf[4],  fw_buf[5],  fw_buf[6],  fw_buf[7],
                               fw_buf[8],  fw_buf[9],  fw_buf[10], fw_buf[11],
                               fw_buf[12], fw_buf[13], fw_buf[14], fw_buf[15],
                               fw_buf[16], fw_buf[17], fw_buf[18], fw_buf[19],
                               fw_buf[20], fw_buf[21], fw_buf[22], fw_buf[23],
                               fw_buf[24], fw_buf[25], fw_buf[26], fw_buf[27],
                               fw_buf[28], fw_buf[29], fw_buf[30], fw_buf[31],
                               8'h80,                       // pad start bit
                               184'd0,                      // zero padding (23 bytes)
                               64'd256 };                   // message length in bits
                sha_mode <= 1'b1; // SHA-256 mode
                state    <= S_HASH_GO;
            end

            S_HASH_GO: begin
                if (sha_ready) begin
                    sha_init <= 1'b1;   // pulse init for 1 cycle
                    state    <= S_HASH_WAIT;
                end
            end

            S_HASH_WAIT: begin
                if (sha_digest_valid)
                    state <= S_RESULT;
            end

            S_RESULT: begin
                led_busy <= 1'b0;
                if (sha_digest == REFERENCE_HASH) begin
                    led_pass    <= 1'b1;
                    led_fail    <= 1'b0;
                    buzzer_out  <= 1'b0;
                    lcd_msg_sel <= 2'd2; // "PASS - FW OK"
                end else begin
                    led_pass    <= 1'b0;
                    led_fail    <= 1'b1;
                    buzzer_out  <= 1'b1; // sound buzzer for the full hold period (3s)
                    lcd_msg_sel <= 2'd3; // "FAIL - TAMPERED"
                end
                lcd_trigger <= 1'b1;
                hold_cnt    <= 0;
                state       <= S_HOLD;
            end

            S_HOLD: begin
                // hold result on LEDs/LCD/buzzer for ~3s, then go listen again
                if (hold_cnt < HOLD_TIME) begin
                    hold_cnt <= hold_cnt + 1'b1;
                end else begin
                    buzzer_out  <= 1'b0;
                    lcd_msg_sel <= 2'd0; // back to "SECURE BOOT RDY"
                    lcd_trigger <= 1'b1;
                    state       <= S_SYNC1;
                end
            end

            default: state <= S_SYNC1;
        endcase
    end

    initial begin
        state       = S_SYNC1;
        byte_cnt    = 0;
        led_pass    = 0;
        led_fail    = 0;
        led_busy    = 0;
        buzzer_out  = 0;
        uart_rst    = 1;
        sha_init    = 0;
        sha_next    = 0;
        sha_mode    = 1;
        hold_cnt    = 0;
        lcd_trigger = 0;
        lcd_msg_sel = 0;
    end

endmodule
