module psram_cfg_parse (
    input       [31:0]      cfg0,
    input       [31:0]      cfg1,
    input       [31:0]      cfg2,
    input       [31:0]      cfg3,
    output      [14:0]      data_len,
    output      [3:0]       sck_div,
    output                  single_line_io_mode,
    output                  data_dir,
    output      [1:0]       data_width,
    output      [3:0]       wait_cyc,
    output      [1:0]       addr_width,
    output                  cmd_only,
    output      [1:0]       cmd_width,
    output      [23:0]      addr,
    output      [7:0]       cmd,
    output      [14:0]      dma_len,
    output      [`RAM_WIDTH-1:0] dma_saddr
);

// cfg0
assign data_len                = cfg0[31:17];
assign sck_div                 = cfg0[16:13];
assign single_line_io_mode     = cfg0[12:12];
assign data_dir                = cfg0[11:11];
assign data_width              = cfg0[10: 9];
assign wait_cyc                = cfg0[ 8: 5];
assign addr_width              = cfg0[ 4: 3];
assign cmd_only                = cfg0[ 2: 2];
assign cmd_width               = cfg0[ 1: 0];
// cfg1
assign addr                    = cfg1[31: 8];
assign cmd                     = cfg1[ 7: 0];
// cfg2
assign dma_len                 = cfg2[31:`RAM_WIDTH]; // tbd, if RAM WIDTH mt 17
assign dma_saddr               = cfg2[`RAM_WIDTH-1: 0];

endmodule

