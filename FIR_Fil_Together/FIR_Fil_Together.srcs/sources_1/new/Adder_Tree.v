`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/28 19:15:05
// Design Name: 
// Module Name: Adder_Tree
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


module Adder_Tree_Recursive #(
    parameter NUM = 4,      
    parameter WIDTH = 16    
)(
    input  signed [NUM * WIDTH - 1 : 0] din,
    output signed [WIDTH - 1 : 0] dout 
);
    
    generate
        // [Base Case 1]: Only 1 operand, pass through directly
        if (NUM == 1) begin : gen_base_1
            assign dout = din;
        end
        // [Base Case 2]: Exactly 2 operands, perform a direct addition
        else if (NUM == 2) begin : gen_base_2
            wire signed [WIDTH - 1 : 0] in0 = din[1*WIDTH - 1 : 0];
            wire signed [WIDTH - 1 : 0] in1 = din[2*WIDTH - 1 : WIDTH];
            assign dout = in0 + in1;
        end
        // [Recursive Step]: More than 2 operands, split into two halves for the left and right sub-trees
        else begin : gen_tree
            // Calculate the number of operands for each half (if odd, RIGHT gets 1 more than LEFT)
            localparam LEFT_NUM  = NUM / 2;
            localparam RIGHT_NUM = NUM - LEFT_NUM;

            wire signed [WIDTH - 1 : 0] left_out;
            wire signed [WIDTH - 1 : 0] right_out;

            // Recursively instantiate the left half
            Adder_Tree_Recursive #(
                .NUM(LEFT_NUM),
                .WIDTH(WIDTH)
            ) left_tree (
                .din(din[LEFT_NUM * WIDTH - 1 : 0]),
                .dout(left_out)
            );

            // Recursively instantiate the right half
            Adder_Tree_Recursive #(
                .NUM(RIGHT_NUM),
                .WIDTH(WIDTH)
            ) right_tree (
                // Extract the remaining upper bits for the right sub-tree
                .din(din[NUM * WIDTH - 1 : LEFT_NUM * WIDTH]),
                .dout(right_out)
            );

            // Finally, add the results from the two sub-trees at this current level!
            assign dout = left_out + right_out;
        end
    endgenerate

endmodule
