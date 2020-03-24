module psram_rx_buf (
    // psram
    input                   psram_rstn,
    input                   psram_clk,
    input                   psram_start,
    output                  rx_rdy,
    input                   rx_vld,
    input   [31:0]          rx_data,
    // hclk
    input                   hclk,
    input                   hrstn,
    input                   start,
    output reg              ram_wr_req,
    input                   ram_wr_ack,
    output  [31:0]          ram_wdata
);
// signals
reg [31:0] d0, d1;
reg fill_flag; reg [1:0] fill_flag_dly; wire fill_flag_sync;
reg toggle; reg [2:0] toggle_dly; wire tx_vld;

// psram clock domain
always @(posedge psram_clk)
    if (fill_flag == 0 && rx_vld == 1)
        d0 <= rx_data;
always @(posedge psram_clk or negedge psram_rstn)
    if (psram_rstn)
        fill_flag <= 0;
    else if (psram_start) // init
        fill_flag <= 0;
    else if (fill_flag == 0 && rx_vld == 1)
        fill_flag <= 1;
    else if (fill_flag == 1 && tx_vld == 1)
        fill_flag <= 0;
assign rx_rdy = ~fill_flag;

// cross clock domain
always @(posedge hclk or negedge hrstn)
    if (~hrstn)
        fill_flag_dly <= 0;
    else if (start)
        fill_flag_dly <= 0;
    else
        fill_flag_dly <= {fill_flag_dly[0], fill_flag};
assign fill_flag_sync = fill_flag_dly[1];
// 
always @(posedge psram_clk or negedge psram_rstn)
    if (psram_rstn)
        toggle_dly <= 0;
    else
        toggle_dly <= {toggle_dly[1:0], toggle};
assign tx_vld = toggle_dly[2] ^ toggle_dly[1];

// hclk clock domain
always @(posedge hclk or negedge hrstn)
    if (~hrstn)
        ram_wr_req <= 0;
    else if (start)
        ram_wr_req <= 0;
    else if (ram_wr_ack)
        ram_wr_req <= 0;
    else if (fill_flag_sync)
        ram_wr_req <= 1;
assign ram_wdata = d0;
// toggle
always @(posedge hclk or negedge hrstn)
    if (~hrstn)
        toggle <= 0;
//    else if (start) // do not need sync reset
//        toggle <= 0;
    else if (ram_wr_req & ram_wr_ack)
        toggle <= ~toggle;

endmodule

