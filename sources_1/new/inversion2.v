`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.06.2022 19:59:02
// Design Name: 
// Module Name: inversion2
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


module inversion2 
#( parameter F_WIDTH = 16,
  			 I_WIDTH = 16,
  			 SPECTRAL_BANDS = 103,
             TOTAL_ENDMEMBERS = 20,
             MAC_F_WIDTH_1 = 0,
             MAC_I_WIDTH_1 = 32  //in_data is right shifted by MAC_I_WIDTH_1 - I_WIDTH before further calculations  ///// scaling 
  )
 (
  input [I_WIDTH-1:0] U_in,
  input [I_WIDTH-1:0] new_vectorT_in,

  // in_data = new_vectorT * U
  output reg [$clog2(TOTAL_ENDMEMBERS)-1:0] U_col,
  output reg [$clog2(SPECTRAL_BANDS)-1:0] U_row,
  output [$clog2(TOTAL_ENDMEMBERS)-1:0] new_vectorT_row,
  output reg [$clog2(SPECTRAL_BANDS)-1:0] new_vectorT_col,

  output reg addr_valid_out,
  input valid_in,

  output reg [I_WIDTH+F_WIDTH-1:0] inverse,
  input [$clog2(TOTAL_ENDMEMBERS)-1:0] inv_row_in, inv_col_in,
  input inv_addr_valid_in,
  //output [$clog2(TOTAL_ENDMEMBERS*TOTAL_ENDMEMBERS)-1:0] inv_addr_out,
  input [$clog2(TOTAL_ENDMEMBERS)-1:0] size,
  output reg inv_out_valid,
  output done,
  input start,
  input clk,rst
 );
  
  
  localparam IDLE = 4'b0000,
  			 READ = 4'b0001,          // read U, new_vectorT and calculate in_data
             CHOL_1 = 4'b0010,        // calculate temp
             CHOL_SQRT = 4'b0011,     // for L(i,i)
             CHOL_DIV = 4'b0100,      // for rest of L
             INV_1 = 4'b0101,         // 1/L(i,i)
             INV_2 = 4'b0110,         // calculate temp
             INV_3 = 4'b0111,         
             MULT = 4'b1000,
             DONE = 4'b1001;
  
  reg [3:0] state;
  assign done = (state == DONE);
  
  reg [F_WIDTH+I_WIDTH-1:0] in_data [TOTAL_ENDMEMBERS-1:0];  
  reg [$clog2(TOTAL_ENDMEMBERS)-1:0] in_data_ptr;
 
  
  reg signed [F_WIDTH+I_WIDTH-1:0] L [(((TOTAL_ENDMEMBERS)*(TOTAL_ENDMEMBERS+1))>>1)-1:0];
  reg signed [F_WIDTH+I_WIDTH-1:0] L_inv [(((TOTAL_ENDMEMBERS)*(TOTAL_ENDMEMBERS+1))>>1)-1:0];
  reg signed [F_WIDTH+I_WIDTH-1:0] inv [(((TOTAL_ENDMEMBERS)*(TOTAL_ENDMEMBERS+1))>>1)-1:0];
  wire [$clog2(((TOTAL_ENDMEMBERS)*(TOTAL_ENDMEMBERS+1))>>1)-1:0] L_addr_1, L_addr_2, inv_addr_1, inv_addr_2;
  reg [$clog2(TOTAL_ENDMEMBERS)-1:0] L_row_1, L_col_1, L_row_2, L_col_2;
  wire [$clog2(TOTAL_ENDMEMBERS)-1:0] inv_row, inv_col;
  reg [$clog2(TOTAL_ENDMEMBERS)-1:0] chol_ctr_r, chol_ctr_w;  // k, j

  
  assign L_addr_1 = (((L_row_1)*(L_row_1+1))>>1) + L_col_1; 
  assign L_addr_2 = (((L_row_2)*(L_row_2+1))>>1) + L_col_2; 
  
  
  assign inv_row = (inv_row_in > inv_col_in) ? inv_row_in : inv_col_in;
  assign inv_col = (inv_row_in > inv_col_in) ? inv_col_in : inv_row_in; 
  assign inv_addr_2 = (((inv_row)*(inv_row+1))>>1) + inv_col; 

  always @ (posedge clk) begin
    inverse <= inv[inv_addr_2];
    inv_out_valid <= inv_addr_valid_in;
  end
  

  
  
  wire [I_WIDTH+F_WIDTH-1:0] U, new_vectorT;
  
  // widths of U and new_vectorT should match with I_WIDTH and F_WIDTH parameters of mac
  assign U = {{MAC_I_WIDTH_1-I_WIDTH{U_in[I_WIDTH-1]}},U_in,{MAC_F_WIDTH_1{1'b0}}};
  assign new_vectorT = {{MAC_I_WIDTH_1-I_WIDTH{new_vectorT_in[I_WIDTH-1]}},new_vectorT_in,{MAC_F_WIDTH_1{1'b0}}};
  
  assign new_vectorT_row = size;
  
  reg signed [I_WIDTH+F_WIDTH-1:0] mac_in_1;
  reg signed [I_WIDTH+F_WIDTH-1:0] mac_in_2;
  wire signed [I_WIDTH+F_WIDTH-1:0] mac_out;
  wire mac_out_valid;
  reg mac_rst, mac_in_valid, mac_in_valid_in;
  reg [15:0] mac_ctr;
  reg [2:0] mac_mode;
  
  assign inv_addr_1 = mac_ctr[$clog2(((TOTAL_ENDMEMBERS)*(TOTAL_ENDMEMBERS+1))>>1)-1:0];
   
  reg signed [F_WIDTH+I_WIDTH-1:0] temp;

  
  wire signed [I_WIDTH+F_WIDTH-1:0] divider_n, divider_d, divider_out;
  reg divider_in_valid;
  wire divider_out_valid;
  wire signed [I_WIDTH+F_WIDTH-1:0] inv_divider_out;
  reg inv_divider_in_valid;
  wire inv_divider_out_valid;
  assign divider_n = temp;
  assign divider_d = L[L_addr_1];
  
  
  wire [I_WIDTH+F_WIDTH-1:0] sqrt_n, sqrt_out;
  reg sqrt_in_valid;
  wire sqrt_out_valid, sqrt_ready;
  assign sqrt_n = temp;
  
  
  
  always @ (posedge clk) begin
    if (rst) begin
      U_col <= 0;
      U_row <= 0;
      new_vectorT_col <= 0;
      in_data_ptr <= 0;
      mac_ctr <= 0;
      chol_ctr_r <= 0;
      chol_ctr_w <= 0;
    end
    else begin
      case (state) 
        
        READ : begin
          if (addr_valid_out) begin
            if (U_row == SPECTRAL_BANDS - 1) begin
              U_row <= 0;
              if (U_col == size) begin
                U_col <= 0;
              end
              else begin
                U_col <= U_col + 1;
              end
            end
            else begin
              U_row <= U_row + 1;
            end

            if (new_vectorT_col == SPECTRAL_BANDS - 1) begin
              new_vectorT_col <= 0;
            end
            else begin
              new_vectorT_col <= new_vectorT_col + 1;
            end
          end
        
          
          if (mac_out_valid) begin
            if (mac_ctr == SPECTRAL_BANDS-1) begin
              in_data[in_data_ptr] <= mac_out;
              mac_ctr <= 0;
              if (size == 0)
                temp <= mac_out;
              else
                temp <= in_data[0];
              if (in_data_ptr == size) begin
                in_data_ptr <= 0;
              end
              else begin
                in_data_ptr <= in_data_ptr + 1;
              end
            end
            else begin
              mac_ctr <= mac_ctr + 1;
            end         
          end  
        end
        CHOL_1 : begin
          if (mac_in_valid) begin
            if (chol_ctr_r == chol_ctr_w - 1) begin
              chol_ctr_r <= 0;
            end
            else begin
              chol_ctr_r <= chol_ctr_r + 1;
            end
          end
          if (mac_out_valid) begin
            if (mac_ctr == chol_ctr_w - 1) begin
              mac_ctr <= 0;
              temp <= in_data[chol_ctr_w] - mac_out;
            end
            else begin
              mac_ctr <= mac_ctr + 1;
            end
          end
        end
        CHOL_SQRT : begin
          
          if (sqrt_out_valid) begin
            L[L_addr_2] <= sqrt_out;
            chol_ctr_w <= 0;
            
            temp <= ({{3{1'b0}},1'b1,{28{1'b0}}} >>> 14); ////scaling
          end
        
        end
        
        CHOL_DIV : begin
          
          if (divider_out_valid) begin
            L[L_addr_2] <= divider_out;
            chol_ctr_w <= chol_ctr_w + 1;
          end

        end
        INV_1 : begin
          if (inv_divider_out_valid) begin //////////////////////////testing
            L_inv[L_addr_1] <= inv_divider_out; //////////////////////////testing
          end        
        end
        
        INV_2 : begin
          if (mac_in_valid) begin
            if (chol_ctr_r == size - 1) begin
              if (chol_ctr_w == size - 1) begin
                chol_ctr_r <= 0;
              end
              else begin
                chol_ctr_r <= chol_ctr_w + 1;
              end
            end
            else begin
              chol_ctr_r <= chol_ctr_r + 1;
            end
          end
          if (mac_out_valid) begin
            if (mac_ctr == size - chol_ctr_w - 1) begin
              mac_ctr <= 0;
              temp <= mac_out;
            end
            else begin
              mac_ctr <= mac_ctr + 1;
            end
          end           
        end
        
        INV_3 : begin
          if (mac_out_valid) begin
            L_inv[L_addr_1] <= mac_out;
            if (chol_ctr_w == size -1) begin
              chol_ctr_w <= 0;
            end
            else begin
              chol_ctr_w <= chol_ctr_w + 1;
            end
          end
        end
        
        MULT : begin   // here chol_ctr_r and chol_ctr_w -> columns of the elements to be read
          if (mac_in_valid) begin
            if (chol_ctr_w == chol_ctr_r) begin
              chol_ctr_w <= 0;
              if (chol_ctr_r == size) begin
                chol_ctr_r <= 0;  
              end
              else begin
                chol_ctr_r <= chol_ctr_r + 1;
              end
            end
            else begin
              chol_ctr_w <= chol_ctr_w + 1;
            end
          end
          if (mac_out_valid) begin
            
            if (mac_ctr >= ((size)*(size +'b1))>>1)
              inv[inv_addr_1] <= mac_out;
            else
              inv[inv_addr_1] <= inv[inv_addr_1] + mac_out;
            
            if (mac_ctr == ((size)*(size +'b11))>>1) begin
              mac_ctr <= 0;
            end
            else begin
              mac_ctr <= mac_ctr + 1;
            end
          end
        end
      
      
      endcase
    end
  
  end
  
  always @ (posedge clk) begin
    if (rst) begin
      addr_valid_out <= 0;
      mac_in_valid_in <= 0;
      divider_in_valid <= 0;
      sqrt_in_valid <= 0;
    end
    else begin
      case (state) 
        
        IDLE: begin
          
          if (start)
            addr_valid_out <= 1;
        
        end
        
        READ : begin
          
          
          if (addr_valid_out)
            if (U_row == SPECTRAL_BANDS - 1)
              if (U_col == size) 
                addr_valid_out <= 0;
        
          
          if (mac_out_valid) 
            if (mac_ctr == SPECTRAL_BANDS-1)
              if (in_data_ptr == size) 
                if (size == 0)
                  sqrt_in_valid <= 1;
                else
                  divider_in_valid <= 1;

        end
        
        CHOL_1 : begin
          if (mac_in_valid)
            if (chol_ctr_r == chol_ctr_w - 1)
              mac_in_valid_in <= 0;

          if (mac_out_valid) 
            if (mac_ctr == chol_ctr_w - 1) 
              if (chol_ctr_w == size)
                sqrt_in_valid <= 1;
              else
                divider_in_valid <= 1;              
        end
        
        CHOL_SQRT : begin
          sqrt_in_valid <= 0;
          
          if (sqrt_out_valid)
            inv_divider_in_valid <= 1; //////////////////////////////testing
        
        end
        
        CHOL_DIV : begin
          divider_in_valid <= 0;
          
          if (divider_out_valid)
            mac_in_valid_in <= 1;
          
        end
        
        INV_1 : begin
          inv_divider_in_valid <= 0;   /////////////////////////////testing
          if (inv_divider_out_valid) begin
              mac_in_valid_in <= 1;
          end
        end
        
        INV_2 : begin
          if (mac_in_valid) begin 
            if (chol_ctr_r == size - 1) begin
              mac_in_valid_in <= 0;
            end  
          end            
          else if (mac_out_valid) begin
            if (mac_ctr == size - chol_ctr_w - 1) begin
              mac_in_valid_in <= 1;
            end  
          end    
        
        end
        
        INV_3 : begin
          mac_in_valid_in <= 0;
          if (mac_out_valid) begin
            mac_in_valid_in <= 1;
          end
        end
        
        MULT : begin
          if (mac_in_valid)
            if (chol_ctr_w == chol_ctr_r)
              if (chol_ctr_r == size) 
                mac_in_valid_in <= 0;  
        end
        
      endcase
    end
  
  end
  
  always @ (posedge clk) begin
    if (rst) begin
      state <= IDLE;
    end
    else begin
      case (state)  
        IDLE: begin      
          
          if (start)
            state <= READ;
        
        end    
        
        READ : begin

          if (mac_out_valid) 
            if (mac_ctr == SPECTRAL_BANDS-1)
              if (in_data_ptr == size) 
                if (size == 0)
                  state <= CHOL_SQRT;
                else
                  state <= CHOL_DIV;

        end
        
        CHOL_1 : begin

          if (mac_out_valid) 
            if (mac_ctr == chol_ctr_w - 1) 
              if (chol_ctr_w == size)
                state <= CHOL_SQRT;
              else
                state <= CHOL_DIV;              
        end
        
        CHOL_SQRT : begin
          
          if (sqrt_out_valid)
            state <= INV_1;
        
        end
        
        CHOL_DIV : begin
          
          if (divider_out_valid)
            state <= CHOL_1;
          
        end
        
        INV_1 : begin
        
          if (inv_divider_out_valid) /////////////////testing
            if (size == 0)
              state <= MULT;
            else
              state <= INV_2;
        
        end
        
        INV_2 : begin
          
          if (mac_out_valid)
            if (mac_ctr == size - chol_ctr_w - 1)
              state <= INV_3;
        
        end
        
        INV_3 : begin
         
          if (mac_out_valid)
            if (chol_ctr_w == size - 1)
              state <= MULT;
            else
              state <= INV_2;
        
        end
        
        MULT : begin
          if (mac_out_valid)
            if (mac_ctr == ((size)*(size +'b11))>>1)
              state <= DONE;  
        end
        
        DONE : begin
          
          state <= IDLE;
          
        end
        
      endcase
    end
  
  end
  
  always @ (*) begin
    mac_in_valid = mac_in_valid_in;
    mac_in_1 = U;
    mac_in_2 = new_vectorT;
    mac_rst = (mac_out_valid & (mac_ctr == SPECTRAL_BANDS-1));
    mac_mode = 3'b000;
    case (state) 
      IDLE: begin
        mac_rst = 1;
        mac_in_valid = 0;
      end
      READ : begin
        mac_rst = (mac_out_valid & (mac_ctr == SPECTRAL_BANDS-1));
        mac_in_1 = U;
        mac_in_2 = new_vectorT;
        mac_mode = 3'b000;
        mac_in_valid = valid_in;
      end
      CHOL_1 : begin
        mac_rst = (mac_out_valid & (mac_ctr == chol_ctr_w - 1));
        mac_in_1 = L[L_addr_1];
        mac_in_2 = L[L_addr_2];
        mac_mode = 3'b011;
      end
      INV_2 : begin
        mac_rst = (mac_out_valid & (mac_ctr == size - chol_ctr_w - 1));
        mac_in_1 = L_inv[L_addr_1];
        mac_in_2 = (L[L_addr_2]);// << 8); /////////scaling
        mac_mode = 3'b001;
      end
      INV_3 : begin
        mac_rst = mac_out_valid;
        mac_in_1 = -temp;
        mac_in_2 = L_inv[L_addr_2];
        mac_mode = 3'b011;
      end
      MULT : begin
        mac_rst = 1;
        mac_in_1 = L_inv[L_addr_1] ; 
        mac_in_2 = L_inv[L_addr_2] ;
        mac_mode = 3'b010;
      end
    endcase
  
  end
  
  always @ (*) begin
    //mac_in_valid = mac_in_valid_in;
    L_row_1 = chol_ctr_w;   
    L_col_1 = chol_ctr_r;
    L_row_2 = size;         
    L_col_2 = chol_ctr_r;  
    case (state) 
      CHOL_1 : begin
        // L(j,k)
        L_row_1 = chol_ctr_w;   
        L_col_1 = chol_ctr_r;   
        
        // L(i,k)
        L_row_2 = size;         
        L_col_2 = chol_ctr_r;
      end
      CHOL_SQRT, CHOL_DIV : begin
        // L(j,j)
        L_row_1 = chol_ctr_w;
        L_col_1 = chol_ctr_w;
        
        // L(i,j)
        L_row_2 = size;
        L_col_2 = chol_ctr_w;       
      end
      INV_1 : begin
        L_row_1 = size;
        L_col_1 = size;
      end
      INV_2 : begin
        L_row_1 = chol_ctr_r;
        L_col_1 = chol_ctr_w;
        L_row_2 = size;
        L_col_2 = chol_ctr_r;      
      end
      INV_3 : begin
        L_row_1 = size;
        L_col_1 = chol_ctr_w;
        L_row_2 = size;
        L_col_2 = size;
      end
      MULT : begin
        L_row_1 = size;
        L_col_1 = chol_ctr_r;
        L_row_2 = size;
        L_col_2 = chol_ctr_w;
      end
    endcase
  
  end
  
  
  mac_fixed
  #(.F_WIDTH(MAC_F_WIDTH_1),
    .I_WIDTH(MAC_I_WIDTH_1),
    .F_WIDTH_2(21),
    .I_WIDTH_2(4),
    .F_WIDTH_3(23),  // inverse scaling = 2**((28-F_WIDTH_3)*2)
    .I_WIDTH_3(4),
    .F_WIDTH_4(28),
    .I_WIDTH_4(4)
  )
  mac 
  (
    .in_1(mac_in_1),
    .in_2(mac_in_2),
    .mac_reset(mac_rst),
    .in_valid(mac_in_valid),
    .mode(mac_mode),
    .out_valid(mac_out_valid),
    .out(mac_out),
    .clk(clk), 
    .rst(rst)
      );
 
  divider
  #(.I_WIDTH(4),
    .F_WIDTH(28),
    .OUT_I_WIDTH(4),
    .OUT_F_WIDTH(28)
  )  
  divider
  (
    .N_in(divider_n), 
    .D_in(divider_d),
    .clk(clk), 
    .rst(rst), 
    .in_valid(divider_in_valid),
    .ready(), 
    .out_valid(divider_out_valid),
    .out(divider_out)
);
  
    divider
  #(.I_WIDTH(4),
    .F_WIDTH(28),
    .OUT_I_WIDTH(4),
    .OUT_F_WIDTH(28)
  )  
  inv_divider
  (
    .N_in(divider_n), 
    .D_in(divider_d),
    .clk(clk), 
    .rst(rst), 
    .in_valid(inv_divider_in_valid),
    .ready(), 
    .out_valid(inv_divider_out_valid),
    .out(inv_divider_out)
);
  
  cordic_sqrt_32
  #(.width(32),
    .f_width(30),
    .out_f_width(14)
  )  
  sqrt
  (
    .N(sqrt_n), 
    .clk(clk), 
    .in_valid(sqrt_in_valid),
    .out_valid(sqrt_out_valid),
    .sqrt(sqrt_out)
);
  
  
  
endmodule
