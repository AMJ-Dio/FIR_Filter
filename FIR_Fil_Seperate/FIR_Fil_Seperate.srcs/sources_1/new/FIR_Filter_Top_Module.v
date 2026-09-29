`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/28 19:25:24
// Design Name: 
// Module Name: FIR_Filter_Top_Module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module FIR_Filter_Top_Module #(
    parameter RAM_WIDTH = 64,   
    parameter LEN_WIDTH = 16    
)(
    input                       clk,
    input                       rst_n,
    
    // control/config from MMIO
    input                       start,
    input                       Reset,
    
    // filter input stream
    input                       AXS_S_fil_vld,
    output                      AXS_S_fil_rdy,
    input  [RAM_WIDTH-1:0]      AXS_S_fil_data, 
    input                       AXS_S_fil_last,  
    
    // source input stream
    input                       AXS_S_src_vld,
    output                      AXS_S_src_rdy,
    input  [RAM_WIDTH-1:0]      AXS_S_src_data, 
    input                       AXS_S_src_last,
    
    // result output stream
    output                      AXS_M_psum_vld,
    input                       AXS_M_psum_rdy, 
    output [RAM_WIDTH-1:0]      AXS_M_psum_data,
    output                      AXS_M_psum_last,
    
    // status
    output                      busy,
    output                      done
);

    // ==========================================
    // Internal Wires (The "Motherboard" Traces)
    // ==========================================
    wire ena_filter;
    wire we_window;
    wire flush_window;
    wire ena_s1;
    wire ena_s2;

    // ==========================================
    // Instance 1: Control Module
    // ==========================================
    FIR_Control u_ctrl (
        .clk              (clk),
        .rst_n            (rst_n),
        .start            (start),
        .Reset            (Reset),
        
        // AXI Stream Handshakes
        .AXS_S_fil_vld    (AXS_S_fil_vld),
        .AXS_S_fil_rdy    (AXS_S_fil_rdy),
        .AXS_S_src_vld    (AXS_S_src_vld),
        .AXS_S_src_rdy    (AXS_S_src_rdy),
        .AXS_S_src_last   (AXS_S_src_last),
        .AXS_M_psum_vld   (AXS_M_psum_vld),
        .AXS_M_psum_rdy   (AXS_M_psum_rdy),
        .AXS_M_psum_last  (AXS_M_psum_last),
        
        // Status
        .busy             (busy),
        .done             (done),
        
        // Datapath Enables
        .ena_filter       (ena_filter),
        .we_window        (we_window),
        .flush_window     (flush_window),
        .ena_s1           (ena_s1),
        .ena_s2           (ena_s2)
    );

    // ==========================================
    // Instance 2: Datapath Module
    // ==========================================
    FIR_Datapath #(
        .RAM_WIDTH(RAM_WIDTH),
        .LEN_WIDTH(LEN_WIDTH)
    ) u_dp (
        .clk              (clk),
        .rst_n            (rst_n),
        .Reset            (Reset),
        
        // Datapath Enables from Control
        .ena_filter       (ena_filter),
        .we_window        (we_window),
        .flush_window     (flush_window),
        .ena_s1           (ena_s1),
        .ena_s2           (ena_s2),
        
        // Data in/out
        .AXS_S_fil_data   (AXS_S_fil_data),
        .AXS_S_src_data   (AXS_S_src_data),
        .AXS_M_psum_data  (AXS_M_psum_data)
    );

endmodule
