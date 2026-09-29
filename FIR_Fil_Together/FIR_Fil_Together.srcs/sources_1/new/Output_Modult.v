`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/28 22:20:38
// Design Name: 
// Module Name: Output_Modult
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


module Output_Module
   #(
    parameter Tap_Num = 4,
    parameter Data_Width = 16
    )
    (
    input signed [Tap_Num * (2 * Data_Width + $clog2(Tap_Num)) - 1 : 0] y_out,
    output signed [Tap_Num * Data_Width - 1 : 0] result
    );
    
    // define local datawidth
    localparam MUL_W = 2 * Data_Width;
    localparam OUT_W = MUL_W + $clog2(Tap_Num);
    localparam TRUNC_W = OUT_W - (Data_Width - 1);
    
    //Saturation Truncation
    generate
        genvar j;
        for(j = 0; j < Tap_Num; j = j + 1)
        begin: Saturation_Truncation
            wire [TRUNC_W - 1 : 0] internal_sig;
            //right shift y_out (Data_Width - 1) bits. (Assuming coeffs are Q1.15 or Q1.(Data_Width - 1))
            assign internal_sig =  y_out[(OUT_W * j + (Data_Width - 1)) +: TRUNC_W];
            
            //Test overflow
            wire is_pos_overflow;
            wire is_neg_overflow;
            
            assign is_pos_overflow = ((internal_sig[TRUNC_W - 1] == 1'b0) && (| internal_sig[TRUNC_W - 2 : Data_Width - 1]));
            assign is_neg_overflow = ((internal_sig[TRUNC_W - 1] == 1'b1) && (~& internal_sig[TRUNC_W - 2 : Data_Width - 1]));
            
            //define infinity constant
            wire [Data_Width - 1 : 0] pos_max = {1'b0, {(Data_Width - 1){1'b1}}};
            wire [Data_Width - 1 : 0] neg_max = {1'b1, {(Data_Width - 1){1'b0}}};
            
            wire [Data_Width - 1 : 0] final_trunc_data = 
                    is_pos_overflow ? pos_max :
                    is_neg_overflow ? neg_max :
                    internal_sig[Data_Width - 1 : 0];
                    
            assign result[j * Data_Width +: Data_Width] = final_trunc_data;
        end
    endgenerate
    
endmodule
