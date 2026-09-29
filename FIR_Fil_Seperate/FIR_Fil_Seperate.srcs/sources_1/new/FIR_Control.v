`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/30 13:03:59
// Design Name: 
// Module Name: FIR_Control
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


module FIR_Control (
    input   clk,
    input   rst_n,
    
    input   start,
    input   Reset,
    
    input   AXS_S_fil_vld,
    output  AXS_S_fil_rdy,
    
    input   AXS_S_src_vld,
    output  AXS_S_src_rdy,
    input   AXS_S_src_last,
    
    output  AXS_M_psum_vld,
    input   AXS_M_psum_rdy,
    output  AXS_M_psum_last,
    
    output reg busy,
    output reg done,
    
    // Outputs to Datapath
    output  ena_filter,
    output  we_window,
    output  flush_window,
    output  ena_s1,
    output  ena_s2
);

    localparam IDLE = 3'b000;
    localparam BUSY = 3'b010;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg start_d1;
    wire start_pos = start & ~start_d1;
    
    reg coeff_loaded;
    reg vld_s0, vld_s1, vld_s2;
    reg last_s0, last_s1, last_s2;
    
    wire rdy_s0, rdy_s1, rdy_s2;
    wire handshake_s0, handshake_s1, handshake_s2;
    wire ena_s0;

    // FSM State Register
    always@(posedge clk or negedge rst_n) begin
        if (!rst_n)      state <= IDLE;
        else             state <= next_state;
    end

    // FSM Next State Logic
    always@(*) begin
        case(state)
            IDLE: begin
                busy = 0; done = 0;
                if(Reset)           next_state = IDLE;
                else if(start_pos)  next_state = BUSY;
                else                next_state = IDLE;
            end
            BUSY: begin
                busy = 1; done = 0;
                if(Reset)           next_state = IDLE;
                else if(AXS_M_psum_last && handshake_s2) next_state = DONE;
                else                next_state = BUSY;
            end
            DONE: begin
                busy = 0; done = 1;
                if(Reset)           next_state = IDLE;
                else if(!start)     next_state = IDLE;
                else                next_state = DONE;        
            end
            default: begin
                busy = 0; done = 0;
                next_state = IDLE; 
            end
        endcase
    end

    // Start Edge Detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) start_d1 <= 1'b0;
        else        start_d1 <= start;
    end

    // Filter Config Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                              coeff_loaded <= 1'b0;
        else if (Reset)                          coeff_loaded <= 1'b0;
        else if (AXS_S_fil_vld && AXS_S_fil_rdy) coeff_loaded <= 1'b1;
    end
    
    assign AXS_S_fil_rdy = ~coeff_loaded;
    assign ena_filter = AXS_S_fil_vld && AXS_S_fil_rdy;

    // s0 Logic
    assign rdy_s0 = ena_s1; 
    assign handshake_s0 = rdy_s0 & vld_s0;
    assign ena_s0 = handshake_s0 | ~vld_s0;
    assign AXS_S_src_rdy = (state == BUSY) & ena_s0;
    
    assign we_window = AXS_S_src_rdy & AXS_S_src_vld;
    assign flush_window = Reset | (state == IDLE) | (state == DONE);

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            vld_s0  <= 1'b0;
            last_s0 <= 1'b0;
        end else if(state == IDLE || Reset) begin
            vld_s0  <= 1'b0;
            last_s0 <= 1'b0;
        end else if(state == BUSY && ena_s0) begin
            vld_s0  <= AXS_S_src_vld;
            last_s0 <= AXS_S_src_vld & AXS_S_src_last; 
        end
    end

    // s1 Logic
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            last_s1 <= 1'b0;
            vld_s1  <= 1'b0;
        end else if(state == IDLE || Reset) begin
            last_s1 <= 1'b0;
            vld_s1  <= 1'b0;
        end else if(ena_s1) begin
            last_s1 <= last_s0;
            vld_s1  <= vld_s0;
        end
    end
    
    assign rdy_s1 = ena_s2;
    assign handshake_s1 = rdy_s1 & vld_s1;
    assign ena_s1 = handshake_s1 | ~vld_s1;

    // s2 Logic
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            last_s2 <= 1'b0;
            vld_s2  <= 1'b0;
        end else if(state == IDLE || Reset) begin
            last_s2 <= 1'b0;
            vld_s2  <= 1'b0;
        end else if(ena_s2) begin
            last_s2 <= last_s1;  
            vld_s2  <= vld_s1;
        end
    end
    
    assign rdy_s2 = AXS_M_psum_rdy;
    assign handshake_s2 = rdy_s2 & vld_s2;
    assign ena_s2 = handshake_s2 | ~vld_s2;
    
    assign AXS_M_psum_vld = vld_s2;
    assign AXS_M_psum_last = last_s2;

endmodule
