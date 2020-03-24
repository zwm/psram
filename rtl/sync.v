
// sync2
module sync2 (
    input rstn, clk, din,
    output dout
);
// dly
reg [1:0] din_dly;
always @(posedge clk or negedge rstn)
    if (~rstn)
        din_dly <= 0;
    else
        din_dly <= {din_dly[0], din};
// output
assign dout = din_dly[1];

endmodule

// psync2
module psync2 (
    input srstn, sclk, sin,
    input drstn, dclk,
    output dout
);
// source toggle
reg stoggle;
always @(posedge sclk or negedge srstn)
    if (~srstn)
        stoggle <= 0;
    else if (sin)
        stoggle <= ~stoggle;
// cross clock domain
reg [2:0] stoggle_dly;
always @(posedge dclk or negedge drstn)
    if (~drstn)
        stoggle_dly <= 0;
    else
        stoggle_dly <= {stoggle_dly[1:0], stoggle};
// edge
assign dout = stoggle_dly[2] ^ stoggle_dly[1];

endmodule

