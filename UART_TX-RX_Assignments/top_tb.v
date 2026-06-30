`timescale 1ns/1ps

module tb_uart_loopback_top;

reg clk;
reg rst;

reg tx_start;
reg [7:0] tx_data;

wire tx_busy;
wire [7:0] rx_data;
wire rx_done;

uart_loopback_top DUT (

    .clk(clk),
    .rst(rst),

    .tx_start(tx_start),
    .tx_data(tx_data),

    .tx_busy(tx_busy),

    .rx_data(rx_data),
    .rx_done(rx_done)

);

always #20 clk = ~clk;

task send_data;
input [7:0] data;
begin

    @(posedge clk);

    tx_data  <= data;
    tx_start <= 1'b1;

    @(posedge clk);

    tx_start <= 1'b0;

    wait(rx_done);

    if(rx_data == data)
        $display("PASS : Sent=%h Received=%h Time=%t",
                 data, rx_data, $time);
    else
        $display("FAIL : Sent=%h Received=%h Time=%t",
                 data, rx_data, $time);

    #100000;

end
endtask

initial
begin

    clk = 0;
    rst = 1;
    tx_start = 0;
    tx_data = 0;

    #500;

    rst = 0;

    send_data(8'h55);

    send_data(8'hAA);

    send_data(8'hF0);

    send_data(8'h0F);

    send_data(8'hA5);

    send_data(8'h5A);

    #1000000;

    $display("TEST COMPLETED");

    $stop;

end

endmodule
