`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/28 19:16:21
// Design Name: 
// Module Name: Parallel_Adder_Tree
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


module Parallel_Adder_Tree
    #(
     parameter Tap_Num = 4,
     parameter Data_Width = 16
     )
     (
     input signed [Tap_Num * Tap_Num * Data_Width - 1 : 0] mul_data,
     output signed [Tap_Num * Data_Width - 1 : 0] y_out
     );

    // Parallel Calculate Tap_Num Adder Trees
    generate
        genvar i;
        for (i = 0; i < Tap_Num; i = i + 1) begin : gen_adder_trees
            
            wire signed [Tap_Num * Data_Width - 1 : 0] tree_in_data;
            assign tree_in_data = mul_data[(i + 1) * Tap_Num * Data_Width - 1 : i * Tap_Num * Data_Width];
            
            //Instantiate Adder Tree
            Adder_Tree_Recursive 
           #(
                .NUM(Tap_Num),
                .WIDTH(Data_Width)
            ) u_tree 
            (
                .din(tree_in_data), 
                
                .dout(y_out[(i + 1) * Data_Width - 1 : i * Data_Width])
            );
            
        end
    endgenerate

endmodule
