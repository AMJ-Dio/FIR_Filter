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

module FIR_Filter_Top_Module#(
    parameter RAM_WIDTH = 64,   //RAM_WIDTH = LEN_WIDTH * Tap_Num
    parameter LEN_WIDTH = 16    //LEN_WIDTH = Data_Width
    )(
    input                       clk,
    input                       rst_n,
 
    //control/config from MMIO
    input                       start,
    input                       Reset,
//    input  [LEN_WIDTH-1:0]      cfg_tap_num,
//    input  [LEN_WIDTH-1:0]      cfg_source_num,  
    
    //filter input stream
    input                       AXS_S_fil_vld,
    output                      AXS_S_fil_rdy,
    input  [RAM_WIDTH-1:0]      AXS_S_fil_data,  //AXS_S_fil_data = {coeff[4], coeff[3], coeff[2], coeff[1]};
    input                       AXS_S_fil_last,  
 
    //source input stream
    input                       AXS_S_src_vld,
    output                      AXS_S_src_rdy,
    input  [RAM_WIDTH-1:0]      AXS_S_src_data,  //AXS_S_src_data = {x[4], x[3], x[2], x[1]};
    input                       AXS_S_src_last,
 
    //result output stream
    output                      AXS_M_psum_vld,
    input                       AXS_M_psum_rdy, //MMIO Wrapper_ena
    output  [RAM_WIDTH-1:0]     AXS_M_psum_data,
    output                      AXS_M_psum_last,
 
    //status
    output  reg                 busy,
    output  reg                 done
 
    );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE    = 3'b000;
localparam BUSY    = 3'b010;
localparam DONE    = 3'b100;
localparam Tap_Num = RAM_WIDTH / LEN_WIDTH;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire signed [RAM_WIDTH-1 : 0]                                        filter_coeffs;
wire signed [2 * RAM_WIDTH-1 : 0]                                    window_reg_out;
wire signed [Tap_Num * RAM_WIDTH - 1 : 0]                            mul_result;
wire signed [Tap_Num * RAM_WIDTH - 1 : 0]                            adder_input;
wire signed [RAM_WIDTH - 1 : 0]                                      adder_out;

reg                                                                  coeff_loaded;
wire                                                                 rdy_s0;
wire                                                                 rdy_s1;
wire                                                                 rdy_s2;
reg                                                                  vld_s0;
reg                                                                  vld_s1;
reg                                                                  vld_s2;
wire                                                                 handshake_s0;
wire                                                                 handshake_s1;
wire                                                                 handshake_s2;
wire                                                                 src_handshake;
wire                                                                 ena_filter;
wire                                                                 ena_s0;
wire                                                                 ena_s1;
wire                                                                 ena_s2;

wire                                                                 start_pos;
reg                                                                  start_d1;
reg                                                                  last_s0;
reg                                                                  last_s1;
reg                                                                  last_s2;

//=====================================================================================================================
// Logic Design: FSM
//=====================================================================================================================
reg [2:0] state;
reg [2:0] next_state;

always@(*) begin
    case( state )
        IDLE : begin
               busy = 0;
               done = 0;
               if(Reset)
                  next_state = IDLE;
               else if(start_pos)
                  next_state = BUSY;
               else
                  next_state = IDLE;
               end
                  
        BUSY : begin
               busy = 1;
               done = 0;
               if(Reset)
                  next_state = IDLE;
               else if(AXS_M_psum_last && handshake_s2)
                  next_state = DONE;
               else
                  next_state = BUSY;
               end
        DONE : begin
               busy = 0;
               done = 1;
               if(Reset)
                  next_state = IDLE;
               else if(!start)
                  next_state = IDLE;
               else
                  next_state = DONE;        
               end      
        default: 
               begin
               busy = 0;
               done = 0;
               next_state = IDLE; 
               end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        start_d1 <= 1'b0;
    end else begin
        start_d1 <= start;
    end
end

assign start_pos = start & ~start_d1;
        
