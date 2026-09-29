`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/30 13:04:17
// Design Name: 
// Module Name: FIR_Datapath
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


module FIR_Datapath #(
    parameter RAM_WIDTH = 64,
    parameter LEN_WIDTH = 16
)(
    input                       clk,
    input                       rst_n,
    input                       Reset,
    
    // Control Enables
    input                       ena_filter,
    input                       we_window,
    input                       flush_window,
    input                       ena_s1,
    input                       ena_s2,
    
    // Data I/O
    input  [RAM_WIDTH-1:0]      AXS_S_fil_data,
    input  [RAM_WIDTH-1:0]      AXS_S_src_data,
    output [RAM_WIDTH-1:0]      AXS_M_psum_data
);

    localparam Tap_Num = RAM_WIDTH / LEN_WIDTH;

    // Internal Wires
    wire signed [RAM_WIDTH-1 : 0]                filter_coeffs;
    wire signed [2 * RAM_WIDTH-1 : 0]            window_reg_out;
    wire signed [Tap_Num * RAM_WIDTH - 1 : 0]    mul_result;
    wire signed [Tap_Num * RAM_WIDTH - 1 : 0]    adder_input;
    wire signed [RAM_WIDTH - 1 : 0]              adder_out;

    // Config Register
    Pipe_Reg #(.WIDTH(RAM_WIDTH)) Filter_Reg (
        .clk    (clk),
        .rst_n  (rst_n),
        .flush  (Reset),
        .WE     (ena_filter),
        .D      (AXS_S_fil_data),
        .Q      (filter_coeffs)
    ); 

    // Window Register
    Pipe_Reg #(.WIDTH(2 * RAM_WIDTH)) Window_Reg (
        .clk    (clk),
        .rst_n  (rst_n),
        .flush  (flush_window),
        .WE     (we_window),    
        .D      ({AXS_S_src_data, window_reg_out[RAM_WIDTH +: RAM_WIDTH]}),
        .Q      (window_reg_out)
    );

    // Multiplication Stage
    Parallel_Multiplication #(
        .Tap_Num    (Tap_Num),
        .Data_Width (LEN_WIDTH)
    ) Parallel_Mul (
        .Coeffs     (filter_coeffs),
        .src_data   (window_reg_out),
        .mul_data   (mul_result)
    );

    // Pipeline Register s1
    Pipe_Reg #(.WIDTH(Tap_Num * RAM_WIDTH)) Pipe_Reg_s1 (
        .clk    (clk),
        .rst_n  (rst_n),
        .flush  (Reset),
        .WE     (ena_s1),
        .D      (mul_result),
        .Q      (adder_input)
    );

    // Adder Tree Stage
    Parallel_Adder_Tree #(
        .Tap_Num    (Tap_Num),
        .Data_Width (LEN_WIDTH)
    ) Parallel_Adder (
        .mul_data   (adder_input),
        .y_out      (adder_out)
    );

    // Pipeline Register s2
    Pipe_Reg #(.WIDTH(RAM_WIDTH)) Pipe_Reg_s2 (
        .clk    (clk),
        .rst_n  (rst_n),
        .flush  (Reset),
        .WE     (ena_s2),
        .D      (adder_out),
        .Q      (AXS_M_psum_data)
    );

endmodule
