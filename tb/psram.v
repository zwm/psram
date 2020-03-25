
// 20200304, file created

module camera_dcmi (
    input                       dcmi_pwdn,
    input                       dcmi_mclk,
    output                      dcmi_pclk,
    output                      dcmi_vsync,
    output                      dcmi_hsync,
    output [13:0]               dcmi_data // support 8/10/12/14 bit
);

//---------------------------------------------------------------------------
//  Macro
//---------------------------------------------------------------------------
`define CAMERA_CFG_FILE         "camera_cfg.txt"
`define CAMERA_DATA_FILE        "camera_data.txt"
`define DCMI_CAPTURE_EN         tb_top.u_dcmi_top.capture_en

//---------------------------------------------------------------------------
//  Var
//---------------------------------------------------------------------------
// conf
reg                         snapshot_mode;
reg                         jpeg_en;
reg                         embd_sync_en;
reg                         pclk_polarity;
reg                         hsync_polarity;
reg                         vsync_polarity;
reg         [1:0]           data_bus_width;         // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
reg         [7:0]           fec;
reg         [7:0]           lec;
reg         [7:0]           lsc;
reg         [7:0]           fsc;
reg         [7:0]           feu;
reg         [7:0]           leu;
reg         [7:0]           lsu;
reg         [7:0]           fsu;
reg         [13:0]          line_size;
reg         [13:0]          pixel_size;
// signal
reg [1:0] dcmi_capture_en_dly; wire ftrig; reg [1:0] ftrig_dly; // frame trigger
reg ext_vsync, ext_hsync; reg jpeg_vsync, jpeg_hsync; reg embd_vsync, embd_hsync;
reg [13:0] ext_data, jpeg_data, embd_data;
reg [31:0] ext_line_cnt, ext_pixel_cnt, ext_tmp_cnt;
reg [31:0] jpeg_line_cnt, jpeg_pixel_cnt, jpeg_tmp_cnt;
reg [31:0] embd_line_cnt, embd_pixel_cnt, embd_tmp_cnt;
reg [3:0] ext_st, jpeg_st, embd_st;
integer fp, fpd, i, j, k, tmp; reg [31:0] task_cnt; reg sim_end;
//---------------------------------------------------------------------------
//  System Ctrl
//---------------------------------------------------------------------------
// EN
wire dcmi_en = ~dcmi_pwdn;
// CLOCK
`ifndef DCMI_PCLK_PERIOD
    `define DCMI_PCLK_PERIOD 20.83
`endif
reg pclk_raw;
initial begin
    pclk_raw = 0;
    forever #((`DCMI_PCLK_PERIOD)/2) pclk_raw = ~pclk_raw;
end
wire pclk = (~dcmi_pclk) ^ pclk_polarity;
wire clk = pclk;
wire rstn = ~dcmi_pwdn;
//---------------------------------------------------------------------------
//  Main
//---------------------------------------------------------------------------
// main
initial begin
    // init
    camera_init;
    // main loop
    begin: LP_MAIN
        while(1) begin
            @(posedge pclk_raw) begin
                if (sim_end) begin
                    $fclose(fp);
                    $display("%t, CAMERA DCMI CFG FILE READ END!", $time);
                    disable LP_MAIN;
                end
                else begin
                    if (ftrig) begin
                        read_cfg(fp);
                        fpd = $fopen(`CAMERA_DATA_FILE, "r");
                    end
                end
            end
        end
    end
end
// dcmi_capture_en_dly
always @(posedge pclk_raw or negedge rstn)
    if (~rstn)
        dcmi_capture_en_dly <= 2'b00;
    else
        dcmi_capture_en_dly <= {dcmi_capture_en_dly[0], `DCMI_CAPTURE_EN};
assign ftrig = ~dcmi_capture_en_dly[1] & dcmi_capture_en_dly[0];
// ftrig_dly
always @(posedge pclk_raw or negedge rstn)
    if (~rstn)
        ftrig_dly <= 2'b00;
    else
        ftrig_dly <= {ftrig_dly[0], ftrig};
// start
wire jpeg_start = ftrig_dly[1] & jpeg_en;
wire embd_start = ftrig_dly[1] & ~jpeg_en & embd_sync_en;
wire ext_start  = ftrig_dly[1] & ~jpeg_en & ~embd_sync_en;
//---------------------------------------------------------------------------
//  Jpeg Engine
//---------------------------------------------------------------------------



//---------------------------------------------------------------------------
//  Embedded Sync Engine
//---------------------------------------------------------------------------



