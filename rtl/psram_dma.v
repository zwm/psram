module psram_dma (
    // sys
    input                   rstn,
    input                   clk,
    // reg
    input                   dma_en,
    input                   task_load,
    input                   task_add,
    input                   task_remove,
    input       [7:0]       task_val,
    output reg  [7:0]       task_list,
    input       [2:0]       task_max,
    input       [`RAM_WIDTH-1:0] task_table_addr,
    input       [31:0]      task_trig,
    input       [7:0]       irq_en,
    input       [7:0]       irq_clr,
    output reg  [7:0]       irq_status,
    // ctrl
    input       [15:0]      trig_src,
    output reg  [31:0]      cfg0,
    output reg  [31:0]      cfg1,
    output reg  [31:0]      cfg2,
    output reg  [31:0]      cfg3,
    output reg              start,
    input                   done,
    output                  irq,
    // mem 
    output reg              ram_rd_req,
    input                   ram_rd_ack,
    output reg  [`RAM_WIDTH-1:0] ram_addr,
    input       [31:0]      ram_rdata
);
// Macro
localparam IDLE             = 4'h0;
localparam SCAN             = 4'h1;
localparam RDCFG            = 4'h2;
localparam TRANS            = 4'h3;
localparam END              = 4'h4;
reg [3:0] st_curr, st_next;
wire [7:0] task_clr;
reg [2:0] cnt; reg [1:0] cfg_cnt;
wire chain_en; wire [`RAM_WIDTH-1:0] task_chain_addr;
// sync
always @(posedge clk or negedge rstn)
    if (~rstn)
        st_curr <= IDLE;
    else if (dma_en)
        st_curr <= st_next;
    else
        st_curr <= IDLE;
// comb
always @(*) begin
    // init
    st_next = st_curr;
    // update
    case (st_curr)
        IDLE: begin
            if (dma_en)
                st_next = SCAN;
        end
        SCAN: begin
            if (task_list[cnt])
                st_next = RDCFG;
        end
        RDCFG: begin
            if (ram_rd_req & ram_rd_ack & cfg_cnt == 2'b11)
                st_next = TRANS;
        end
        TRANS: begin
            if (done) begin
                if (chain_en)
                    st_next = RDCFG;
                else
                    st_next = END;
            end
        end
        END: begin
            if (dma_en)
                st_next = SCAN;
        end
        default: begin
            st_next = IDLE;
        end
    endcase
    // reset
    if (~dma_en) st_next = IDLE;
end
// dout, tbd!!! ???
reg ram_rd_req_d1;
reg ram_rd_ack_d1;
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        ram_rd_req_d1 <= 0;
        ram_rd_ack_d1 <= 0;
    end
    else begin
        ram_rd_req_d1 <= ram_rd_req;
        ram_rd_ack_d1 <= ram_rd_ack;
    end
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        cfg0 <= 0; cfg1 <= 0; cfg2 <= 0; cfg3 <= 0;
    end
    else if (st_curr == SCAN && st_next == RDCFG) begin
        cfg0 <= 0; cfg1 <= 0; cfg2 <= 0; cfg3 <= 0;
    end
    else if (st_curr == RDCFG || st_next == TRANS) begin
        if (ram_rd_req_d1 & ram_rd_ack_d1)
            {cfg0, cfg1, cfg2, cfg3} <= {cfg1, cfg2, cfg3, ram_rdata};
    end
// behave
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        cnt <= 0;
        cfg_cnt <= 0;
        ram_rd_req <= 0;
        ram_addr <= 0;
    end
    else begin
        case (st_curr)
            IDLE: begin
                cnt <= 0;
                cfg_cnt <= 0;
                ram_rd_req <= 0;
            end
            SCAN: begin
                if (task_list[cnt]) begin
                    ram_rd_req <= 1;
                    ram_addr <= task_table_addr + {{(`RAM_WIDTH-5){1'b0}}, cnt[2:0], 2'b00}; // task entrance port, tbd, lsb 2 bits can not set to 0 ???
                end
                else begin
                    if (cnt == task_max)
                        cnt <= 0;
                    else
                        cnt <= cnt + 1;
                end
            end
            RDCFG: begin
                if (ram_rd_ack) begin // latch data
                    cfg_cnt <= cfg_cnt + 1;
                    ram_addr <= ram_addr + 1; // tbd
                end
                if (ram_rd_ack && cfg_cnt == 2'b11) begin
                    ram_rd_req <= 0;
                end
            end
            TRANS: begin
                if (done & chain_en) begin // init cfg addr
                    ram_rd_req <= 1;
                    ram_addr <= task_chain_addr; // chain addr
                end
            end
            END: begin
                if (~dma_en) begin
                    cnt <= cnt + 1;
                end
            end
            default: begin
                cnt <= 0;
            end
        endcase
    end
always @(posedge clk or negedge rstn)
    if (~rstn)
        start <= 0;
    else
        start <= st_curr == TRANS && ram_rd_req_d1 && ram_rd_ack_d1; // tbd, do not start before cfg all out!!!
// cfg3 parse
assign chain_en = cfg3[0];
assign task_chain_addr = cfg3[`RAM_WIDTH:1];
// task_list & irq
genvar i;
generate
    for (i=0; i<8; i=i+1)
    begin: TL_IRQ
        // clr
        assign task_clr[i] = (st_curr == END) && (cnt == i);
        // list
        always @(posedge clk or negedge rstn)
            if (~rstn)
                task_list[i] <= 0;
            else if (dma_en == 0)
                task_list[i] <= 0;
            else if (((task_load | task_add) & task_val[i]) || trig_src[task_trig[(i+1)*4-1:i*4]])
                task_list[i] <= 1;
            else if ((task_remove & task_val[i]) || task_clr[i])
                task_list[i] <= 0;
        // irq_status
        always @(posedge clk or negedge rstn)
            if (~rstn)
                irq_status[i] <= 0;
            else if (dma_en == 0)
                irq_status[i] <= 0;
            else if (task_clr[i])
                irq_status[i] <= 1;
            else if (irq_clr[i])
                irq_status[i] <= 0;
    end
endgenerate
// output
assign irq = |(irq_en & irq_status);

endmodule

