
module tb_top();
// macro
`include "tb_define.v"
// port
reg hrstn, hclk; wire irq;
reg psram_clk, psram_rstn; reg [15:0] trig_src;
wire ncs, sck; wire [3:0] do, do_en; reg [3:0] di;
reg ahb_bus_sel; reg ahb_bus_wr; reg ahb_bus_rd; reg [ 3:0] ahb_bus_addr;
reg [ 3:0] ahb_bus_bsel; reg [31:0] ahb_bus_wdata; wire [31:0] ahb_bus_rdata;
wire ram_wr_req, ram_wr_ack; wire [31:0] ram_wdata;
wire ram_rd_req, ram_rd_ack; wire [31:0] ram_rdata; wire [16:0] ram_addr;
wire psram_ram_wr_req, psram_ram_wr_ack; wire [31:0] psram_ram_wdata;
wire psram_ram_rd_req, psram_ram_rd_ack; wire [31:0] psram_ram_rdata; wire [16:0] psram_ram_addr;
// host
reg host_ram_wr_req; wire host_ram_wr_ack; reg [31:0] host_ram_wdata;
reg host_ram_rd_req; wire host_ram_rd_ack; wire [31:0]  host_ram_rdata; reg [16:0] host_ram_addr;
// reg
reg dma_en, task_load, task_add, task_remove;
reg [7:0] task_val;
reg [2:0] task_max;
reg [16:0] task_table_addr;
reg [31:0] task_trig;
reg [7:0] irq_en, irq_clr;
reg [31:0] dbg_reg;
reg [31:0] dbg_cnt;
// task_val
task set_task_val;
    input [7:0] val;
    reg [31:0] tmp;
    begin
        reg_read(0, tmp);
        tmp = {tmp[31:16], val[7:0], tmp[7:0]};
        reg_write(0, tmp);
    end
endtask
// dma_en
task set_dma_en;
    input val;
    reg [31:0] tmp;
    begin
        reg_read(0, tmp);
        #100;
        dbg_reg = tmp;
        dbg_cnt = 1;
        tmp = {tmp[31:20], val, tmp[18:0]};
        #100;
        dbg_reg = tmp;
        dbg_cnt = 2;
        reg_write(0, tmp);
    end
endtask
// task_load
task set_task_load;
    input val;
    reg [31:0] tmp;
    begin
        reg_read(0, tmp);
        tmp = {tmp[31:17], val, tmp[15:0]};
        reg_write(0, tmp);
    end
endtask
// task_max
task set_task_max;
    input [2:0] val;
    reg [31:0] tmp;
    begin
        reg_read(0, tmp);
        tmp = {tmp[31:23], val, tmp[19:0]};
        reg_write(0, tmp);
    end
endtask
// task_table
task set_task_table;
    input [16:0] val;
    reg [31:0] tmp;
    begin
        tmp = {15'h0, val};
        reg_write(1, tmp);
    end
endtask
// task
task set_task;
    begin
        set_dma_en(1);
        set_task_max(7);
        set_task_table(17'h10000);
        set_task_val(8'h03);
        set_task_load(1);
    end
endtask
// ram
task set_ram;
    integer i;
    begin
        // task 0, write 6 bytes
        ram_write(17'h10000, 32'h000C_08E0); // write 6 bytes, wait 7 cycles
        ram_write(17'h10001, 32'h1234_56AA); // cmd: aa, addr: 0x123456
        ram_write(17'h10002, 32'h0080_0100); // saddr: 0x0100, len: 64
        ram_write(17'h10003, 32'h0000_0000); // chain_en: 0
        for(i=0; i<20; i=i+1)
            ram_write(17'h0_0100 + i, 32'h5555_aaaa);
        // task 1, read 6 bytes
        ram_write(17'h10004, 32'h000C_00E0); // write 6 bytes, wait 7 cycles
        ram_write(17'h10005, 32'h1234_56AA); // cmd: aa, addr: 0x123456
        ram_write(17'h10006, 32'h0080_0200); // saddr: 0x0200, len: 64
        ram_write(17'h10007, 32'h0000_0000); // chain_en: 0
        for(i=0; i<20; i=i+1)
            ram_write(17'h0_0100 + i, 32'h5555_aaaa);
    end
endtask

// clk gen
initial begin
    psram_clk = 0;
    hclk = 0;
    fork
        forever #(10/2) psram_clk = ~psram_clk;
        forever #(6/2) hclk = ~hclk;
    join
end

// main
initial begin
    sys_init;
    por;
    #50_000;
    set_ram;
    set_task;
    #1000_000;
    $finish;
end
// inst psram
psram_top u_psram_inf (
    .psram_clk          ( psram_clk         ),
    .psram_rstn         ( psram_rstn        ),
    .hclk               ( hclk              ),
    .hrstn              ( hrstn             ),
    .ahb_bus_sel        ( ahb_bus_sel       ),
    .ahb_bus_wr         ( ahb_bus_wr        ),
    .ahb_bus_rd         ( ahb_bus_rd        ),
    .ahb_bus_addr       ( ahb_bus_addr      ),
    .ahb_bus_bsel       ( ahb_bus_bsel      ),
    .ahb_bus_wdata      ( ahb_bus_wdata     ),
    .ahb_bus_rdata      ( ahb_bus_rdata     ),
    .ncs                ( ncs               ),
    .sck                ( sck               ),
    .do                 ( do                ),
    .do_en              ( do_en             ),
    .di                 ( di                ),
    .ram_wr_req         ( psram_ram_wr_req  ),
    .ram_wr_ack         ( psram_ram_wr_ack  ),
    .ram_rd_req         ( psram_ram_rd_req  ),
    .ram_rd_ack         ( psram_ram_rd_ack  ),
    .ram_addr           ( psram_ram_addr    ),
    .ram_wdata          ( psram_ram_wdata   ),
    .ram_rdata          ( psram_ram_rdata   ),
    .trig_src           ( trig_src          ),
    .irq                ( irq               )
);
// inst psram
// ram
// mux
assign ram_wr_req = psram_ram_wr_req | host_ram_wr_req;
assign ram_rd_req = psram_ram_rd_req | host_ram_rd_req;
assign ram_addr = (psram_ram_wr_req | psram_ram_rd_req) ? psram_ram_addr : host_ram_addr;
assign ram_wdata = psram_ram_wr_req ? psram_ram_wdata : host_ram_wdata;
assign psram_ram_rdata = ram_rdata;
assign psram_ram_rd_ack = ram_rd_ack;
assign psram_ram_wr_ack = ram_wr_ack;
assign host_ram_rdata = ram_rdata;
assign host_ram_rd_ack = ram_rd_ack;
assign host_ram_wr_ack = ram_wr_ack;
// inst
mem u_ram (
    .clk                ( hclk              ),
    .ram_wr_req         ( ram_wr_req        ),
    .ram_wr_ack         ( ram_wr_ack        ),
    .ram_rd_req         ( ram_rd_req        ),
    .ram_rd_ack         ( ram_rd_ack        ),
    .ram_addr           ( ram_addr          ),
    .ram_wdata          ( ram_wdata         ),
    .ram_rdata          ( ram_rdata         )
);

// fsdb
`ifdef DUMP_FSDB
initial begin
    $fsdbDumpfile("tb_top.fsdb");
    $fsdbDumpvars(0, tb_top);
