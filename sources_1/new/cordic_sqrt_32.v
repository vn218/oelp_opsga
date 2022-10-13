`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.06.2022 19:55:48
// Design Name: 
// Module Name: cordic_sqrt_32
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


/* Square root calculation (using Pipelining) architecture */

// Data path for single vectoring operation 
//parameters i specifies the index of the module (there are 15 in total)
module Vectoring_Single
  					 #(parameter i = 0,
    		  					 width = 16)
  
  					  (input clk,
                       input signed [width-1:0] xin,
                       input signed [width-1:0] yin,
                       input dir_in,
                       output dir_out,
                       input signed [width-1:0] x_ref,
                       output reg signed [width-1:0] x_out,y_out
                      );
  

  
  //definfing registers
  reg signed [width-1:0] x;
  reg signed [width-1:0] y;
  
  
  reg signed [width-1:0] x_add_out;
  reg signed [width-1:0] y_add_out;
  
  //wires
  wire [width-1:0] x_shift;
  wire [width-1:0] y_shift;
  
  //get the next X and Y value according to index of this module
  assign x_shift = xin >>> i;
  assign y_shift = yin >>> i;
  
  //control signal for next module (direction of next rotation)
  assign dir_out = (x_out < x_ref) & (y_out[width-1] == 0);
  
  //Determine the addition/subtraction according to the control signal
  always@(*)
    begin
      if(dir_in == 1)
        begin
          x_add_out = xin + y_shift;
          y_add_out = yin - x_shift;
        end
      else
        begin
          x_add_out = xin - y_shift;
          y_add_out = yin + x_shift;
        end
    end
  
  //latching the output
  always@(posedge clk) begin
    x_out <= x_add_out;
  	y_out <= y_add_out;
  end
    
endmodule

//Data path for single rotation operation (16 total)

module Rotation_Single
  					#(parameter i = 0,
    		  					 width = 16,
                      			 f_width = 14)
  
  					  (input clk,
                       input signed [width-1:0] xin,
                       input signed [width-1:0] yin,
                       input [1:0] dir_in,
                       input [width-1:0] sec,
                       output reg signed [width-1:0] x_out,y_out
                      );
  

  
  //definfing registers
  reg signed [width-1:0] x;
  reg signed [width-1:0] y;
  
  
  reg signed [width-1:0] x_add_out;
  reg signed [width-1:0] y_add_out;
  
  //wires
  wire [width-1:0] x_shift;
  wire [width-1:0] y_shift;
  wire [2*width-1:0] x_mult;
  wire [2*width-1:0] y_mult;
  
  //multiplying with secant so that the length of the vector increases even in the case of no rotation
  //so that the scaling factor at the end remains the same
  assign x_mult = sec*xin;
  assign y_mult = sec*yin;
  
  //get the next X and Y value according to index of this module
  assign x_shift = xin >>> i;
  assign y_shift = yin >>> i;
  
  //Determine the addition/subtraction according to the control signal
  always@(*)
    begin
      if(dir_in[0] == 1)
        begin
          x_add_out = xin + y_shift;
          y_add_out = yin - x_shift;
        end
      else
        begin
          x_add_out = xin - y_shift;
          y_add_out = yin + x_shift;
        end
    end
  
  //Rotation according to the control signal (add/sub/no rotation)
  always@(posedge clk) begin
    
    if (dir_in[1]^dir_in[0] == 0) begin
    	x_out <= x_add_out;
  		y_out <= y_add_out;
    end  
    else begin
      // scaled up version of the inputs in case of no rotation
      x_out <= x_mult[width+f_width-1:f_width];
      y_out <= y_mult[width+f_width-1:f_width];
    end
  end
     
endmodule


//Indexing module to find the most significant high bit
//Output is the minimum number of left shifts required to make the MSB of the 32-bit number high 
module index32_module(input [31:0] num , output reg [4:0] out);
  always@(*)
    begin
      casez(num)
        32'b1zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz : out = 'd0;
        32'b01zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz : out = 'd1;
        32'b001zzzzzzzzzzzzzzzzzzzzzzzzzzzzz : out = 'd2;
        32'b0001zzzzzzzzzzzzzzzzzzzzzzzzzzzz : out = 'd3;
        32'b00001zzzzzzzzzzzzzzzzzzzzzzzzzzz : out = 'd4;
        32'b000001zzzzzzzzzzzzzzzzzzzzzzzzzz : out = 'd5;
        32'b0000001zzzzzzzzzzzzzzzzzzzzzzzzz : out = 'd6;
        32'b00000001zzzzzzzzzzzzzzzzzzzzzzzz : out = 'd7;
        32'b000000001zzzzzzzzzzzzzzzzzzzzzzz : out = 'd8;
        32'b0000000001zzzzzzzzzzzzzzzzzzzzzz : out = 'd9;
        32'b00000000001zzzzzzzzzzzzzzzzzzzzz : out = 'd10;
        32'b000000000001zzzzzzzzzzzzzzzzzzzz : out = 'd11;
        32'b0000000000001zzzzzzzzzzzzzzzzzzz : out = 'd12;
        32'b00000000000001zzzzzzzzzzzzzzzzzz : out = 'd13;
        32'b000000000000001zzzzzzzzzzzzzzzzz : out = 'd14;
        32'b0000000000000001zzzzzzzzzzzzzzzz : out = 'd15;
        32'b00000000000000001zzzzzzzzzzzzzzz : out = 'd16;
        32'b000000000000000001zzzzzzzzzzzzzz : out = 'd17;
        32'b0000000000000000001zzzzzzzzzzzzz : out = 'd18;
        32'b00000000000000000001zzzzzzzzzzzz : out = 'd19;
        32'b000000000000000000001zzzzzzzzzzz : out = 'd20;
        32'b0000000000000000000001zzzzzzzzzz : out = 'd21;
        32'b00000000000000000000001zzzzzzzzz : out = 'd22;
        32'b000000000000000000000001zzzzzzzz : out = 'd23;
        32'b0000000000000000000000001zzzzzzz : out = 'd24;
        32'b00000000000000000000000001zzzzzz : out = 'd25;
        32'b000000000000000000000000001zzzzz : out = 'd26;
        32'b0000000000000000000000000001zzzz : out = 'd27;
        32'b00000000000000000000000000001zzz : out = 'd28;
        32'b000000000000000000000000000001zz : out = 'd29;
        32'b0000000000000000000000000000001z : out = 'd30;
        32'b00000000000000000000000000000001 : out = 'd31;
        default : out = 'd0;
      endcase
    end  
endmodule

//barrel shifter Left
module barrel_shift_left_32 (input [31:0] in, output [31:0] out, input [4:0] ctrl);
  
  wire [31:0] shift_0, shift_1, shift_2, shift_3, shift_4;
  
  
  //simple shifting operations according to the control signal
  
  //cascaded conditional shifters architecture
  
  assign shift_0 = ctrl[0] ? in << 1 : in;
  assign shift_1 = ctrl[1] ? shift_0 << 2 : shift_0;
  assign shift_2 = ctrl[2] ? shift_1 << 4 : shift_1;
  assign shift_3 = ctrl[3] ? shift_2 << 8 : shift_2;
  assign shift_4 = ctrl[4] ? shift_3 << 16 : shift_3;

  assign out = shift_4;
  
endmodule

//barrel Shifter right
module barrel_shift_right_32 (input [31:0] in, output [31:0] out, input [4:0] ctrl);
  
  wire [31:0] shift_0, shift_1, shift_2, shift_3, shift_4;
  
  
  //simple shifting operations according to the control signal
  
  //cascaded conditional shifters architecture
  
  assign shift_0 = ctrl[0] ? in >> 1 : in;
  assign shift_1 = ctrl[1] ? shift_0 >> 2 : shift_0;
  assign shift_2 = ctrl[2] ? shift_1 >> 4 : shift_1;
  assign shift_3 = ctrl[3] ? shift_2 >> 8 : shift_2;
  assign shift_4 = ctrl[4] ? shift_3 >> 16 : shift_3;

  assign out = shift_4;
  
endmodule


//main module for finding the squareroot
module cordic_sqrt_32 
  #( parameter width = 16,
    
    //fraction width for cordic operations
    f_width = 14,
    
    //fraction width of the output
    out_f_width = 6
  )
  (
    input [width-1:0] N,
    input clk, in_valid,
    output reg [width-1:0] sqrt,
    output out_valid
  );
  
  //defining the parameters
  
  //predetermined directions of rotation for 0 deg
  localparam [0:15] zero_rot = 16'b0111010011110011;
  
  //scaling factors to compensate for optimisation of taking out cos terms.
  //Extra root 2 for cases in which input was scaled down be applying an odd number of right shifts
  localparam [width-1:0] sf = 32'b00100110110111010011101101101010,
  					sf_root_2 =32'b00110110111101100101011011000101;
  
  //latency of the entire module
  localparam latency = 17;
  
  //number of left shifts required to make the MSB high
  wire [$clog2(width)-1:0] index;
  
  //number of right shifts required to scale down the input to the range [0.5,1)
  wire [$clog2(width):0] init_sf;
  assign init_sf = width - index;
  
  //delay line for init_sf. To be used for scaling back up the output
  reg [$clog2(width):0] init_sf_delay [15:0];
  
  // left_barrel_out : input scaled up such that MSB is high
  wire [width-1:0] left_barrel_out, scaled_N;
  
  //rigth shifting left_barrel_out such that the initial input gets scaled down to the range [0.5,1) in the new Q point rep.
  //Note that input is an integer
  assign scaled_N = left_barrel_out >> (width - f_width);
  
  //out_valid is just a delayed version of in_valid
  reg valid_delay [latency-1:0];
  assign out_valid = valid_delay[latency-1];
  
  //array to store the secant value corresponding to each index (1/cos(angle))
  reg [width-1:0] sec [15:0];
  
  //read from the file the sec(angle) for each angle
  initial begin
    $readmemb("sec.txt",sec);
  end
  
  //arrays containing x_out, x_in, y_out, y_in of all the vectoring and rotation modules
  wire [width-1:0] vector_x_out [14:0];
  wire [width-1:0] vector_y_out [14:0];
  wire [width-1:0] rotate_x_out [15:0];
  wire [width-1:0] rotate_y_out [15:0];
  
  //array containing dir_out of all vectoring modules 
  wire vector_dir_out [14:0];
  
  wire [2*width-1:0] N2;
  wire [width-1:0] x_init;
  
  //computing the reference x-coordinate for vectoring operation = 2*scaled_N - 1
  assign N2 = (32'b10 << f_width)*scaled_N;
  assign x_init = N2[width+f_width-1:f_width] - (32'b1 << f_width);
  
  //array of registers containing the x_ref (reference x-coordinate) for each stage.
  reg [width-1:0] x_ref [14:0];
  reg [2*width-1:0] x_ref_in [14:0];
  
  //scaling the output to compensate the cordic optimisation
  wire [2*width-1:0] scaled_out;
  assign scaled_out = init_sf_delay[15][0] ? rotate_x_out[15]*sf_root_2 : rotate_x_out[15]*sf;
   
  //right shifting so that we have final output in the Q point representation of the output
  // number of right shifts = f_width - out_f_width - (init_sf/2)
  // out_f_width chosen such that the above value is always non negative
  wire [width-1:0] right_barrel_out;
  wire [$clog2(width)-1:0] right_barrel_ctrl;
  
  assign right_barrel_ctrl = f_width - out_f_width - (init_sf_delay[15] >> 1); 
  
  //register containing the final output
  always @ (posedge clk) begin
    sqrt <= right_barrel_out;
  end
  
  //genvar and integer for for loops
  genvar i;
  integer j;
  
  //for loop for generating cascading modules for vectoring operation 
  for (i=1;i<15;i=i+1) begin
  Vectoring_Single
   #(.i(i),
     .width(width))
    Vectoring
    (.clk(clk),
     .xin(vector_x_out[i-1]),
     .yin(vector_y_out[i-1]),
     .dir_in(vector_dir_out[i-1]),
     .dir_out(vector_dir_out[i]),
     .x_ref(x_ref[i]),
     .x_out(vector_x_out[i]),
     .y_out(vector_y_out[i])
    );
  end
  
  //for loop for generating cascading modules for rotation operation
  for (i=1;i<16;i=i+1) begin   
     Rotation_Single
       #(.i(i),
         .width(width),
         .f_width(f_width))
        Rotation
        (.clk(clk),
         .xin(rotate_x_out[i-1]),
         .yin(rotate_y_out[i-1]),
         
          //concatenation of corresponding zero_rot and dir_out of previous vectoring module
         .dir_in({vector_dir_out[i-1], zero_rot[i]}),
         
         .sec(sec[i]),
         .x_out(rotate_x_out[i]),
         .y_out(rotate_y_out[i])
        );
  
  end
  
  //module for first vectoring operation
    Vectoring_Single
  #(.i(0),
    .width(width))
    Vectoring_first
    (.clk(clk),
     .xin({{width-f_width-1{1'b0}},1'b1,{f_width{1'b0}}}),
     .yin('b0),
     .dir_in('b0),
     .dir_out(vector_dir_out[0]),
     .x_ref(x_ref[0]),
     .x_out(vector_x_out[0]),
     .y_out(vector_y_out[0])
    );
  
  //module for first rotation operation
    Rotation_Single
  #(.i(0),
    .width(width),
    .f_width(f_width))
    Rotation_first
    (.clk(clk),
     .xin(N == 0 ? 0 : {{width-f_width-1{1'b0}},1'b1,{f_width{1'b0}}}),
     .yin('b0),
     .dir_in('b00),
     .sec(sec[0]),
     .x_out(rotate_x_out[0]),
     .y_out(rotate_y_out[0])
    );
  
  //x_ref is multiplied by secant of the corresponding stage.
  //This is to make sure that our reference coordinate scales up with the vector in vectoring mode
  always @ (*) begin
    x_ref_in[0] <= x_init*sec[0];
    
    for(j=1;j<15;j=j+1) begin
      x_ref_in[j] = x_ref[j-1]*sec[j];
    end
  
  end
  always @ (posedge clk) begin
    
    for(j=0;j<15;j=j+1) begin
      x_ref[j] <= x_ref_in[j][width+f_width-1:f_width];
    end
  
  end
  
  //init_sf delay line
  always @ (posedge clk) begin
    
    init_sf_delay[0] <= init_sf;
    
    for(j=1;j<16;j=j+1) begin
      init_sf_delay[j] <= init_sf_delay[j-1];
    end
  
  end
  
  //valid delay line
  always @ (posedge clk) begin
    
    valid_delay[0] <= in_valid;
    
    for(j=1;j<latency;j=j+1) begin
      valid_delay[j] <= valid_delay[j-1];
    end
  
  end
  
  
  //instantiating remaining modules
  index32_module index_module(.num(N) , 
                       .out(index)
                      ); 

  
  barrel_shift_left_32 brl_shft_in(.in(N), 
                                   .out(left_barrel_out),
                                .ctrl(index));
  
 
  barrel_shift_right_32 brl_shft_out(.in(scaled_out[width+f_width-1:f_width]), 
                                     .out(right_barrel_out),
                                     .ctrl(right_barrel_ctrl));
  
endmodule
