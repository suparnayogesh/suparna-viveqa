// ============================================================
// lcd_display.v
// 16x2 HD44780-compatible LCD status display.
// Initializes once on power-up, then shows one of 4 fixed
// 16-char messages on line 1 whenever 'trigger' is pulsed,
// selected by msg_sel:
//   0 = "SECURE BOOT RDY "
//   1 = "VERIFYING FW... "
//   2 = "PASS - FW OK    "
//   3 = "FAIL - TAMPERED "
// ============================================================

module lcd_display (
    input  wire       clk_24mhz,
    input  wire       trigger,   // 1-cycle pulse: load & show msg_sel
    input  wire [1:0] msg_sel,

    output reg  lcd_rs,   // G4
    output reg  lcd_rw,   // H3 (tied low - write only)
    output reg  lcd_e,    // E1
    output reg  [7:0] lcd_d // G2,G1,H5,H4,J5,J4,H2,H1 (D0..D7)
);

    // ------------------------------------------------------------
    // Timing constants @ 24 MHz
    // ------------------------------------------------------------
    localparam integer POWERON_DELAY = 24_000_000 / 20; // ~50ms
    localparam integer ENABLE_PULSE  = 20;               // ~833ns
    localparam integer CMD_DELAY     = 24_000_000 / 400; // ~2.5ms (covers clear/home worst case)

    // ------------------------------------------------------------
    // Init command ROM (RS = 0 for all)
    // ------------------------------------------------------------
    reg [7:0] init_rom [0:3];
    initial begin
        init_rom[0] = 8'h38; // function set: 8-bit, 2-line, 5x8
        init_rom[1] = 8'h0C; // display on, cursor off
        init_rom[2] = 8'h01; // clear display
        init_rom[3] = 8'h06; // entry mode: increment
    end

    // ------------------------------------------------------------
    // Message text -> byte lookup (16 chars each, packed MSB-first)
    // ------------------------------------------------------------
    function [7:0] get_char;
        input [1:0] sel;
        input [4:0] idx;
        reg [127:0] m;
        begin
            case (sel)
                2'd0: m = "SECURE BOOT RDY ";
                2'd1: m = "VERIFYING FW... ";
                2'd2: m = "PASS - FW OK    ";
                2'd3: m = "FAIL - TAMPERED ";
                default: m = "                ";
            endcase
            get_char = m[127 - (idx*8) -: 8];
        end
    endfunction

    // ------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------
    localparam S_POWERON     = 0;
    localparam S_INIT_SETUP  = 1;
    localparam S_INIT_EN_HI  = 2;
    localparam S_INIT_EN_LO  = 3;
    localparam S_INIT_WAIT   = 4;
    localparam S_IDLE_WAIT   = 5;
    localparam S_ADDR_SETUP  = 6;
    localparam S_ADDR_EN_HI  = 7;
    localparam S_ADDR_EN_LO  = 8;
    localparam S_ADDR_WAIT   = 9;
    localparam S_CHAR_SETUP  = 10;
    localparam S_CHAR_EN_HI  = 11;
    localparam S_CHAR_EN_LO  = 12;
    localparam S_CHAR_WAIT   = 13;

    reg [3:0]  state;
    reg [25:0] delay_cnt;
    reg [2:0]  init_idx;
    reg [4:0]  char_idx;
    reg [1:0]  cur_msg;

    always @(posedge clk_24mhz) begin
        lcd_rw <= 1'b0;

        case (state)

            // ---------------- power-on + one-time init ----------------
            S_POWERON: begin
                lcd_e <= 1'b0;
                if (delay_cnt < POWERON_DELAY)
                    delay_cnt <= delay_cnt + 1'b1;
                else begin
                    delay_cnt <= 0;
                    init_idx  <= 0;
                    state     <= S_INIT_SETUP;
                end
            end

            S_INIT_SETUP: begin
                if (init_idx < 4) begin
                    lcd_rs    <= 1'b0;
                    lcd_d     <= init_rom[init_idx];
                    delay_cnt <= 0;
                    lcd_e     <= 1'b1;
                    state     <= S_INIT_EN_HI;
                end else begin
                    // init done -> show boot-ready message immediately
                    cur_msg  <= 2'd0;
                    char_idx <= 0;
                    state    <= S_ADDR_SETUP;
                end
            end

            S_INIT_EN_HI: begin
                if (delay_cnt < ENABLE_PULSE) delay_cnt <= delay_cnt + 1'b1;
                else begin lcd_e <= 1'b0; delay_cnt <= 0; state <= S_INIT_EN_LO; end
            end

            S_INIT_EN_LO: begin
                delay_cnt <= 0;
                state     <= S_INIT_WAIT;
            end

            S_INIT_WAIT: begin
                if (delay_cnt < CMD_DELAY) delay_cnt <= delay_cnt + 1'b1;
                else begin
                    delay_cnt <= 0;
                    init_idx  <= init_idx + 1'b1;
                    state     <= S_INIT_SETUP;
                end
            end

            // ---------------- wait for a message request ----------------
            S_IDLE_WAIT: begin
                lcd_e <= 1'b0;
                if (trigger) begin
                    cur_msg  <= msg_sel;
                    char_idx <= 0;
                    state    <= S_ADDR_SETUP;
                end
            end

            // ---------------- set DDRAM addr to line1 col0 (0x80) ----------------
            S_ADDR_SETUP: begin
                lcd_rs    <= 1'b0;
                lcd_d     <= 8'h80;
                delay_cnt <= 0;
                lcd_e     <= 1'b1;
                state     <= S_ADDR_EN_HI;
            end

            S_ADDR_EN_HI: begin
                if (delay_cnt < ENABLE_PULSE) delay_cnt <= delay_cnt + 1'b1;
                else begin lcd_e <= 1'b0; delay_cnt <= 0; state <= S_ADDR_EN_LO; end
            end

            S_ADDR_EN_LO: begin
                delay_cnt <= 0;
                state     <= S_ADDR_WAIT;
            end

            S_ADDR_WAIT: begin
                if (delay_cnt < CMD_DELAY) delay_cnt <= delay_cnt + 1'b1;
                else begin
                    delay_cnt <= 0;
                    state     <= S_CHAR_SETUP;
                end
            end

            // ---------------- write 16 characters ----------------
            S_CHAR_SETUP: begin
                if (char_idx < 16) begin
                    lcd_rs    <= 1'b1;
                    lcd_d     <= get_char(cur_msg, char_idx);
                    delay_cnt <= 0;
                    lcd_e     <= 1'b1;
                    state     <= S_CHAR_EN_HI;
                end else begin
                    state <= S_IDLE_WAIT;
                end
            end

            S_CHAR_EN_HI: begin
                if (delay_cnt < ENABLE_PULSE) delay_cnt <= delay_cnt + 1'b1;
                else begin lcd_e <= 1'b0; delay_cnt <= 0; state <= S_CHAR_EN_LO; end
            end

            S_CHAR_EN_LO: begin
                delay_cnt <= 0;
                state     <= S_CHAR_WAIT;
            end

            S_CHAR_WAIT: begin
                if (delay_cnt < CMD_DELAY) delay_cnt <= delay_cnt + 1'b1;
                else begin
                    delay_cnt <= 0;
                    char_idx  <= char_idx + 1'b1;
                    state     <= S_CHAR_SETUP;
                end
            end

            default: state <= S_POWERON;
        endcase
    end

    initial begin
        state     = S_POWERON;
        delay_cnt = 0;
        init_idx  = 0;
        char_idx  = 0;
        cur_msg   = 0;
        lcd_rs    = 0;
        lcd_rw    = 0;
        lcd_e     = 0;
        lcd_d     = 8'h00;
    end

endmodule
