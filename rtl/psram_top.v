
module psram_top (
    // sys
    input                       psram_clk, // 192M ?
    input                       psram_rstn,
    input                       hclk,
    input                       hrstn,
    // ahb
    input                       ahb_bus_sel,
    input                       ahb_bus_wr,
    input                       ahb_bus_rd,
    input           [ 3:0]      ahb_bus_addr,
    input           [ 3:0]      ahb_bus_bsel,
    input           [31:0]      ahb_bus_wdata,
    output          [31:0]      ahb_bus_rdata,
    // qspi
    output                      ncs,
    output                      sck,
    output          [3:0]       do,
    output          [3:0]       do_en,
    input           [3:0]       di,
    // mem
    output                      ram_wr_req,
    input                       ram_wr_ack,
    output                      ram_rd_req,
    input                       ram_rd_ack,
    output  [`RAM_WIDTH-1:0]    ram_addr,
    output  [31:0]              ram_wdata,
    input   [31:0]              ram_rdata,
    // irq
    input           [15:0]      trig_src,
    output                      irq
);
// signals
wire start, done;
wire [31:0] cfg0, cfg1, cfg2, cfg3;
wire dma_en, task_load, task_add, task_remove;
wire [7:0] task_val, task_list, irq_en, irq_clr, irq_status;
wire [2:0] task_max; wire [31:0] task_trig; wire [`RAM_WIDTH-1:0] task_table_addr;
wire dma_rd_req; wire [`RAM_WIDTH-1:0] dma_addr;
wire trx_rd_req; wire [`RAM_WIDTH-1:0] trx_addr;
// ram port mux
assign ram_rd_req = dma_rd_req | trx_rd_req;
assign ram_addr = dma_rd_req ? dma_addr : trx_addr;
// psram_reg
psram_reg u_psram_reg (
    .rstn                   ( hrstn                  ),
    .clk                    ( hclk                   ),
    .ahb_bus_sel            ( ahb_bus_sel            ),
    .ahb_bus_wr             ( ahb_bus_wr             ),
    .ahb_bus_rd             ( ahb_bus_rd             ),
    .ahb_bus_addr           ( ahb_bus_addr           ),
    .ahb_bus_bsel           ( ahb_bus_bsel           ),
    .ahb_bus_wdata          ( ahb_bus_wdata          ),
    .ahb_bus_rdata          ( ahb_bus_rdata          ),
    .dma_en                 ( dma_en                 ),
    .task_load              ( task_load              ),
    .task_add               ( task_add               ),
    .task_remove            ( task_remove            ),
    .task_val               ( task_val               ),
    .task_max               ( task_max               ),
    .task_list              ( task_list              ),
    .task_table_addr        ( task_table_addr        ),
    .task_trig              ( task_trig              ),
    .irq_en                 ( irq_en                 ),
    .irq_clr                ( irq_clr                ),
    .irq_status             ( irq_status             )
);
// psram_dma
psram_dma u_psram_dma (
    .rstn                   ( hrstn                  ),
    .clk                    ( hclk                   ),
    .dma_en                 ( dma_en                 ),
    .task_load              ( task_load              ),
    .task_add               ( task_add               ),
    .task_remove            ( task_remove            ),
    .task_val               ( task_val               ),
    .task_list              ( task_list              ),
    .task_max               ( task_max               ),
    .task_table_addr        ( task_table_addr        ),
    .task_trig              ( task_trig              ),
    .irq_en                 ( irq_en                 ),
    .irq_clr                ( irq_clr                ),
    .irq_status             ( irq_status             ),
    .trig_src               ( trig_src               ),
    .cfg0                   ( cfg0                   ),
    .cfg1                   ( cfg1                   ),
    .cfg2                   ( cfg2                   ),
    .cfg3                   ( cfg3                   ),
    .start                  ( start                  ),
    .done                   ( done                   ),
    .irq                    ( irq                    ),
    .ram_rd_req             ( dma_rd_req             ),
    .ram_rd_ack             ( ram_rd_ack             ),
    .ram_addr               ( dma_addr               ),
    .ram_rdata              ( ram_rdata              )
);
// psram_trx
psram_trx u_psram_trx (
    .psram_clk              ( psram_clk              ),
    .psram_rstn             ( psram_rstn             ),
    .hclk                   ( hclk                   ),
    .hrstn                  ( hrstn                  ),
    .start                  ( start                  ),
    .done                   ( done                   ),
    .cfg0                   ( cfg0                   ),
    .cfg1                   ( cfg1                   ),
    .cfg2                   ( cfg2                   ),
    .cfg3                   ( cfg3                   ),
    .ncs                    ( ncs                    ),
    .sck                    ( sck                    ),
    .di                     ( di                     ),
    .do                     ( do                     ),
    .do_en                  ( do_en                  ),
    .ram_wr_req             ( ram_wr_req             ),
    .ram_wr_ack             ( ram_wr_ack             ),
    .ram_rd_req             ( trx_rd_req             ),
    .ram_rd_ack             ( ram_rd_ack             ),
    .ram_addr               ( trx_addr               ),
    .ram_wdata              ( ram_wdata              ),
    .ram_rdata              ( ram_rdata              )
);

endmodule

