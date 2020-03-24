
module tb_top();
// macro
`include "tb_define.v"
// port
reg rstn, hclk; wire dcmi_irq;
reg ahb_bus_sel; reg ahb_bus_wr; reg ahb_bus_rd; reg [ 3:0] ahb_bus_addr;
reg [ 3:0] ahb_bus_bsel; reg [31:0] ahb_bus_wdata; wire [31:0] ahb_bus_rdata;
wire ram_wr_req; reg ram_wr_ack; wire [23:0] ram_waddr; wire [31:0] ram_wdata;
// dcmi
reg dcmi_mclk; wire dcmi_pclk, dcmi_vsync, dcmi_hsync; wire [13:0] dcmi_data; reg dcmi_pwdn;
// reg
reg block_en;
reg capture_en;
reg man_mode;
reg snapshot_mode;
reg crop_en;
reg jpeg_en;
reg embd_sync_en;
reg pclk_polarity;
reg hsync_polarity;
reg vsync_polarity;
reg [1:0] data_bus_width; // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
reg [1:0] frame_sel_mode; // 00: all, 01: 1/2, 10: 1/4, 11: reserved
reg [1:0] byte_sel_mode; // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
reg line_sel_mode;       // 0: all, 1: 1/2
reg byte_sel_start;      // 0: 1st, 1: 2nd
reg line_sel_start;      // 0: 1st, 1: 2nd
reg [7:0] fsc, fec, lsc, lec;
reg [7:0] fsu, feu, lsu, leu;
reg [12:0] line_crop_start;
reg [13:0] pixel_crop_start;
reg [13:0] line_crop_size;
reg [13:0] pixel_crop_size;
reg [17:0] dma_saddr, dma_len;
// reg
wire [31:0] dcmi_cr, dcmi_escr, dcmi_esur, dcmi_cwstrt, dcmi_cwsize, dcmi_dma_addr;

// main
initial begin
    sys_init;
    #50_000;
    rstn = 1;
    dcmi_pwon;
    reg_init;
    set_regs;
    repeat (10) @(posedge dcmi_pclk);
    set_block_en(1);
    reg_write(0, dcmi_cr);
    repeat (10) @(posedge dcmi_pclk);
    set_capture_en(1);
    reg_write(0, dcmi_cr);
    repeat (10) @(posedge dcmi_pclk);
    set_capture_en(0);
    reg_write(0, dcmi_cr);
    #1000_000;
    $finish;
end
dcmi_top u_dcmi_top (
    .rstn               ( rstn              ),
    .hclk               ( hclk              ),
    .dcmi_pclk          ( dcmi_pclk         ),
    .dcmi_vsync         ( dcmi_vsync        ),
    .dcmi_hsync         ( dcmi_hsync        ),
    .dcmi_data          ( dcmi_data         ),
    .ahb_bus_sel        ( ahb_bus_sel       ),
    .ahb_bus_wr         ( ahb_bus_wr        ),
    .ahb_bus_rd         ( ahb_bus_rd        ),
    .ahb_bus_addr       ( ahb_bus_addr      ),
    .ahb_bus_bsel       ( ahb_bus_bsel      ),
    .ahb_bus_wdata      ( ahb_bus_wdata     ),
    .ahb_bus_rdata      ( ahb_bus_rdata     ),
    .dcmi_irq           ( dcmi_irq          ),
    .ram_wr_req         ( ram_wr_req        ),
    .ram_wr_ack         ( ram_wr_ack        ),
    .ram_waddr          ( ram_waddr         ),
    .ram_wdata          ( ram_wdata         )
);
// inst camera
camera_dcmi u_camera (
    .dcmi_pwdn          ( dcmi_pwdn         ),
    .dcmi_mclk          ( dcmi_mclk         ),
    .dcmi_pclk          ( dcmi_pclk         ),
    .dcmi_vsync         ( dcmi_vsync        ),
    .dcmi_hsync         ( dcmi_hsync        ),
    .dcmi_data          ( dcmi_data         )
);
// fsdb
`ifdef DUMP_FSDB
initial begin
    $fsdbDumpfile("tb_top.fsdb");
    $fsdbDumpvars(0, tb_top);
