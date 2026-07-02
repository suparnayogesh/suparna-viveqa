// ============================================================
// uart_rx.v
// Simple 8N1 UART receiver
// Default: 24 MHz system clock, 115200 baud
// ============================================================

module uart_rx #(
    parameter integer CLK_FREQ = 24_000_000,
    parameter integer BAUD     = 115200
) (
    input  wire       clk,
    input  wire        rst,        // synchronous, active high
    input  wire       rx,         // async serial input (from ESP32 TX)
    output reg  [7:0] data,       // received byte
    output reg         valid       // 1-cycle pulse when 'data' is valid
);

    localparam integer BIT_PERIOD = CLK_FREQ / BAUD; // ~208 cycles @ 24MHz/115200

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift_reg;

    // 2-stage synchronizer for the async rx line
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end

    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            valid   <= 1'b0;
            clk_cnt <= 0;
            bit_idx <= 0;
            data    <= 8'h00;
        end else begin
            valid <= 1'b0; // default, pulses high for exactly 1 cycle per byte

            case (state)
                S_IDLE: begin
                    if (rx_sync2 == 1'b0) begin  // falling edge = start bit
                        clk_cnt <= 0;
                        state   <= S_START;
                    end
                end

                S_START: begin
                    if (clk_cnt == (BIT_PERIOD / 2)) begin
                        if (rx_sync2 == 1'b0) begin
                            clk_cnt <= 0;
                            bit_idx <= 0;
                            state   <= S_DATA;
                        end else begin
                            state <= S_IDLE; // glitch, not a real start bit
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_cnt == (BIT_PERIOD - 1)) begin
                        clk_cnt <= 0;
                        shift_reg[bit_idx] <= rx_sync2;
                        if (bit_idx == 3'd7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_cnt == (BIT_PERIOD - 1)) begin
                        clk_cnt <= 0;
                        data    <= shift_reg;
                        valid   <= 1'b1;
                        state   <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
