1. Write RTL for 1bit Full adder using Dataflow abstraction and verify the same using a Testbench. 

module full_adder(
    input A,
    input B,
    input Cin,
    output Sum,
    output Cout
);

assign Sum  = A ^ B ^ Cin;
assign Cout = (A & B) | (B & Cin) | (A & Cin);

endmodule


module full_adder_tb;

reg A, B, Cin;
wire Sum, Cout;

full_adder dut(
    A, B, Cin,
    Sum, Cout
);

initial begin
    {A,B,Cin} = 3'b000; #10;
    {A,B,Cin} = 3'b001; #10;
    {A,B,Cin} = 3'b010; #10;
    {A,B,Cin} = 3'b011; #10;
    {A,B,Cin} = 3'b100; #10;
    {A,B,Cin} = 3'b101; #10;
    {A,B,Cin} = 3'b110; #10;
    {A,B,Cin} = 3'b111; #10;

    $finish;
end

endmodule

2. Write RTL for 2x4 decoder using Dataflow abstraction and verify the same using a Testbench. 
module decoder_2x4 (
    input  A,
    input  B,
    output Y0,
    output Y1,
    output Y2,
    output Y3
);

assign Y0 = ~A & ~B;
assign Y1 = ~A &  B;
assign Y2 =  A & ~B;
assign Y3 =  A &  B;

endmodule


module decoder_2x4_tb;

reg A, B;
wire Y0, Y1, Y2, Y3;

decoder_2x4 dut (
    .A(A),
    .B(B),
    .Y0(Y0),
    .Y1(Y1),
    .Y2(Y2),
    .Y3(Y3)
);

initial begin
    $monitor("A=%b B=%b | Y0=%b Y1=%b Y2=%b Y3=%b",
              A, B, Y0, Y1, Y2, Y3);

    A = 0; B = 0; #10;
    A = 0; B = 1; #10;
    A = 1; B = 0; #10;
    A = 1; B = 1; #10;

    $finish;
end

endmodule

3. Write RTL for 8x3 priority encoder using structural model and verify the same using a Testbench. 
module priority_encoder_8x3(
    input  D0, D1, D2, D3, D4, D5, D6, D7,
    output Y2, Y1, Y0
);

wire D6b, D5b, D4b, D3b, D2b;

not (D6b, D6);
not (D5b, D5);
not (D4b, D4);
not (D3b, D3);
not (D2b, D2);

or  (Y2, D4, D5, D6, D7);

wire w1, w2;
and (w1, D4b, D5b, D2);
and (w2, D4b, D5b, D3);
or  (Y1, D6, D7, w1, w2);

wire w3, w4, w5;
and (w3, D6b, D5);
and (w4, D6b, D4b, D3);
and (w5, D6b, D4b, D2b, D1);
or  (Y0, D7, w3, w4, w5);

endmodule

`timescale 1ns/1ps

module priority_encoder_8x3_tb;

reg D0, D1, D2, D3, D4, D5, D6, D7;
wire Y2, Y1, Y0;

priority_encoder_8x3 dut (
    D0, D1, D2, D3, D4, D5, D6, D7,
    Y2, Y1, Y0
);

initial begin
    $monitor("D7D6D5D4D3D2D1D0=%b%b%b%b%b%b%b%b -> Y=%b%b%b",
              D7,D6,D5,D4,D3,D2,D1,D0,Y2,Y1,Y0);

    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b00000001; #10; // D0
    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b00000010; #10; // D1
    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b00000100; #10; // D2
    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b00001000; #10; // D3
    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b00010000; #10; // D4
    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b00100000; #10; // D5
    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b01000000; #10; // D6
    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b10000000; #10; // D7

    // Priority check
    {D7,D6,D5,D4,D3,D2,D1,D0} = 8'b10101010; #10;

    $finish;
end

endmodule


4. Write RTL for the 4 bits Ripple carry Adder using 1-bit Full adder and verify the same using a Testbench.
module full_adder(
    input A, B, Cin,
    output Sum, Cout
);

assign Sum  = A ^ B ^ Cin;
assign Cout = (A & B) | (B & Cin) | (A & Cin);

endmodule

module ripple_carry_adder_4bit(
    input  [3:0] A,
    input  [3:0] B,
    input  Cin,
    output [3:0] Sum,
    output Cout
);

wire C1, C2, C3;

full_adder FA0(A[0], B[0], Cin, Sum[0], C1);
full_adder FA1(A[1], B[1], C1,  Sum[1], C2);
full_adder FA2(A[2], B[2], C2,  Sum[2], C3);
full_adder FA3(A[3], B[3], C3,  Sum[3], Cout);

endmodule

`timescale 1ns/1ps

module ripple_carry_adder_4bit_tb;

reg  [3:0] A, B;
reg  Cin;
wire [3:0] Sum;
wire Cout;

