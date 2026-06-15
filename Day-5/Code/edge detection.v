module edge_detect(
    input clk,
    input rst_n,
    input data_in,
    output rising_edge,
    output falling_edge,
    output both_edge
);
    reg data_in_delayed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_in_delayed <= 0;
        else
            data_in_delayed <= data_in;
    end

    assign rising_edge = data_in & ~data_in_delayed;
    assign falling_edge = ~data_in & data_in_delayed;
    assign both_edge = data_in ^ data_in_delayed;
endmodule
