`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/28 19:16:52
// Design Name: 
// Module Name: Parallel_Multiplication
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


module Parallel_Multiplication
    #(
      parameter Tap_Num = 4,
      parameter Data_Width = 16
     )
     (
      input signed [Tap_Num * Data_Width - 1 : 0] Coeffs, //Coefficients, b={b_n,b_(n-1),b_(n-2),...b_0}
      input signed [2 * Tap_Num * Data_Width - 1 : 0] src_data,  // src_data={d_(2n-1),d_(2n-2),...d_0}
      output signed [Tap_Num * Tap_Num * Data_Width - 1 : 0] mul_data
     );
    
    
    //Decode Coefficients, coeff[i] = b_i
    wire signed [Data_Width - 1 : 0] coeff [0 : Tap_Num - 1];
    generate
        genvar i;
        for(i = 0; i < Tap_Num; i = i + 1)
        begin
            assign coeff[i] = Coeffs[(i+1)*Data_Width-1 : i*Data_Width];
        end
    endgenerate  
    
    //Decode src_data, src_data_array[i] = x_i
    wire signed [Data_Width - 1 : 0] src_data_array [0 : 2 * Tap_Num - 1];
    generate
        genvar j;
        for(j = 0; j < 2 * Tap_Num; j = j + 1)
        begin
            assign src_data_array[j] = src_data[(j+1) * Data_Width - 1 : j*Data_Width];
        end
    endgenerate    
    
    //Parallel Multiplication
    reg signed [Data_Width - 1 : 0] mul_data_array [0 : Tap_Num * Tap_Num - 1];
    integer m, n;
    always@(*)
    begin
        for(m = 0; m < Tap_Num; m = m + 1)
        begin
            for(n = 0; n < Tap_Num; n = n + 1)
            begin
            mul_data_array[m * Tap_Num + n] = coeff[n] * src_data_array[m + n];
            end
        end
    end
    
    //output
    generate
        genvar k;
        for(k = 0; k < Tap_Num * Tap_Num; k = k + 1)
        begin
            assign mul_data[(k+1) * Data_Width - 1 : k*Data_Width] = mul_data_array[k];
        end
    endgenerate
      
endmodule
