module mem (
    input                       clk,
    input                       ram_wr_req,
    output                      ram_wr_ack,
    input                       ram_rd_req,
    output                      ram_rd_ack,
    input       [16:0]          ram_addr,
    input       [31:0]          ram_wdata,
    output reg  [31:0]          ram_rdata
);
// mem
reg [31:0] mem [2**17-1:0];
// wr
always @(posedge clk) begin
    if (ram_wr_req) begin
        mem[ram_addr] <= ram_wdata;
    end
    if (ram_rd_req) begin
        ram_rdata <= mem[ram_addr];
    end
end
// ack
assign ram_rd_ack = ram_rd_req;
assign ram_wr_ack = ram_wr_req;

endmodule

