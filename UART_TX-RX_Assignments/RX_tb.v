`timescale 1ns/1ps

module tb_uart_rx;

reg clk;
reg rst;
reg rx;

wire [7:0] rx_data;
wire rx_done;

parameter CLKS_PER_BIT = 2500;
parameter BIT_PERIOD = 100000;

uart_rx DUT (
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .rx_data(rx_data),
    .rx_done(rx_done)
);

always #20 clk = ~clk;

task send_uart_byte;
input [7:0] data;
integer i;
begin

    rx = 0;
    #(BIT_PERIOD);

    for(i=0;i<8;i=i+1)
    begin
        rx = data[i];
        #(BIT_PERIOD);
    end

    rx = 1;
    #(BIT_PERIOD);

end
endtask

initial
begin

    clk = 0;
    rst = 1;
    rx  = 1;

    #500;

    rst = 0;

    send_uart_byte(8'h55);

    #2000000;

    send_uart_byte(8'hA3);

    #2000000;

    $stop;

end

endmodule
