`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.03.2022 18:17:58
// Design Name: 
// Module Name: sqrt
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


module sqrt
  #( parameter I_WIDTH = 16,
               F_WIDTH = 16)
  (input [I_WIDTH+F_WIDTH-1:0] N_in,
   output reg [I_WIDTH+F_WIDTH-1:0] out,
   input clk, rst, in_valid,
   output reg out_valid, ready
  );
  
  localparam IDLE = 0,
  			ITERATE = 1,
            DONE = 2;
  
  reg [1:0] state;
  reg [I_WIDTH+F_WIDTH-1:0] X;
  wire [I_WIDTH+2*F_WIDTH-1:0] X_in;
  wire [I_WIDTH+2*F_WIDTH-1:0] NX;
  
  reg [I_WIDTH+F_WIDTH-1:0] N;
  
  wire [I_WIDTH+2*F_WIDTH-1:0] NX2; 
  reg [I_WIDTH+F_WIDTH-1:0] R;
  //reg [I_WIDTH+F_WIDTH-1:0] R_old;
  reg X_valid, R_valid;
  
  reg [I_WIDTH+F_WIDTH-1:0] approx_mem [31:0];
  wire [I_WIDTH+F_WIDTH-1:0] approx;
  wire [I_WIDTH+2*F_WIDTH-1:0] out_in;
  reg [5:0] index;
  
  reg [2:0] iter;
  
  
  
  // initial approximation of 1/sqrt(N)
  
  initial begin
    $readmemb("sqrt_mem.txt",approx_mem);
  end
  
  
  always @ (*) begin
    index = 'b0;
    if (N_in > 32'h8000_0000)
      index = 'b11111;
    
    if (N_in <= 32'h8000_0000 && N_in > 32'h4000_0000)
      index = 'b11110;
    
    if (N_in <= 32'h4000_0000 && N_in > 32'h2000_0000)
      index = 'b11101;
    
    if (N_in <= 32'h2000_0000 && N_in > 32'h1000_0000)
      index = 'b11100;
    
    if (N_in <= 32'h1000_0000 && N_in > 32'h0800_0000)
      index = 'b11011; 
    
    if (N_in <= 32'h0800_0000 && N_in > 32'h0400_0000)
      index = 'b11010;
    
    if (N_in <= 32'h0400_0000 && N_in > 32'h0200_0000)
      index = 'b11001;
    
    if (N_in <= 32'h0200_0000 && N_in > 32'h0100_0000)
      index = 'b11000;
    
    if (N_in <= 32'h0100_0000 && N_in > 32'h0080_0000)
      index = 'b10111;   
    
    if (N_in <= 32'h0080_0000 && N_in > 32'h0040_0000)
      index = 'b10110;
    
    if (N_in <= 32'h0040_0000 && N_in > 32'h0020_0000)
      index = 'b10101;
    
    if (N_in <= 32'h0020_0000 && N_in > 32'h0010_0000)
      index = 'b10100;
    
    if (N_in <= 32'h0010_0000 && N_in > 32'h0008_0000)
      index = 'b10011;
    
    
    if (N_in <= 32'h0008_0000 && N_in > 32'h0004_0000)
      index = 'b10010;
    
    if (N_in <= 32'h0004_0000 && N_in > 32'h0002_0000)
      index = 'b10001;
    
    if (N_in <= 32'h0002_0000 && N_in > 32'h0001_0000)
      index = 'b10000;
    
    if (N_in <= 32'h0001_0000 && N_in > 32'h0000_8000)
      index = 'b1111;
    
    if (N_in <= 32'h0000_8000 && N_in > 32'h0000_4000)
      index = 'b1110;
    
    if (N_in <= 32'h0000_4000 && N_in > 32'h0000_2000)
      index = 'b1101;
    
    if (N_in <= 32'h0000_2000 && N_in > 32'h0000_1000)
      index = 'b1100;
    
    if (N_in <= 32'h0000_1000 && N_in > 32'h0000_0800)
      index = 'b1011;
    
    if (N_in <= 32'h0000_0800 && N_in > 32'h0000_0400)
      index = 'b1010;
    
    if (N_in <= 32'h0000_0400 && N_in > 32'h0000_0200)
      index = 'b1001;
    
    if (N_in <= 32'h0000_0200 && N_in > 32'h0000_0100)
      index = 'b1000;
    
    if (N_in <= 32'h0000_0100 && N_in > 32'h0000_0080)
      index = 'b111;
    
    if (N_in <= 32'h0000_0080 && N_in > 32'h0000_0040)
      index = 'b110;
    
    if (N_in <= 32'h0000_0040 && N_in > 32'h0000_0020)
      index = 'b101;
    
    if (N_in <= 32'h0000_0020 && N_in > 32'h0000_0010)
      index = 'b100;
    
    if (N_in <= 32'h0000_0010 && N_in > 32'h0000_0008)
      index = 'b11;
    
    if (N_in <= 32'h0000_0008 && N_in > 32'h0000_0004)
      index = 'b10;
    
    if (N_in <= 32'h0000_0004 && N_in > 32'h0000_0002)
      index = 'b1;
    
    if (N_in <= 32'h0000_0002 && N_in > 32'h0000_0000)
      index = 'b0; 
  end
  
  assign approx = approx_mem[index];

  assign NX = N*X << 4;
  assign NX2 = X*NX[I_WIDTH+2*F_WIDTH-1 -: I_WIDTH+F_WIDTH];
  //assign R = (32'h0003_0000 << 4 ) - NX2[I_WIDTH+2*F_WIDTH-1 -: I_WIDTH+F_WIDTH];
  assign X_in = ((X>>1)*R) >> 4;
  
  
  assign out_in = N*X;

  
  always @ (posedge clk) begin
    case (state)
    IDLE : begin
	  N <= N_in;
      X <= approx;
      R_valid <= 0;
      X_valid <= in_valid;     
    end
    ITERATE : begin
        if (R_valid)
            X <= X_in[I_WIDTH+2*F_WIDTH-1 -: I_WIDTH+F_WIDTH];
        
        if (X_valid)
            R <= (32'h0003_0000 << 4 ) - NX2[I_WIDTH+2*F_WIDTH-1 -: I_WIDTH+F_WIDTH];
        R_valid <= X_valid;
        X_valid <= R_valid;

    end
    endcase
  
  end
  
  always @ (posedge clk) begin
    
    if (rst) begin
      state <= IDLE;
      iter <= 0;
    end
    else begin
     
      case (state)
      IDLE : begin
        if (in_valid) begin
          if (N_in == 0) begin
            state <= DONE;
            out <= 0;
          end
          else
            state <= ITERATE;
        end
      end
      ITERATE : begin     
        if (iter == 'b11 && R_valid)
          state <= DONE;
        out <= out_in[I_WIDTH+2*F_WIDTH-1 -: I_WIDTH+F_WIDTH];
        if (R_valid)
            iter <= iter + 1;
      end
      DONE : begin
        state <= IDLE;
      end
      endcase
    end
  end
    
  always @ (*) begin
    ready = 0;
    out_valid = 0;
    case (state) 
     IDLE : ready = 1;
     DONE : out_valid = 1;  
    endcase 
  end
  
endmodule