ripple_carry_adder_4bit dut(
    A, B, Cin, Sum, Cout
);

initial begin
    $monitor("A=%b B=%b Cin=%b -> Sum=%b Cout=%b",
              A, B, Cin, Sum, Cout);

    A = 4'b0000; B = 4'b0000; Cin = 0; #10;
    A = 4'b0011; B = 4'b0101; Cin = 0; #10;
    A = 4'b0111; B = 4'b0001; Cin = 0; #10;
    A = 4'b1111; B = 4'b0001; Cin = 0; #10;
    A = 4'b1010; B = 4'b0101; Cin = 1; #10;

    $finish;
end

endmodule

5. Write RTL for 4:1 Mux using 2:1 Muxes and verify the same using a Testbench.

module mux2x1(
    input I0, I1, S,
    output Y
);

assign Y = S ? I1 : I0;

endmodule

module mux4x1(
    input I0, I1, I2, I3,
    input S0, S1,
    output Y
);

wire w1, w2;

mux2x1 M1(I0, I1, S0, w1);
mux2x1 M2(I2, I3, S0, w2);
mux2x1 M3(w1, w2, S1, Y);

endmodule

`timescale 1ns/1ps

module mux4x1_tb;

reg I0, I1, I2, I3;
reg S0, S1;
wire Y;

mux4x1 dut(
    I0, I1, I2, I3,
    S0, S1,
    Y
);

initial begin
    I0 = 0; I1 = 1; I2 = 0; I3 = 1;

    S1 = 0; S0 = 0; #10;
    S1 = 0; S0 = 1; #10;
    S1 = 1; S0 = 0; #10;
    S1 = 1; S0 = 1; #10;

    $finish;
end

endmodule


6. Write RTL description and test bench for 3:8 Decoder.

module decoder_3x8(
    input A, B, C,
    output Y0, Y1, Y2, Y3, Y4, Y5, Y6, Y7
);

assign Y0 = ~A & ~B & ~C;
assign Y1 = ~A & ~B &  C;
assign Y2 = ~A &  B & ~C;
assign Y3 = ~A &  B &  C;
assign Y4 =  A & ~B & ~C;
assign Y5 =  A & ~B &  C;
assign Y6 =  A &  B & ~C;
assign Y7 =  A &  B &  C;

endmodule


`timescale 1ns/1ps

module decoder_3x8_tb;

reg A, B, C;
wire Y0, Y1, Y2, Y3, Y4, Y5, Y6, Y7;

decoder_3x8 dut(
    A, B, C,
    Y0, Y1, Y2, Y3, Y4, Y5, Y6, Y7
);

initial begin
    {A,B,C} = 3'b000; #10;
    {A,B,C} = 3'b001; #10;
    {A,B,C} = 3'b010; #10;
    {A,B,C} = 3'b011; #10;
    {A,B,C} = 3'b100; #10;
    {A,B,C} = 3'b101; #10;
    {A,B,C} = 3'b110; #10;
    {A,B,C} = 3'b111; #10;

    $finish;
end

endmodule


7. Write RTL description and testbench for 8:3 Priority encoder. 
module priority_encoder_8x3(
    input  [7:0] D,
    output reg [2:0] Y
);

always @(*) begin
    casex(D)
        8'b1xxxxxxx: Y = 3'b111;
        8'b01xxxxxx: Y = 3'b110;
        8'b001xxxxx: Y = 3'b101;
        8'b0001xxxx: Y = 3'b100;
        8'b00001xxx: Y = 3'b011;
        8'b000001xx: Y = 3'b010;
        8'b0000001x: Y = 3'b001;
        8'b00000001: Y = 3'b000;
        default:     Y = 3'b000;
    endcase
end

endmodule

`timescale 1ns/1ps

module priority_encoder_8x3_tb;

reg  [7:0] D;
wire [2:0] Y;

priority_encoder_8x3 dut(
    D,
    Y
);

initial begin
    D = 8'b00000001; #10;
    D = 8'b00000010; #10;
    D = 8'b00000100; #10;
    D = 8'b00001000; #10;
    D = 8'b00010000; #10;
    D = 8'b00100000; #10;
    D = 8'b01000000; #10;
    D = 8'b10000000; #10;

    // Priority check
    D = 8'b10101010; #10;

    $finish;
end

endmodule


Sequential Circuits
1. Write RTL and Testbench for SR latch using Gate level modelling. 

module sr_latch(
    input S,R,
    output Q,Qb
);

nand(Q,Qb,S);
nand(Qb,Q,R);

endmodule

`timescale 1ns/1ps

module sr_latch_tb;

reg S,R;
wire Q,Qb;

sr_latch dut(S,R,Q,Qb);

initial begin
    S=1; R=1; #10; // Hold
    S=0; R=1; #10; // Set
    S=1; R=1; #10; // Hold
    S=1; R=0; #10; // Reset
    S=1; R=1; #10; // Hold

    $finish;
