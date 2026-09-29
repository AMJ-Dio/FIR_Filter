`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/25 09:11:49
// Design Name: 
// Module Name: FIR_Filter
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


module FIR_Filter_Parallel #(parameter W = 32,   //W -> Data Width
                             parameter N = 16,       //N -> Tap Number
                             parameter [N*W-1:0] b = {N*W{1'b0}}) //b = {b0,b1,b2,b3 ...,bn}
(
    input clk,
    input rst_n,
    input signed [W-1:0] x,             //Input values
    output reg signed [2*W + $clog2(N) - 1:0] y       //Output    
);
    
    reg signed [W-1:0] x_array [0:N-1]; //Array to store x values
    integer k,n; //Loop variables
    reg signed [2*W + $clog2(N) - 1:0] sum;
    reg signed [2*W-1:0] p [0:N-1]; //Multiplication Result Array
    
    //Decode the coefficient, coeff_array[0] = bn, coeff_array[1] = b(n-1)
    wire signed [W-1:0] coeff_array [0:N-1];
    generate
        genvar i;
        for(i = 0; i < N; i = i + 1)
        begin
            assign coeff_array[i] = b[(i+1)*W-1 : W*i];
        end
    endgenerate
    
    always@(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            //Reset logic
            for(n = 0; n < N; n = n + 1)x_array[n] <= {W{1'b0}};
        else 
        begin
            //Store new x and shift x_array
            for(n = N - 1; n > 0; n = n - 1)x_array[n] <= x_array[n-1];
            x_array[0] <= x;
        end
    end

    //Calculate the sum
    always@(*)
    begin
    sum = 0;
    for(k = 0; k < N; k = k + 1)p[k] = x_array[k] * coeff_array[k];
    for(k=0; k<N; k=k+1)sum = sum + p[k];
    end
    
    //Output y when rising edge of clk
    always@(posedge clk or negedge rst_n)
    begin
    if(!rst_n)y <= {(2*W + $clog2(N)){1'b0}};
    else y <= sum;
    end
    
endmodule
