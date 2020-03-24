
module psram_clk (
    input rstn,
    input clk,
    input sck_en,
    input sck_pause,
    input [3:0] sck_div,
    output sck_neg,
    output sck_pos, // due to clk delay, use sck_pos will cause read date earlier than we want, may cause problems!!!
    output reg sck
);

// signals
reg [1:0] cnt; wire [1:0] hi_div, lo_div;
// alias
assign lo_div = sck_div[1:0];
assign hi_div = sck_div[3:2];
// output
assign sck_neg = (sck_pause == 0) && (sck == 1) && (cnt == hi_div);
assign sck_pos = (sck_pause == 0) && (sck == 0) && (cnt == lo_div);
// cnt & sck
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        cnt <= 0;
        sck <= 0;
    end
    else if (sck_en) begin
        if (~sck_pause) begin
            if (sck == 0 && cnt == lo_div) begin
                sck <= 1;
                cnt <= 0;
            end
            else if (sck == 1 && cnt == hi_div) begin
                sck <= 0;
                cnt <= 0;
            end
            else begin
                cnt <= cnt + 1;
            end
        end
    end
    else begin // disable
        cnt <= 0;
        sck <= 0;
    end

endmodule

