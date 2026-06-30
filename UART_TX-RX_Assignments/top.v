module uart_loopback_top(

    input clk,
    input rst,

    input tx_start,
    input [7:0] tx_data,

    output tx_busy,

    output [7:0] rx_data,
    output rx_done

);

wire uart_wire;

uart_tx TX (
    .clk(clk),
    .rst(rst),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx(uart_wire),
    .tx_busy(tx_busy)
);

uart_rx RX (
    .clk(clk),
    .rst(rst),
    .rx(uart_wire),
    .rx_data(rx_data),
    .rx_done(rx_done)
);

endmodule
