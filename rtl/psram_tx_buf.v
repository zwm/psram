module psram_tx_buf (
    // psram
    input                   psram_rstn,
    input                   psram_clk,
    input                   psram_start,
    input                   tx_free,
    output                  tx_vld,
    output  [31:0]          tx_data,
    // hclk
    input                   hclk,
    input                   hrstn,
    input                   start,
    output                  ram_rd_req,
    input                   ram_rd_ack,
    input   [31:0]          ram_rdata
);
// signals
reg [31:0] d0, d1;
reg fill_flag; reg [1:0] fill_flag_dly; wire fill_flag_sync;
reg toggle; reg [2:0] toggle_dly; wire tx_free_sync;
reg ram_rd_req_d1, ram_rd_ack_d1;
always @(posedge hclk or negedge hrstn)
    if (~hrstn) begin
        ram_rd_req_d1 <= 0;
        ram_rd_ack_d1 <= 0;
    end
    else begin
        ram_rd_req_d1 <= ram_rd_req;
        ram_rd_ack_d1 <= ram_rd_ack;
    end
// hclk clock domain
always @(posedge hclk)
    //if (fill_flag == 0 && ram_rd_req_d1 == 1 && ram_rd_ack_d1 == 1) // no need fill_flag, bugfix????
    if (ram_rd_req_d1 == 1 && ram_rd_ack_d1 == 1)
        d0 <= ram_rdata;
always @(posedge hclk or negedge hrstn)
    if (~hrstn)
        fill_flag <= 0;
    else if (start) // init
        fill_flag <= 0;
    else if (fill_flag == 0 && ram_rd_req & ram_rd_ack)
        fill_flag <= 1;
    else if (fill_flag == 1 && tx_free_sync == 1)
        fill_flag <= 0;
assign ram_rd_req = ~fill_flag; // may read more data, tbd!!!
// tx_free, cross domain
always @(posedge psram_clk or negedge psram_rstn)
    if (~psram_rstn)
        toggle <= 0;
    else if (tx_free)
        toggle <= ~toggle;
always @(posedge hclk or negedge hrstn)
    if (~hrstn)
        toggle_dly <= 0;
    else
        toggle_dly <= {toggle_dly[1:0], toggle};
assign tx_free_sync = toggle_dly[2] ^ toggle_dly[1];
// cross clock domain
always @(posedge psram_clk or negedge psram_rstn)
    if (~psram_rstn)
        fill_flag_dly <= 0;
    else if (psram_start)
        fill_flag_dly <= 0;
    else
        fill_flag_dly <= {fill_flag_dly[0], fill_flag};
assign fill_flag_sync = fill_flag_dly[1];
assign tx_vld = fill_flag_sync;
assign tx_data = d0;

endmodule

