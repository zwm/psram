module psram_ctrl (
    // sys
    input                   rstn,
    input                   clk,
    // qspi port
    output reg              ncs,
    output                  sck, 
    input   [3:0]           di,
    output  [3:0]           do,
    output  [3:0]           do_en,
    // reg
    input                   start, // trigger one transmission
    input   [ 7:0]          cmd,
    input                   cmd_only,
    input   [1:0]           cmd_width,
    input   [23:0]          addr,
    input   [1:0]           addr_width,
    input   [3:0]           wait_cyc,       // 0 to 15
    input                   data_dir,       // 0: read, 1: write
    input   [14:0]          data_len,       // max 512 ?
    input   [1:0]           data_width,
    input                   single_line_io_mode,
    input   [3:0]           sck_div,
    // dma 
    input                   tx_vld,
    input   [31:0]          tx_data,
    output                  tx_free,
    input                   rx_rdy,
    output                  rx_vld,
    output  [31:0]          rx_data,
    output                  done
);
// Macro
localparam      IDLE        = 0;
localparam      TX_CMD      = 1;
localparam      TX_ADDR     = 2;
localparam      WAIT_CYC    = 3;
localparam      TX_DATA     = 4;
localparam      RX_DATA     = 5;
localparam      TRANS_END   = 6;
// signals
reg [3:0] st_curr, st_next;
reg [3:0] out_en;
reg [31:0] shift_reg32;
reg sck_en, sck_pause;
wire sck_pos, sck_neg;
reg [15:0] cnt; reg [2:0] bit_cnt; // use seperate adder is better choice
// cmd
wire [15:0] cnt_max_cmd = cmd_width == 2'b00 ? 7 :     // single mode, 8 cycles
                          cmd_width == 2'b01 ? 3 :     // dual mode, 4 cycles
                                               1 ;     // quad mode, 2 cycles
