// `include "param_def.v"
interface chnl_intf(input clk, input rstn);
    logic [31:0] ch_data;
    logic        ch_valid;
    logic        ch_ready;
    clocking drv_ck @(posedge clk);
        default input #1ns output #1ns;
        input ch_ready;
        output ch_data, ch_valid;
    endclocking
    clocking mon_ck @(posedge clk);
        default input #1ns output #1ns;
        input ch_ready, ch_valid, ch_data;
    endclocking
    
endinterface //chnl_intf

interface reg_intf(input clk, input rstn);
    logic [1:0] cmd;
    logic [`ADDR_WIDTH-1:0] cmd_addr;
    logic [`CMD_DATA_WIDTH-1:0] cmd_data_s2m;
    logic [`CMD_DATA_WIDTH-1:0] cmd_data_m2s;
    clocking drv_ck @(posedge clk);
        default input #1ns output #1ns;
        input cmd_data_s2m;
        output cmd, cmd_addr, cmd_data_m2s;
    endclocking

    clocking mon_ck @(posedge clk);
        default input #1ns output #1ns;
        input cmd, cmd_addr, cmd_data_s2m, cmd_data_m2s;
    endclocking

endinterface // reg_intf

interface fmt_intf(input clk, input rstn);
    logic        fmt_grant;
    logic        fmt_req;
    logic        fmt_start;
    logic        fmt_end;
    logic  [1:0] fmt_chid;
    logic  [5:0] fmt_length;
    logic  [31:0] fmt_data;

    clocking drv_ck @(posedge clk);
        default input #1ns output #1ns;
        input fmt_chid, fmt_length, fmt_data, fmt_start, fmt_end, fmt_req;
        output fmt_grant;
    endclocking

    clocking mon_ck @(posedge clk);
        default input #1ns output #1ns;
        input fmt_grant, fmt_req, fmt_start, fmt_end, fmt_chid, fmt_length, fmt_data;
    endclocking
endinterface

interface mcdf_intf(input clk, input rstm);
    logic chnl_en[3];

    clocking mon_ck @(posedge clk);
        default input #1ns output #1ns;
        input chnl_en;
    endclocking
endinterface

import chnl_pkg::*;
import reg_pkg::*;
import fmt_pkg::*;
import mcdf_pkg::*;

module tb;

endmodule