//---------------------------------------------------------------------------
//  External Sync Engine
//---------------------------------------------------------------------------
localparam EXT_IDLE             = 0;
localparam EXT_FS               = 1;
localparam EXT_LS               = 2;
localparam EXT_LINE             = 3;
localparam EXT_LE               = 4;
localparam EXT_FE               = 5;
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        ext_st <= EXT_IDLE; ext_tmp_cnt <= 0;
        ext_line_cnt <= 0; ext_pixel_cnt <= 0; ext_data <= 0;
        ext_vsync <= 0; ext_hsync <= 0;
    end
    else begin
        case (ext_st)
            EXT_IDLE: begin
                if (ext_start) begin
                    ext_st <= EXT_FS; ext_tmp_cnt <= 0;
                    ext_line_cnt <= 0; ext_pixel_cnt <= 0; ext_data <= 0;
                    ext_vsync <= 0; ext_hsync <= 0;
                end
            end
            EXT_FS: begin
                if (ext_tmp_cnt == 20) begin
                    ext_st <= EXT_LS; ext_tmp_cnt <= 0;
                    ext_line_cnt <= 0; ext_pixel_cnt <= 0; ext_data <= 0;
                    ext_vsync <= 1; ext_hsync <= 0; // vsync change valid
                end
                else begin
                    ext_tmp_cnt <= ext_tmp_cnt + 1;
                end
            end
            EXT_LS: begin
                if (ext_tmp_cnt == 20) begin
                    ext_st <= EXT_LINE; ext_tmp_cnt <= 0;
                    ext_hsync <= 1;
                    ext_pixel_cnt <= 0;
                    ext_data <= 0;
                end
                else begin
                    ext_tmp_cnt <= ext_tmp_cnt + 1;
                end
            end
            EXT_LINE: begin
                // cnt
                if (ext_pixel_cnt == pixel_size - 1) begin
                    ext_st <= EXT_LE; ext_tmp_cnt <= 0;
                end
                else begin
                    ext_pixel_cnt <= ext_pixel_cnt + 1;
                end
                // data
                tmp = $fscanf(fpd, "%h", ext_tmp_cnt);
                ext_data <= ext_tmp_cnt[13:0];
            end
            EXT_LE: begin
                ext_hsync <= 0;
                if (ext_line_cnt == line_size - 1) begin
                    ext_st <= EXT_FE; ext_tmp_cnt <= 0;
                    ext_line_cnt <= 0;
                end
                else begin
                    ext_st <= EXT_LS;
                    ext_line_cnt <= ext_line_cnt + 1;
                end
            end
            EXT_FE: begin
                if (ext_tmp_cnt == 20) begin
                    // vsync
                    ext_vsync <= 0;
                    if (~snapshot_mode & dcmi_en) begin
                        ext_st <= EXT_FS;
                    end
                    else begin
                        ext_st <= EXT_IDLE;
                        $fclose(fpd);
                    end
                end
                else begin
                    ext_tmp_cnt <= ext_tmp_cnt + 1;
                end
            end
            default: begin
                ext_st <= EXT_IDLE;
                ext_line_cnt <= 0; ext_pixel_cnt <= 0; ext_data <= 0;
                ext_vsync <= 0; ext_hsync <= 0;
            end
        endcase
    end
reg ext_hsync_d1;
always @(posedge clk or negedge rstn)
    if (~rstn)
        ext_hsync_d1 <= 0;
    else
        ext_hsync_d1 <= ext_hsync;
//---------------------------------------------------------------------------
//  Final Output
//---------------------------------------------------------------------------
// pclk
assign dcmi_pclk = dcmi_en & pclk_raw;
assign dcmi_vsync = vsync_polarity ^ (jpeg_en ? ~jpeg_vsync : embd_sync_en ? ~embd_vsync : ~ext_vsync);
assign dcmi_hsync = hsync_polarity ^ (jpeg_en ? ~jpeg_hsync : embd_sync_en ? ~embd_hsync : ~ext_hsync_d1);
assign dcmi_data  = jpeg_en ? ~jpeg_data  : embd_sync_en ? ~embd_data  : ext_data ;

//---------------------------------------------------------------------------
//  task
//---------------------------------------------------------------------------
// camera_init
task camera_init;
    begin
        sim_end = 0;
        task_cnt = 0;
        fp = $fopen(`CAMERA_CFG_FILE, "r");
    end
endtask
// read_cfg
task read_cfg;
    input integer fp;
    integer ret, i, j, k, tmp;
    reg [80*8-1:0] s;
    begin
        // read title
        ret = $fgets (s, fp); // task label
        if (ret < 7)  begin // error detect
            sim_end = 1;
            $display("%t, read log file end!", $time);
        end
        else begin
            $display("%t, task_cnt: %0d, log label: %0s", $time, task_cnt, s);
        end
        // read log
        if (sim_end == 0) begin
            // command
            ret = $fscanf(fp, "%s %d", s, snapshot_mode); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %d", s, jpeg_en); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %d", s, embd_sync_en); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %d", s, pclk_polarity); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %d", s, vsync_polarity); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %d", s, hsync_polarity); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %d", s, data_bus_width); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %h", s, fsc); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %h", s, fec); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %h", s, lsc); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %h", s, lec); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %h", s, fsu); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %h", s, feu); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %h", s, lsu); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %h", s, leu); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %d", s, line_size); ret = $fgets(s, fp);
            ret = $fscanf(fp, "%s %d", s, pixel_size); ret = $fgets(s, fp);
        end
    end
endtask

endmodule

