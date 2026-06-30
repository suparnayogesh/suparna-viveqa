`timescale 1ns / 1ps

module led_controller(

    input clk,
    input rst,

    input rx_done,
    input [7:0] rx_data,

    output reg [7:0] leds

);

always @(posedge clk or posedge rst)
begin

    if(rst)
    begin
        leds <= 8'b00000000;
    end

    else if(rx_done)
    begin

        case(rx_data)

            "1": leds[0] <= ~leds[0];
            "2": leds[1] <= ~leds[1];
            "3": leds[2] <= ~leds[2];
            "4": leds[3] <= ~leds[3];
            "5": leds[4] <= ~leds[4];
            "6": leds[5] <= ~leds[5];
            "7": leds[6] <= ~leds[6];
            "8": leds[7] <= ~leds[7];

            default: leds <= leds;

        endcase

    end

end

endmodule
