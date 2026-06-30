`timescale 1ns / 1ps

module button_decoder(

    input  [15:0] buttons,
    output reg [7:0] ascii_char,
    output reg valid

);

always @(*)
begin

    valid = 1'b1;

    case(buttons)

        // Button 0
        16'h0001: ascii_char = "0";

        // Button 1
        16'h0002: ascii_char = "1";

        // Button 2
        16'h0004: ascii_char = "2";

        // Button 3
        16'h0008: ascii_char = "3";

        // Button 4
        16'h0010: ascii_char = "4";

        // Button 5
        16'h0020: ascii_char = "5";

        // Button 6
        16'h0040: ascii_char = "6";

        // Button 7
        16'h0080: ascii_char = "7";

        // Button 8
        16'h0100: ascii_char = "8";

        // Button 9
        16'h0200: ascii_char = "9";

        // Button A
        16'h0400: ascii_char = "A";

        // Button B
        16'h0800: ascii_char = "B";

        // Button C
        16'h1000: ascii_char = "C";

        // Button D
        16'h2000: ascii_char = "D";

        // Button E
        16'h4000: ascii_char = "E";

        // Button F
        16'h8000: ascii_char = "F";

        default:
        begin
            ascii_char = 8'h00;
            valid      = 1'b0;
        end

    endcase

end

endmodule
