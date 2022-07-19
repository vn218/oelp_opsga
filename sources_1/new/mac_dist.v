`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.06.2022 17:25:30
// Design Name: 
// Module Name: mac_dist
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


module mac_dist
  #(parameter IN_WIDTH = 16,
              CONCAT = 4)
 (
  input signed [CONCAT*IN_WIDTH-1:0] in_1,
  input signed [CONCAT*IN_WIDTH-1:0] in_2,
  input mac_reset,
  input in_valid,
  output reg out_valid,
  output reg signed [2*IN_WIDTH-1:0] out,
  input clk, rst
      );
  
  
  reg signed [2*IN_WIDTH-1:0] product_sum;
  reg signed [2*IN_WIDTH-1:0] out_in;
  wire signed [IN_WIDTH-1:0] inputs1 [CONCAT-1:0];
  wire signed [IN_WIDTH-1:0] inputs2 [CONCAT-1:0];
  
  genvar j;
  integer i;
  
    for (j = CONCAT; j > 0; j = j - 1) begin
        assign inputs1[j-1] = in_1[j*IN_WIDTH - 1 -: IN_WIDTH];
        assign inputs2[j-1] = in_2[j*IN_WIDTH - 1 -: IN_WIDTH]; 
    end
  
  always @ (*) begin    
    
    product_sum = 0;
    for (i = CONCAT; i > 0; i = i - 1) begin
        product_sum = product_sum + inputs1[i-1]*inputs2[i-1]; 
    end
    
    if (in_valid)
      out_in = product_sum;  
    else begin
      out_in = 0;
    end
    
  end
  
  
  always @ (posedge clk) begin
    if (rst ) begin
      out <= 0;
      out_valid <= 0;
    end
    else if (mac_reset) begin
      out <= out_in;       
    end
    else begin
      out <= out_in + out; 
    end
    out_valid <= in_valid;
  end      
endmodule