always@(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end 
    else begin
        state <= next_state;
    end
end

//=====================================================================================================================
// Logic Design: Filter Config
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        coeff_loaded <= 1'b0;
    end
    else if (state == IDLE || Reset) begin
        coeff_loaded <= 1'b0;
    end
    else if (AXS_S_fil_vld && AXS_S_fil_rdy) begin
        coeff_loaded <= 1'b1;
    end
end

assign AXS_S_fil_rdy = ~coeff_loaded;
assign ena_filter = AXS_S_fil_vld && AXS_S_fil_rdy;

Pipe_Reg#(.WIDTH(RAM_WIDTH)) Filter_Reg
(
    .clk(clk),
    .rst_n(rst_n),
    .flush(Reset),
    .WE(ena_filter),
    .D(AXS_S_fil_data),
    .Q(filter_coeffs)
); 

//=====================================================================================================================
// Logic Design: s0
//=====================================================================================================================    
assign rdy_s0 = ena_s1; 
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0 = handshake_s0 | ~vld_s0;

assign AXS_S_src_rdy = (state == BUSY) & ena_s0;
assign src_handshake = AXS_S_src_rdy & AXS_S_src_vld;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vld_s0  <= 1'b0;
        last_s0 <= 1'b0;
    end   
    else if(state == IDLE || Reset) begin
        vld_s0  <= 1'b0;
        last_s0 <= 1'b0;
    end
    else if(state == BUSY && ena_s0) begin
        vld_s0  <= AXS_S_src_vld;
        last_s0 <= AXS_S_src_vld & AXS_S_src_last; 
    end
end

Pipe_Reg#(.WIDTH(2 * RAM_WIDTH)) Window_Reg
(
    .clk(clk),
    .rst_n(rst_n),
    .flush(Reset | (state == IDLE)),
    .WE(src_handshake),    
    .D({AXS_S_src_data, window_reg_out[RAM_WIDTH +: RAM_WIDTH]}),
    .Q(window_reg_out)
);
    
//=====================================================================================================================
// Logic Design: s1
//===================================================================================================================== 
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        last_s1 <= 1'b0;
        vld_s1 <= 1'b0;
        end
    else if(state == IDLE || Reset) begin
        last_s1 <= 1'b0;
        vld_s1 <= 1'b0;
        end
    else if(ena_s1) begin
        last_s1 <= last_s0;
        vld_s1 <= vld_s0;
        end
end

assign rdy_s1 = ena_s2;
assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1 = handshake_s1 | ~vld_s1;

Parallel_Multiplication#(
    .Tap_Num(Tap_Num),
    .Data_Width(LEN_WIDTH)
) Parallel_Mul
(
    .Coeffs(filter_coeffs),
    .src_data(window_reg_out),
    .mul_data(mul_result)
);

Pipe_Reg#(.WIDTH(Tap_Num * RAM_WIDTH)) Pipe_Reg_s1
(
    .clk(clk),
    .rst_n(rst_n),
    .flush(Reset),
    .WE(ena_s1),
    .D(mul_result),
    .Q(adder_input)
);
//=====================================================================================================================
// Logic Design: s2
//===================================================================================================================== 
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        last_s2 <= 1'b0;
        vld_s2 <= 1'b0;
        end
    else if(state == IDLE || Reset) begin
        last_s2 <= 1'b0;
        vld_s2 <= 1'b0;
        end
    else if(ena_s2) begin
        last_s2 <= last_s1;  
        vld_s2 <= vld_s1;
        end
end

assign rdy_s2 = AXS_M_psum_rdy;
assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2 = handshake_s2 | ~vld_s2;
assign AXS_M_psum_vld = vld_s2;
assign AXS_M_psum_last = last_s2;

Parallel_Adder_Tree#(
    .Tap_Num(Tap_Num),
    .Data_Width(LEN_WIDTH)
) Parallel_Adder
(
    .mul_data(adder_input),
    .y_out(adder_out)
);

Pipe_Reg#(.WIDTH(RAM_WIDTH)) Pipe_Reg_s2
(
    .clk(clk),
    .rst_n(rst_n),
    .flush(Reset),
    .WE(ena_s2),
    .D(adder_out),
    .Q(AXS_M_psum_data)
);
    
endmodule
