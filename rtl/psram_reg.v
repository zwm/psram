module psram_reg (
    input                       rstn,
    input                       clk,
    input                       ahb_bus_sel,
    input                       ahb_bus_wr,
    input                       ahb_bus_rd,
    input           [ 3:0]      ahb_bus_addr,
    input           [ 3:0]      ahb_bus_bsel,
    input           [31:0]      ahb_bus_wdata,
    output reg      [31:0]      ahb_bus_rdata,
    // reg
    output reg                  dma_en,
    output reg                  task_load,
    output reg                  task_add,
    output reg                  task_remove,
    output reg      [7:0]       task_val,
    output reg      [2:0]       task_max,
    input           [7:0]       task_list,
    output reg      [`RAM_WIDTH-1:0]      task_table_addr,
    output reg      [31:0]      task_trig,
    output reg      [7:0]       irq_en,
    output reg      [7:0]       irq_clr,
    input           [7:0]       irq_status
);

// 0: DMA_CTRL
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        task_max <= 0;
        dma_en <= 0;
        task_val <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 0)) begin
        if (ahb_bus_bsel[2]) begin // [23:16]
            task_max <= ahb_bus_wdata[22:20];
            dma_en <= ahb_bus_wdata[19];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            task_val <= ahb_bus_wdata[15:8];
        end
    end
always @(*) begin
    task_remove = ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 0) & ahb_bus_bsel[2] & ahb_bus_wdata[18];
    task_add = ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 0) & ahb_bus_bsel[2] & ahb_bus_wdata[17];
    task_load = ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 0) & ahb_bus_bsel[2] & ahb_bus_wdata[16];
end
// 1: DMA_TABLE
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        task_table_addr <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 1)) begin
        if (ahb_bus_bsel[2]) begin // [23:16]
            task_table_addr[`RAM_WIDTH-1:16] <= ahb_bus_wdata[`RAM_WIDTH-1:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            task_table_addr[15:8] <= ahb_bus_wdata[15:8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            task_table_addr[7:0] <= ahb_bus_wdata[7:0];
        end
    end
// 2: TRIG_SRC
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        task_trig <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 2)) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            task_trig[31:24] <= ahb_bus_wdata[31:24];
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            task_trig[23:16] <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            task_trig[15:8] <= ahb_bus_wdata[15:8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            task_trig[7:0] <= ahb_bus_wdata[7:0];
        end
    end
// 3: IRQ
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        irq_clr <= 0;
        irq_en <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 3)) begin
        if (ahb_bus_bsel[2]) begin // [23:16]
            irq_clr[7:0] <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            irq_en[7:0] <= ahb_bus_wdata[15:8];
        end
    end
// read
always @(*) begin
    // init
    ahb_bus_rdata = 0;
    // update
    if (ahb_bus_sel & ahb_bus_rd) begin
        case (ahb_bus_addr)
            0: ahb_bus_rdata = { 9'h0,              // [31:23]
                                 task_max,          // [22:20]
                                 dma_en,            // [19]
                                 task_remove,       // [18]
                                 task_add,          // [17]
                                 task_load,         // [16]
                                 task_val,          // [15:8]
                                 task_list};        // [7:0]
            1: ahb_bus_rdata = { 15'h0,             // [31:17]
                                 task_table_addr};  // [16:0]
            2: ahb_bus_rdata = { task_trig };       // [31:0]
            3: ahb_bus_rdata = { 8'h0,              // [31:24]
                                 irq_clr,           // [23:16]
                                 irq_en,            // [15:8]
                                 irq_status};       // [7:0]
            default: ahb_bus_rdata = 0;
        endcase
    end
end

endmodule

