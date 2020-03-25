module psram_trx (
    // sys
    input                       psram_clk,
    input                       psram_rstn,
    input                       hclk,
    input                       hrstn,
    input                       start,
    output                      done,
    input           [31:0]      cfg0,
    input           [31:0]      cfg1,
    input           [31:0]      cfg2,
    input           [31:0]      cfg3,
    // qspi
    output                      ncs,
    output                      sck,
    input           [3:0]       di,
    output          [3:0]       do,
    output          [3:0]       do_en,
    // mem
    output                      ram_wr_req,
    input                       ram_wr_ack,
    output                      ram_rd_req,
    input                       ram_rd_ack,
    output reg      [`RAM_WIDTH-1:0]      ram_addr,
    output          [31:0]      ram_wdata,
    input           [31:0]      ram_rdata
);
// cfg0
wire    [14:0]      data_len;
wire    [3:0]       sck_div;
wire                single_line_io_mode;
wire                data_dir;
wire    [1:0]       data_width;
wire    [3:0]       wait_cyc;
wire    [1:0]       addr_width;
wire                cmd_only;
wire    [1:0]       cmd_width;
// cfg1
wire    [23:0]      addr;
wire    [7:0]       cmd;
// cfg2
wire    [14:0]      dma_len;
wire    [`RAM_WIDTH-1:0] dma_saddr;
// internal signals
wire start_psram, done_psram;
wire tx_vld, tx_free; wire [31:0] tx_data;
wire rx_vld, rx_rdy; wire [31:0] rx_data;
// start, hclk to psram
psync2 u_psync_start2psram (
    .srstn      ( hrstn         ),
    .sclk       ( hclk          ),
    .sin        ( start         ),
    .drstn      ( psram_rstn    ),
    .dclk       ( psram_clk     ),
    .dout       ( start_psram   )
);
// done, psram to hclk
psync2 u_psync_done2hclk (
    .srstn      ( psram_rstn    ),
    .sclk       ( psram_clk     ),
    .sin        ( done_psram    ),
    .drstn      ( hrstn         ),
    .dclk       ( hclk          ),
    .dout       ( done          )
);
// psram ctrl
psram_cfg_parse u_psram_cfg_parse (
    .cfg0                   ( cfg0                  ),
    .cfg1                   ( cfg1                  ),
    .cfg2                   ( cfg2                  ),
    .cfg3                   ( cfg3                  ),
    .data_len               ( data_len              ),
    .sck_div                ( sck_div               ),
    .single_line_io_mode    ( single_line_io_mode   ),
    .data_dir               ( data_dir              ),
    .data_width             ( data_width            ),
    .wait_cyc               ( wait_cyc              ),
    .addr_width             ( addr_width            ),
    .cmd_only               ( cmd_only              ),
    .cmd_width              ( cmd_width             ),
    .addr                   ( addr                  ),
    .cmd                    ( cmd                   ),
    .dma_len                ( dma_len               ),
    .dma_saddr              ( dma_saddr             )
);
// psram ctrl
psram_ctrl u_psram_ctrl (
    .rstn                   ( psram_rstn            ),
    .clk                    ( psram_clk             ),
    .ncs                    ( ncs                   ),
    .sck                    ( sck                   ),
    .di                     ( di                    ),
    .do                     ( do                    ),
    .do_en                  ( do_en                 ),
    .start                  ( start_psram           ),
    .cmd                    ( cmd                   ),
    .cmd_only               ( cmd_only              ),
    .cmd_width              ( cmd_width             ),
    .addr                   ( addr                  ),
    .addr_width             ( addr_width            ),
    .wait_cyc               ( wait_cyc              ),
    .data_dir               ( data_dir              ),
    .data_len               ( data_len              ),
    .data_width             ( data_width            ),
    .single_line_io_mode    ( single_line_io_mode   ),
    .sck_div                ( sck_div               ),
    .tx_vld                 ( tx_vld                ),
    .tx_data                ( tx_data               ),
    .tx_free                ( tx_free               ),
    .rx_rdy                 ( rx_rdy                ),
    .rx_vld                 ( rx_vld                ),
    .rx_data                ( rx_data               ),
    .done                   ( done_psram            )
);
// txbuf
psram_tx_buf u_txbuf (
    .psram_rstn             ( psram_rstn            ),
    .psram_clk              ( psram_clk             ),
    .psram_start            ( start_psram           ),
    .tx_free                ( tx_free               ),
    .tx_vld                 ( tx_vld                ),
    .tx_data                ( tx_data               ),
    .hclk                   ( hclk                  ),
    .hrstn                  ( hrstn                 ),
    .start                  ( start                 ),
    .ram_rd_req             ( ram_rd_req            ),
    .ram_rd_ack             ( ram_rd_ack            ),
    .ram_rdata              ( ram_rdata             )
);
// rxbuf
psram_rx_buf u_rxbuf (
    .psram_rstn             ( psram_rstn            ),
    .psram_clk              ( psram_clk             ),
    .psram_start            ( start_psram           ),
    .rx_rdy                 ( rx_rdy                ),
    .rx_vld                 ( rx_vld                ),
    .rx_data                ( rx_data               ),
    .hclk                   ( hclk                  ),
    .hrstn                  ( hrstn                 ),
    .start                  ( start                 ),
    .ram_wr_req             ( ram_wr_req            ),
    .ram_wr_ack             ( ram_wr_ack            ),
    .ram_wdata              ( ram_wdata             )
);
// ram_addr, hclk domain
wire tx = data_dir;
wire ram_addr_inc = tx ? (ram_rd_req & ram_rd_ack) : (ram_wr_req & ram_wr_ack); // tbd!!!!
wire [`RAM_WIDTH-1:0] ram_addr_next = (ram_addr == (dma_saddr + dma_len - 1)) ? dma_saddr : (ram_addr + 1);
always @(posedge hclk or negedge hrstn)
    if (~hrstn)
        ram_addr <= 0;
    else if (start)
        ram_addr <= dma_saddr;
    else if (ram_addr_inc)
        ram_addr <= ram_addr_next;

endmodule