end
`endif

task sys_init;
    begin
        rstn = 0;
        ram_wr_ack = 1;
        ahb_bus_sel = 0;
        ahb_bus_wr = 0;
        ahb_bus_rd = 0;
        ahb_bus_addr = 0;
        ahb_bus_bsel = 0;
        ahb_bus_wdata = 0;
        block_en = 0;
        capture_en = 0;
        man_mode = 0;
        snapshot_mode = 0;
        snapshot_mode = 0;
        crop_en = 0;
        jpeg_en = 0;
        embd_sync_en = 0;
        pclk_polarity = 0;
        hsync_polarity = 0;
        vsync_polarity = 0;
        data_bus_width = 0;         // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
        frame_sel_mode = 0;      // 00: all, 01: 1/2, 10: 1/4, 11: reserved
        byte_sel_mode = 0;       // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
        line_sel_mode = 0;       // 0: all, 1: 1/2
        byte_sel_start = 0;      // 0: 1st, 1: 2nd
        line_sel_start = 0;      // 0: 1st, 1: 2nd
        fsc = 0;
        fec = 0;
        lsc = 0;
        lec = 0;
        fsu = 0;
        feu = 0;
        lsu = 0;
        leu = 0;
        line_crop_start = 0;
        pixel_crop_start = 0;
        line_crop_size = 0;
        pixel_crop_size = 0;
        dcmi_pwdn = 0;
    end
endtask

task reg_init;
    begin
        block_en = 0;
        capture_en = 0;
        man_mode = 0;
        snapshot_mode = 1;
        crop_en = 0;
        jpeg_en = 0;
        embd_sync_en = 0;
        pclk_polarity = 0;
        hsync_polarity = 0;
        vsync_polarity = 0;
        data_bus_width = 0;         // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
        frame_sel_mode = 0;      // 00: all, 01: 1/2, 10: 1/4, 11: reserved
        byte_sel_mode = 0;       // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
        line_sel_mode = 0;       // 0: all, 1: 1/2
        byte_sel_start = 0;      // 0: 1st, 1: 2nd
        line_sel_start = 0;      // 0: 1st, 1: 2nd
        fsc = 0;
        fec = 0;
        lsc = 0;
        lec = 0;
        fsu = 0;
        feu = 0;
        lsu = 0;
        leu = 0;
        line_crop_start = 1;
        pixel_crop_start = 1;
        line_crop_size = 10;
        pixel_crop_size = 20;
        dma_saddr = 0;
        dma_len = 100;
    end
endtask

task set_block_en;
    input val;
    begin
        block_en = val;
    end
endtask

task set_capture_en;
    input val;
    begin
        capture_en = val;
    end
endtask

task dcmi_pwon;
    begin
        dcmi_pwdn = 1;
        #1000;
        dcmi_pwdn = 0;
    end
endtask

initial begin
    dcmi_mclk = 0;
    hclk = 0;
    fork
        forever #(100/2) dcmi_mclk = ~dcmi_mclk;
        forever #(6/2) hclk = ~hclk;
    join
end

// reg assign
assign dcmi_cr =               { 11'h0,             // [31:21]
                                line_sel_start,     // [20]
                                line_sel_mode,      // [19]
                                byte_sel_start,     // [18]
                                byte_sel_mode,      // [17:16]
                                man_mode,           // [15]
                                block_en,           // [14]
                                2'h0,               // [13:12]
                                data_bus_width,     // [11:10]
                                frame_sel_mode,     // [9:8]
                                vsync_polarity,     // [7]
                                hsync_polarity,     // [6]
                                pclk_polarity,      // [5]
                                embd_sync_en,       // [4]
                                jpeg_en,            // [3]
                                crop_en,            // [2]
                                snapshot_mode,      // [1]
                                capture_en};        // [0]
assign dcmi_escr             = {fec,                // [31:24]
                                lec,                // [23:16]
                                lsc,                // [15:8]
                                fsc};               // [7:0]
assign dcmi_esur             = {feu,                // [31:24]
                                leu,                // [23:16]
                                lsu,                // [15:8]
                                fsu};               // [7:0]
assign dcmi_cwstrt           = {dma_saddr[17:16],  // [31:30]
                                line_crop_start,    // [29:16]
                                dma_len[17:16],    // [15:14]
                                pixel_crop_start};  // [13:0]
assign dcmi_cwsize           = {2'h0,               // [31:30]
                                line_crop_size,     // [29:16]
                                2'h0,               // [15:14]
                                pixel_crop_size};   // [13:0]
assign dcmi_dma_addr         =  {dma_saddr[15:0],  // [31:16]
                                 dma_len[15:0]};   // [15:0]

task reg_write;
    input [3:0] addr;
    input [31:0] val;
    begin
        @(posedge hclk) begin
            ahb_bus_sel <= 1;
            ahb_bus_rd <= 0;
            ahb_bus_wr <= 1;
            ahb_bus_addr <= addr;
            ahb_bus_wdata <= val;
            ahb_bus_bsel <= 4'hf;
        end
        @(posedge hclk) begin
            ahb_bus_sel <= 0;
            ahb_bus_wr <= 0;
            ahb_bus_bsel <= 4'h0;
        end
    end
endtask

task reg_read;
    input [3:0] addr;
    output [31:0] val;
    begin
        @(posedge hclk) begin
            ahb_bus_sel <= 1;
            ahb_bus_rd <= 1;
            ahb_bus_wr <= 0;
            ahb_bus_addr <= addr;
        end
        @(posedge hclk) begin
            ahb_bus_sel <= 0;
            ahb_bus_rd <= 0;
            val <= ahb_bus_rdata;
        end
    end
endtask

task set_regs;
    begin
        reg_write(0, dcmi_cr);
        reg_write(6, dcmi_escr);
        reg_write(7, dcmi_esur);
        reg_write(8, dcmi_cwstrt);
        reg_write(9, dcmi_cwsize);
        reg_write(12, dcmi_dma_addr);
    end
endtask

endmodule