end
`endif
// sys_init
task sys_init;
    begin
        hrstn = 0;
        psram_rstn = 0;
        ahb_bus_sel = 0;
        ahb_bus_wr = 0;
        ahb_bus_rd = 0;
        ahb_bus_addr = 0;
        ahb_bus_bsel = 0;
        ahb_bus_wdata = 0;
        host_ram_rd_req  = 0;
        host_ram_wr_req  = 0;
        host_ram_addr = 0;
        host_ram_wdata = 0;
        di = 0;
        dbg_cnt = 0;
        dbg_reg = 0;
    end
endtask
// por
task por;
    begin
        #500_000;
        fork
            begin: HCLK
                repeat(10) @(posedge hclk); #1;
                hrstn = 1;
            end
            begin: PSRAM_CLK
                repeat(10) @(posedge psram_clk); #1;
                psram_rstn = 1;
            end
        join
    end
endtask
// reg_write
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
// reg_read
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
        #1; // must add delay to get output
    end
endtask
// ram_write
task ram_write;
    input [16:0] addr;
    input [31:0] val;
    begin
        @(posedge hclk) begin
            host_ram_wr_req  <= 1;
            host_ram_addr <= addr;
            host_ram_wdata <= val;
            dbg_reg = addr;
            dbg_cnt = dbg_cnt + 1;
        end
        begin: LP_WAIT_ACK
            while(1) begin
                @(posedge hclk) begin
                    if (host_ram_wr_ack) begin
                        host_ram_wr_req  <= 0;
                        disable LP_WAIT_ACK;
                    end
                end
            end
        end
        #1; // must add delay to get output
    end
endtask
// ram_read
task ram_read;
    input [3:0] addr;
    output [31:0] val;
    begin
        @(posedge hclk) begin
            host_ram_rd_req  <= 1;
            host_ram_addr <= addr;
        end
        begin: LP_WAIT_ACK
            while(1) begin
                @(posedge hclk) begin
                    if (host_ram_rd_ack) begin
                        host_ram_rd_req  <= 0;
                        val <= ram_rdata;
                        disable LP_WAIT_ACK;
                    end
                end
            end
        end
        #1; // must add delay to get output
    end
endtask

endmodule