end

endmodule

2. Write RTL and Testbench for JK Flip Flop, using parameter declaration for the respective scenarios (HOLD, TOGGLE, SET, RESET).
module jk_ff(
    input J,K,clk,rst,
    output reg Q
);

parameter HOLD   = 2'b00,
          RESET  = 2'b01,
          SET    = 2'b10,
          TOGGLE = 2'b11;

always @(posedge clk or posedge rst)
begin
    if(rst)
        Q <= 0;
    else
        case({J,K})
            HOLD   : Q <= Q;
            RESET  : Q <= 0;
            SET    : Q <= 1;
            TOGGLE : Q <= ~Q;
        endcase
end

endmodule

`timescale 1ns/1ps

module jk_ff_tb;

reg J,K,clk,rst;
wire Q;

jk_ff dut(J,K,clk,rst,Q);

always #5 clk=~clk;

initial begin
    clk=0;
    rst=1; #10;
    rst=0;

    J=0; K=0; #10; // Hold
    J=0; K=1; #10; // Reset
    J=1; K=0; #10; // Set
    J=1; K=1; #20; // Toggle

    $finish;
end

endmodule

3. Write RTL and Testbench for for a T Flip Flop using D Flip Flop. 

module dff(
    input clk,rst,D,
    output reg Q
);

always @(posedge clk or posedge rst)
begin
    if(rst)
        Q <= 0;
    else
        Q <= D;
end

endmodule


module t_ff(
    input T,clk,rst,
    output Q
);

wire D;

assign D = T ^ Q;

dff d1(clk,rst,D,Q);

endmodule


`timescale 1ns/1ps

module t_ff_tb;

reg T,clk,rst;
wire Q;

t_ff dut(T,clk,rst,Q);

always #5 clk=~clk;

initial begin
    clk=0;
    rst=1; #10;
    rst=0;

    T=0; #20; // Hold
    T=1; #40; // Toggle

    $finish;
end

endmodule


4. Write RTL and Testbench for a 4-bit synchronous and loadable binary up counter. 

module sync_up_counter(
    input clk,rst,
    input load,
    input [3:0] D,
    output reg [3:0] Q
);

always @(posedge clk or posedge rst)
begin
    if(rst)
        Q <= 4'b0000;
    else if(load)
        Q <= D;
    else
        Q <= Q + 1;
end

endmodule


`timescale 1ns/1ps

module sync_up_counter_tb;

reg clk,rst,load;
reg [3:0] D;
wire [3:0] Q;

sync_up_counter dut(clk,rst,load,D,Q);

always #5 clk=~clk;

initial begin
    clk=0;
    rst=1; #10;
    rst=0;

    load=1;
    D=4'b1010; #10;

    load=0; #50;

    load=1;
    D=4'b0011; #10;

    load=0; #30;

    $finish;
end

endmodule

5. Write RTL and Testbench to design a 4-bit MOD-12 loadable binary synchronous up counter. 

module mod12_counter(
    input clk,
    input rst,
    input load,
    input [3:0] D,
    output reg [3:0] Q
);

always @(posedge clk or posedge rst)
begin
    if(rst)
        Q <= 4'b0000;
    else if(load)
        Q <= D;
    else if(Q == 4'd11)
        Q <= 4'd0;
    else
        Q <= Q + 1;
end

endmodule

`timescale 1ns/1ps

module mod12_counter_tb;

reg clk,rst,load;
reg [3:0] D;
wire [3:0] Q;

mod12_counter dut(clk,rst,load,D,Q);

always #5 clk = ~clk;

initial begin
    clk = 0;
    rst = 1; #10;
    rst = 0;

    load = 1;
    D = 4'd5; #10;

    load = 0; #100;

    load = 1;
    D = 4'd9; #10;

    load = 0; #50;

    $finish;
end

endmodule
6. Write RTL and Testbench to design a 4-bit loadable binary synchronous up-down counter 

module updown_counter(
    input clk,
    input rst,
    input load,
    input up_down,
    input [3:0] D,
    output reg [3:0] Q
);

always @(posedge clk or posedge rst)
begin
    if(rst)
        Q <= 4'b0000;
    else if(load)
        Q <= D;
    else if(up_down)
        Q <= Q + 1;
    else
        Q <= Q - 1;
end

endmodule

`timescale 1ns/1ps

module updown_counter_tb;

reg clk,rst,load,up_down;
reg [3:0] D;
wire [3:0] Q;

updown_counter dut(
    clk,rst,load,up_down,D,Q
);

always #5 clk = ~clk;

initial begin
    clk = 0;
    rst = 1; #10;
    rst = 0;

    load = 1;
    D = 4'd4; #10;

    load = 0;
    up_down = 1; #50;

    up_down = 0; #50;

    load = 1;
    D = 4'd10; #10;

    load = 0;
    up_down = 0; #40;

    $finish;
end

endmodule