wire [31:0] shift_reg32_init_cmd = {cmd, 24'h00};
wire [31:0] shift_reg32_next_cmd = cmd_width == 2'b00 ? {shift_reg32[30:0], 1'h0} :
                                   cmd_width == 2'b01 ? {shift_reg32[29:0], 2'h0} :
                                                        {shift_reg32[27:0], 4'h0} ;
wire [3:0] out_en_cmd = cmd_width == 2'b00 ? 4'b0001 :
                        cmd_width == 2'b01 ? 4'b0011 :
                                             4'b1111 ;
// addr
wire [15:0] cnt_max_addr = addr_width == 2'b00 ? 23 :     // single mode
                           addr_width == 2'b01 ? 11 :     // dual mode
                                                 5  ;     // quad mode
wire [31:0] shift_reg32_init_addr = {addr, 8'h00};
wire [31:0] shift_reg32_next_addr = addr_width == 2'b00 ? {shift_reg32[30:0], 1'h0} :
                                    addr_width == 02'b1 ? {shift_reg32[29:0], 2'h0} :
                                                          {shift_reg32[27:0], 4'h0} ;
wire [3:0] out_en_addr = addr_width == 2'b00 ? 4'b0001 :
                         addr_width == 2'b01 ? 4'b0011 :
                                               4'b1111 ;
// wait
wire [15:0] cnt_max_wait = wait_cyc - 1;
wire [31:0] shift_reg32_init_wait = 0;
wire [3:0] out_en_wait = out_en_addr;
// data
wire [15:0] cnt_max_data = {1'b0, data_len}; // tbd, width???
wire tx = data_dir;
wire rx = ~data_dir;
wire [31:0] shift_reg32_init_tx = tx_data;
wire [31:0] shift_reg32_next_tx = data_width == 2'b00 ? {shift_reg32[30:0], 1'h0} :
                                  data_width == 02'b1 ? {shift_reg32[29:0], 2'h0} :
                                                        {shift_reg32[27:0], 4'h0} ;
wire [31:0] shift_reg32_next_rx = data_width == 2'b00 ? (single_line_io_mode ? {shift_reg32[30:0], di[0:0]} : {shift_reg32[30:0], di[1:1]}) :
                                  data_width == 02'b1 ? {shift_reg32[29:0], di[1:0]} :
                                                        {shift_reg32[27:0], di[3:0]} ;
wire [3:0] out_en_tx = data_width == 2'b00 ? 4'b0001 :
                       data_width == 2'b01 ? 4'b0011 :
                                             4'b1111 ;
wire [3:0] out_en_rx = data_width == 2'b00 ? (single_line_io_mode ? 4'b0000 : 4'b0001) :
                                     2'b01 ? 4'b0000 :
                                             4'b0000 ;
wire byte_end = data_width == 2'b00 ? bit_cnt == 3'h7 :
                data_width == 2'b01 ? bit_cnt == 3'h3 :
                                      bit_cnt == 3'h1 ;
// wire word_end = cnt[1:0] == 2'b11;
wire word_end = cnt[1:0] == 2'b11 & byte_end; // bugfix, 20200325
// curr
always @(posedge clk or negedge rstn)
    if (~rstn)
        st_curr <= IDLE;
    else
        st_curr <= st_next;
// next
always @(*) begin
    st_next = st_curr;
    case (st_curr)
        IDLE: begin
            if (start)
                st_next = TX_CMD;
        end
        TX_CMD: begin
            if (sck_neg && cnt == cnt_max_cmd) begin
                if (cmd_only)
                    st_next = TRANS_END;
                else
                    st_next = TX_ADDR;
            end
        end
        TX_ADDR: begin
            if (sck_neg && cnt == cnt_max_addr) begin
                if (wait_cyc == 0) begin
                    if (tx)
                        st_next = TX_DATA;
                    else
                        st_next = RX_DATA;
                end
                else begin
                    st_next = WAIT_CYC;
                end
            end
        end
        WAIT_CYC: begin
            if (sck_neg && cnt == cnt_max_wait) begin
                if (tx)
                    st_next = TX_DATA;
                else
                    st_next = RX_DATA;
            end
        end
        TX_DATA: begin
            if (sck_neg && byte_end && cnt == cnt_max_data) begin
                st_next = TRANS_END;
            end
        end
        RX_DATA: begin
            if ((sck_pause ? 1'b1 : sck_pos) && byte_end && cnt == cnt_max_data && rx_rdy) begin // may delay by bus
                st_next = TRANS_END;
            end
        end
        TRANS_END: begin
            if (rx) begin
                if (rx_rdy) // write finish
                    st_next = IDLE;
            end
            else begin
                st_next = IDLE;
            end
        end
        default: begin
            st_next = IDLE;
        end
    endcase
end
// reg
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        cnt <= 0; // common cnt
        bit_cnt <= 0;
        sck_en <= 0;
        sck_pause <= 0;
        ncs <= 1;
        out_en <= 4'h0;
    end
    else begin
        case (st_curr)
            IDLE: begin
                ncs <= 1;
                sck_en <= 0;
                // out_en <= 4'h0; // out_en ???
                if (start) begin // update cmd
                    cnt <= 0;
                    bit_cnt <= 0;
                    shift_reg32 <= shift_reg32_init_cmd;
                    sck_en <= 1;
                    sck_pause <= 0; // 1 -> 0, 20200325
                    ncs <= 0;
                    out_en <= out_en_cmd;
                end
            end
            TX_CMD: begin
                if (sck_neg) begin
                    if (cnt == cnt_max_cmd) begin // update addr
                        out_en <= out_en_addr;
                        if (cmd_only == 0) begin
                            cnt <= 0;
                            shift_reg32 <= shift_reg32_init_addr;
                        end
                    end
                    else begin
                        cnt <= cnt + 1;
                        shift_reg32 <= shift_reg32_next_cmd;
                    end
                end
            end
            TX_ADDR: begin
                if (sck_neg) begin
                    if (cnt == cnt_max_addr) begin // end det
                        cnt <= 0;
                        if (wait_cyc == 0) begin
                            if (tx) begin // tx, reload tx buf
                                out_en <= out_en_tx;
                                shift_reg32 <= shift_reg32_init_tx;
                                sck_pause <= ~tx_vld; // if tx data not ready, pause clock
                            end
                            else begin // rx, disable output
                                out_en <= out_en_rx;
                            end
                        end
                        else begin // to wait
                            out_en <= out_en_wait;
                            shift_reg32 <= shift_reg32_init_wait;
                        end
                    end
                    else begin
                        cnt <= cnt + 1;
                        shift_reg32 <= shift_reg32_next_addr;
                    end
                end
            end
            WAIT_CYC: begin
                if (sck_neg) begin
                    if (cnt == cnt_max_wait) begin
                        cnt <= 0;
                        if (tx) begin // tx, reload tx buf
                            out_en <= out_en_tx;
                            shift_reg32 <= shift_reg32_init_tx;
                            sck_pause <= ~tx_vld; // if tx data not ready, pause clock
                        end
                        else begin // rx, disable output
                            out_en <= out_en_rx;
                        end
                    end
                    else begin
                        cnt <= cnt + 1;
                    end
                end
            end
            TX_DATA: begin // check tx data valid one cycle before data start
                if (sck_pause) begin // wait data
                    sck_pause <= ~tx_vld;
                    shift_reg32 <= shift_reg32_init_tx;
                end
                else if (sck_neg) begin // tx
                    if (byte_end && (cnt != cnt_max_data)) begin // update byte cnt if not last byte
                            cnt <= cnt + 1;
                    end
                    if (byte_end && (cnt == cnt_max_data)) begin // end
                        sck_pause <= 1;
                    end
                    else begin // tx
                        if (word_end) begin // reload next word
                            sck_pause <= ~tx_vld;
                            bit_cnt <= 0;
                            shift_reg32 <= shift_reg32_init_tx;
                        end
                        else begin
                            bit_cnt <= bit_cnt + 1;
                            shift_reg32 <= shift_reg32_next_tx;
                        end
                    end
                end
            end
            RX_DATA: begin
                if (sck_pause) begin // wait bus
                    if (rx_rdy)
                        sck_pause <= 0;
                end
                else if (sck_pos) begin
                    if (byte_end && (cnt != cnt_max_data)) begin // update byte cnt if not last byte
                        cnt <= cnt + 1;
                    end
                    if (byte_end && (cnt == cnt_max_data)) begin // end
                        sck_pause <= 1;
                        shift_reg32 <= shift_reg32_next_rx; // not must
                    end
                    else begin
                        if (word_end) begin
                            sck_pause <= ~rx_rdy;
                            bit_cnt <= 0;
                            shift_reg32 <= shift_reg32_next_rx; // not must
                        end
                        else begin
                            bit_cnt <= bit_cnt + 1;
                            shift_reg32 <= shift_reg32_next_rx;
                        end
                    end
                end
            end
            TRANS_END: begin
                sck_pause <= 0;
                sck_en <= 0;
                ncs <= 1;
            end
            default : begin // init qspi port?
                ncs <= 1;
                sck_en <= 0;
            end
        endcase
    end

// output
//assign do = shift_reg32[31:28]};
assign do = data_width == 2'b00 ? {3'b000, shift_reg32[31:31]} : // no need ??? just falitate simulation
            data_width == 2'b01 ? {2'b00,  shift_reg32[31:30]} :
                                  {        shift_reg32[31:28]} ;
assign do_en = out_en;
assign rx_vld = (st_curr == RX_DATA) && ((sck_pos == 1 && rx_rdy == 1 && ((word_end == 1) || (byte_end == 1 && cnt == cnt_max_data))) ||
                                         (sck_pause == 1 && rx_rdy == 1));
assign rx_data = shift_reg32_next_rx;
assign tx_free = (st_curr == TX_ADDR && sck_neg && cnt == cnt_max_addr && wait_cyc == 0 && tx && tx_vld) ||
                 (st_curr == WAIT_CYC && sck_neg && cnt == cnt_max_wait && tx && tx_vld) ||
                 (st_curr == TX_DATA && word_end && tx_vld) ||
                 (st_curr == TX_DATA && sck_pause && tx_vld); // tbd, 20200325
assign done = (st_curr == TRANS_END) && (st_next == IDLE);
// inst sck
psram_clk u_sck (
    .rstn (rstn),
    .clk (clk),
    .sck_en (sck_en),
    .sck_pause (sck_pause),
    .sck_div (sck_div),
    .sck_neg (sck_neg),
    .sck_pos (sck_pos), // due to clk delay, use sck_pos will cause read date earlier than we want, may cause problems!!!
    .sck (sck)
);

endmodule

