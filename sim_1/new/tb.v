`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.02.2022 03:17:48
// Design Name: 
// Module Name: tb
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


module tb(
   );
parameter SPECTRAL_BANDS = 188,
    WIDTH = 16,
    MAC_WIDTH = 32,
    TOTAL_PIXELS = 500,
    TOTAL_ENDMEMBERS = 19; // excluding m1

reg [WIDTH-1:0] image [0:TOTAL_PIXELS*SPECTRAL_BANDS-1];

reg [4*WIDTH-1:0] pixel_in;
reg in_axi_valid;
reg in_axi_ready;
wire [$clog2(TOTAL_PIXELS)-1:0] endmem_index_out;
wire out_axi_valid;
wire out_axi_ready;
wire intr;
wire finish;
reg clk;
reg rst;
 
top
#(.SPECTRAL_BANDS(SPECTRAL_BANDS),
  .IN_WIDTH(WIDTH),
  .T_WIDTH(32),
  .MAC_WIDTH(MAC_WIDTH),
  .TOTAL_PIXELS(TOTAL_PIXELS),
  .TOTAL_ENDMEMBERS(TOTAL_ENDMEMBERS)
)
DUT
(
.pixel_in(pixel_in),
.in_axi_valid(in_axi_valid),
.in_axi_ready(1'b1),
.endmem_index_out(endmem_index_out),
.out_axi_valid(out_axi_valid),
.out_axi_ready(out_axi_ready),
.intr(intr),
.finish(finish),
.clk(clk),
.rst(rst)
    );
    
integer pixel = 0, spectral_band = 0 ;

initial begin
    clk = 1'b0;
    forever
    begin
        #5 clk = ~clk;
        if (finish)
            $finish;
    end
end

initial begin
    $readmemb("test_real_188.txt",image); 
//    image[9] = 10;
//    image[10] = 20;
//    image[11] = 30;
//    image[0] = 80;
//    image[1] = 120;
//    image[2] = 20;
//    image[3] = 40;
//    image[4] = 40;
//    image[5] = 30;
//    image[6] = 220;
//    image[7] = 50;
//    image[8] = 100;
    
end

initial begin
    rst = 1;
    #20
    rst = 0;
    
    while ( !finish ) begin
        in_axi_valid <= 0;
        @ (posedge intr)
        for (spectral_band = 0;spectral_band < SPECTRAL_BANDS/4;spectral_band = spectral_band + 1) begin
            @ (posedge clk)
            pixel_in <= {image[pixel*SPECTRAL_BANDS + spectral_band*4 + 3],image[pixel*SPECTRAL_BANDS + spectral_band*4 + 2],image[pixel*SPECTRAL_BANDS + spectral_band*4 + 1],image[pixel*SPECTRAL_BANDS + spectral_band*4]};        
            in_axi_valid <= 1;    
        end
        @ (posedge clk)
        pixel = pixel + 1;
        if (pixel == TOTAL_PIXELS) begin
            pixel = 0;
        end        
        
    end
  
end
    
endmodule
