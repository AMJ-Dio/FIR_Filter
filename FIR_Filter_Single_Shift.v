`timescale 1ns / 1ps
/* ==============================================================================
 * Module Name: FIR_Filter
 * Description: Fully Pipelined Transposed FIR Filter
 * * Features:
 * - Transposed architecture for maximum operating frequency (high Fmax).
 * - Fully pipelined with 1 data/clock cycle throughput.
 * - Built-in pipeline stall mechanism via 'valid_in' signal.
 *
 * Parameters:
 * - W: Data width for input 'x' and internal coefficients.
 * - N: Number of filter taps.
 * - b: Flattened coefficient array {b_n, b_(n-1), ..., b_0}.
 *
 * Usage Instructions:
 * 1. Reset (rst_n): 
 * Drive 'rst_n' low (0) to initialize the module. This clears all internal 
 * shift registers, sum chains, and valid chains to 0.
 *
 * 2. Inputting Data (valid_in & x):
 * - When you have valid data to process, set 'valid_in' = 1 and provide 
 * the data on 'x'.
 * - If there is no new data or you need to pause, set 'valid_in' = 0. 
 * This will STALL (freeze) the entire pipeline. No data will be lost, 
 * and the internal state will hold until 'valid_in' returns to 1.
 *
 * 3. Reading Output (valid_out & y):
 * - The module has a built-in Latency of (N + 2) clock cycles.
 * - ONLY read the output 'y' when 'valid_out' == 1. 
 * - If 'valid_out' == 0, it means the pipeline is either filling up (initial 
 * latency) or currently stalled. Ignore 'y' during this time.
 * ==============================================================================
 */


module FIR_Filter#(parameter W = 32,                      //Data Width
                   parameter N = 16,                      //Tap Number
                   parameter [N*W-1:0] b = {N*W{1'b0}})   //Coefficients, b={b_n,b_(n-1),b_(n-2),...b_0} 
                  (
                  input clk,                              //clock
                  input rst_n,                            //negative reset
                  input valid_in,                         //if 1, input signal is valid
                  input signed [W-1:0] x,                 //input signal value
                  output reg valid_out,                   //if 1, output signal is valid
                  output reg signed [2*W+$clog2(N)-1:0] y //output value
                  );
    
    //Define Variables
    wire signed [W-1:0] coeff [0:N-1];
    reg  signed [W-1:0] x_reg;
    integer k;                                            //loop variable
    reg signed [2*W+$clog2(N)-1:0] sum_chain [0:N-1];     //sum chain
    reg [N:0] valid_chain;
    
    
    //Decode Coefficients, coeff[i] = b_i
    generate
        genvar i;
        for(i=0; i<N; i=i+1)
        begin
            assign coeff[i] = b[(i+1)*W-1 : i*W];
        end
    endgenerate
    
    //input register
    always@(posedge clk or negedge rst_n)
    begin
        if(!rst_n)x_reg <= 0;
        else if(valid_in) x_reg <= x;
    end
    
    //Pipeline sum chain
    always@(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            for(k=0; k<N; k=k+1)sum_chain[k] <= 0;
        else if(valid_in) begin
            sum_chain[N-1] <= x_reg * coeff[N-1];
            for(k=0; k<N-1; k=k+1)
                sum_chain[k] <= sum_chain[k+1] + (x_reg * coeff[k]);
        end
    end
    
    //Output
    always@(posedge clk or negedge rst_n)
    begin
        if(!rst_n)y <= 0;
        else if(valid_in) y <= sum_chain[0];
    end
    
    //Pipeline Valid bit
    always@(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            valid_chain <= 0;
            valid_out <= 1'b0;
        end
        else 
        begin
        if(valid_in) begin
            valid_chain <= {valid_chain[N-1:0], valid_in};
            valid_out <= valid_chain[N];
        end
        else valid_out <= 0;
        end
    end
    
endmodule
