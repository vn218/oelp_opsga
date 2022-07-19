`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.06.2022 15:02:02
// Design Name: 
// Module Name: control_logic_increased_bw
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

////////////OP-SGA increased bandwidth
module control_logic3
#(parameter SPECTRAL_BANDS = 100,
    IN_WIDTH = 16,
    T_WIDTH = 32,
    MAC_WIDTH = 36,
    TOTAL_PIXELS = 100000,
    TOTAL_ENDMEMBERS = 20
)
(
input [IN_WIDTH-1:0] pixel_in,
input in_axi_valid,
input in_axi_ready,
output [$clog2(TOTAL_PIXELS)-1:0] endmem_index_out,
output out_axi_valid,
output reg out_axi_ready,
output reg intr,
output reg [MAC_WIDTH-1:0] mac_out_1,
output reg [MAC_WIDTH-1:0] mac_out_2,
output reg mac_reset,
output reg [2:0] mac_mode,
output reg mac_valid_out,
//output reg [4:0] state,
output reg finish,
input [MAC_WIDTH-1:0] mac_in,
input mac_valid_in,
input clk,
input rst,
output signed [IN_WIDTH-1:0] inv_U,
output signed [IN_WIDTH-1:0] inv_new_vectorT,
input [$clog2(TOTAL_ENDMEMBERS)-1:0] inv_U_col,
input [$clog2(SPECTRAL_BANDS)-1:0] inv_U_row,
input [$clog2(TOTAL_ENDMEMBERS)-1:0] inv_new_vectorT_row,
input [$clog2(SPECTRAL_BANDS)-1:0] inv_new_vectorT_col,
input inv_addr_valid_in,
output reg inv_valid_out,
input signed [T_WIDTH-1:0] inverse,
output reg [$clog2(TOTAL_ENDMEMBERS)-1:0] inv_row, inv_col,
output reg inv_addr_valid_out,
output [$clog2(TOTAL_ENDMEMBERS)-1:0] inv_size,
input inv_out_valid,
input inv_done,
output reg inv_start,
  
output reg mat_mult_start,
output reg [$clog2(SPECTRAL_BANDS)-1:0] mat1_dims_rows, mat1_dims_cols, mat2_dims_cols,
output reg mat1_valid, mat2_valid,
output reg signed [T_WIDTH-1:0] mat1, mat2,
output reg [2:0] mat_mult_mac_mode,
input mat_mult_rd_addr_valid,
input [$clog2(SPECTRAL_BANDS)-1:0] mat1_row, mat1_col, mat2_row, mat2_col, mat_mult_out_row, mat_mult_out_col,
input mat_mult_out_valid,
input signed [T_WIDTH-1:0] mat_mult_out,
input mat_mult_done
    );

localparam IDLE = 0,
    PRE_INIT = 1,
    INIT_m1 = 2,
    INIT_m2 = 3,
    INIT_P_1 = 4,
    INIT_P_2 = 5,
    INIT_P_3 = 6,
    MAX_NORM_1 = 7,
    MAX_NORM_2 = 8,
    BETA = 9,
    u_1 = 10,
    u_2 = 11,
    u_3 = 12,
    u_4 = 13,
    UPDATE_P = 14,
    OUT = 15,
    FINISH = 16;
    


reg [4:0] state;

reg [IN_WIDTH-1:0] buffer [SPECTRAL_BANDS-1:0];
wire [IN_WIDTH-1:0] buffer_1;
wire [IN_WIDTH-1:0] buffer_2;
assign buffer_1 = buffer[0];
assign buffer_2 = buffer[SPECTRAL_BANDS-1];
reg buffer_1_valid;
reg buffer_2_valid;
reg buffer_shift;
integer i;

reg [$clog2(TOTAL_PIXELS)-1:0] in_pixel_counter;
reg [$clog2(SPECTRAL_BANDS)-1:0] in_spectral_counter;
reg [$clog2(SPECTRAL_BANDS+1)-1:0] out_ctr;

//reg [$clog2(SPECTRAL_BANDS):0] m1_column_counter_1;
//reg [$clog2(SPECTRAL_BANDS):0] m1_column_counter_2;
wire [IN_WIDTH-1:0] m1_in_1;
wire [IN_WIDTH-1:0] m1_in_2;
wire [IN_WIDTH-1:0] m1_out_1;
wire [IN_WIDTH-1:0] m1_out_2;
wire [$clog2(SPECTRAL_BANDS)-1:0] m1_addr_1;
wire [$clog2(SPECTRAL_BANDS)-1:0] m1_addr_2;
reg m1_wr_en_1;
reg m1_wr_en_2;

//reg [$clog2(SPECTRAL_BANDS)-1:0] endmembers_column_counter_1;
reg [$clog2(SPECTRAL_BANDS)-1:0] col_ctr;
reg col_ctr_en;
//reg [$clog2(TOTAL_ENDMEMBERS-1):0] endmembers_row_counter_1;
//reg [$clog2(TOTAL_ENDMEMBERS)-1:0] endmembers_row_counter_2;
reg [$clog2(SPECTRAL_BANDS)-1:0] endmembers_column_1;
reg [$clog2(SPECTRAL_BANDS)-1:0] endmembers_column_2;
reg [$clog2(TOTAL_ENDMEMBERS-1):0] endmembers_row_1;
reg [$clog2(TOTAL_ENDMEMBERS)-1:0] endmembers_row_2;

wire [IN_WIDTH-1:0] endmembers_in_1;
wire [IN_WIDTH-1:0] endmembers_in_2;
wire [IN_WIDTH-1:0] endmembers_out_1;
wire [IN_WIDTH-1:0] endmembers_out_2;
wire [$clog2(SPECTRAL_BANDS*TOTAL_ENDMEMBERS)-1:0] endmembers_addr_1;
wire [$clog2(SPECTRAL_BANDS*TOTAL_ENDMEMBERS)-1:0] endmembers_addr_2;
reg endmembers_wr_en_1;
reg endmembers_wr_en_2;
reg endmembers_valid;


reg signed [T_WIDTH-1:0] inter_in_1, inter_in_2;
wire signed [T_WIDTH-1:0] inter_out_1, inter_out_2;
reg inter_wr_en_1, inter_wr_en_2;
wire [$clog2((TOTAL_ENDMEMBERS+1)*SPECTRAL_BANDS)-1:0] inter_addr_1, inter_addr_2; 
reg [$clog2(SPECTRAL_BANDS)-1:0] inter_col_1, inter_col_2;
reg [$clog2(SPECTRAL_BANDS+TOTAL_ENDMEMBERS-1)-1:0] inter_row_1, inter_row_2;

assign inter_addr_1 = (inter_row_1)*(SPECTRAL_BANDS) + inter_col_1;
assign inter_addr_2 = (inter_row_2)*(SPECTRAL_BANDS) + inter_col_2;

reg signed[T_WIDTH-1:0] p_mat_in_1, p_mat_in_2;
wire signed [T_WIDTH-1:0] p_mat_out_1, p_mat_out_2;
reg p_mat_wr_en_1, p_mat_wr_en_2;
reg [$clog2(SPECTRAL_BANDS)-1:0] p_mat_row_1, p_mat_row_2, p_mat_col_1, p_mat_col_2;
reg [1:0] p_mat_state;
wire p_mat_mac_valid;
reg p_mat_in_valid;
wire p_mat_mac_rst;
wire [T_WIDTH-1:0] p_mat_prod;
reg p_mat_prod_valid;
wire [2*T_WIDTH-1:0] p_mat_update_prod;

reg signed [T_WIDTH-1:0] divider_d, beta;
reg divider_in_valid;
wire divider_out_valid;
wire [T_WIDTH-1:0] divider_out;


wire [IN_WIDTH-1:0] mux0, mux1; 
reg [IN_WIDTH-1:0] mux2;
reg mux0_s, mux1_s;
reg [1:0] mux2_s;

reg [$clog2(SPECTRAL_BANDS)-1:0] mac_ctr;
reg [$clog2(TOTAL_ENDMEMBERS)-1:0] iter;
reg [MAC_WIDTH-1:0] max_dist;
reg [$clog2(TOTAL_PIXELS)-1:0] endmembers_index [TOTAL_ENDMEMBERS:0];
reg max_dist_changed, pixel_is_endmember, skip;
reg load; //to load contents of buffer to memory
reg delayed_in_axi_valid;
reg [IN_WIDTH-1:0] delayed_pixel_in;

reg [$clog2(SPECTRAL_BANDS)-1:0]  delayed_mat_mult_out_row, delayed_mat_mult_out_col;
reg delayed_mat_mult_out_valid, delayed_mat_mult_done;
reg signed [T_WIDTH-1:0] delayed_mat_mult_out;


wire signed [IN_WIDTH-1:0] sub1 , sub2; 
reg [IN_WIDTH-1:0] sub_1_in_1, sub_1_in_2;
wire [IN_WIDTH-1:0] sub_2_in_1, sub_2_in_2;

assign p_mat_update_prod = beta*delayed_mat_mult_out;

assign inv_size = iter;

assign endmem_index_out = endmembers_index[out_ctr];
assign out_axi_valid = (state == OUT & in_axi_ready);

assign sub1 = sub_1_in_1 - sub_1_in_2;
assign sub2 = sub_2_in_1 - sub_2_in_2;
/*assign sub_1_in_1 = mux2;
assign sub_1_in_2 = mux1;*/
assign sub_2_in_1 = endmembers_out_1;
assign sub_2_in_2 = m1_out_1;

assign mux0 = mux0_s ? pixel_in : buffer_2; // to m1

always @ (*) begin
    pixel_is_endmember = 0;
    for (i = 0 ; i <= TOTAL_ENDMEMBERS ; i = i + 1) begin
        if(in_pixel_counter == endmembers_index[i])
            pixel_is_endmember = 1;    
    end
  
end

//assign mux1 = mux1_s ? endmembers_out_2 : m1_out_2; 

/*always @ (*) begin
    case (mux2_s)
    'b00 : mux2 = buffer_2;
    'b01 : mux2 = delayed_pixel_in;
    'b10 : mux2 = endmembers_out_2;
    endcase
end*/

assign m1_addr_1 = endmembers_column_1;
assign m1_addr_2 = endmembers_column_2;
assign m1_in_1 = mux0;

assign endmembers_addr_1 = (endmembers_row_1)*SPECTRAL_BANDS + endmembers_column_1;
assign endmembers_addr_2 = (endmembers_row_2)*SPECTRAL_BANDS + endmembers_column_2;
assign endmembers_in_1 = buffer_2;

assign inv_U = sub1;
assign inv_new_vectorT = sub2;

assign p_mat_mac_rst = mac_ctr == SPECTRAL_BANDS-1;  


always @ (posedge clk) begin
    if ( buffer_shift ) begin
        for( i = 0 ; i < SPECTRAL_BANDS - 1 ; i = i + 1) begin
            buffer[0] <= pixel_in;
            buffer[i + 1] <= buffer[i];
        end
    end    
end

always @ (posedge clk) begin
    if (rst) begin
        delayed_pixel_in <= 0;
        delayed_in_axi_valid <= 0;
        delayed_mat_mult_out_row <= 0; 
        delayed_mat_mult_out_col <= 0;
        delayed_mat_mult_out_valid <= 0;
        delayed_mat_mult_out <= 0;
        delayed_mat_mult_done <= 0;
    end
    else begin
        delayed_mat_mult_out_row <= mat_mult_out_row ; 
        delayed_mat_mult_out_col <= mat_mult_out_col;
        delayed_mat_mult_out_valid <= mat_mult_out_valid;
        delayed_mat_mult_out <= mat_mult_out;
        delayed_mat_mult_done <= mat_mult_done;
        if ( state != PRE_INIT) begin
            delayed_pixel_in <= pixel_in;
            delayed_in_axi_valid <= in_axi_valid;
        end    
    end    
end

always @ (posedge clk) begin
    if (rst) begin
        in_pixel_counter <= 0;
        in_spectral_counter <= 0;
    end
    else if (in_axi_valid) begin
        if (in_spectral_counter == SPECTRAL_BANDS - 1 ) begin
            in_spectral_counter <= 0;
            if (in_pixel_counter == TOTAL_PIXELS - 1) begin
                in_pixel_counter <= 0;
            end
            else begin
                in_pixel_counter <= in_pixel_counter + 1;
            end    
        end
        else begin
            in_spectral_counter <= in_spectral_counter + 1;
        end    
    end
end

always @ (posedge clk) begin
    if (rst) begin
        mac_ctr <= 0;
        max_dist_changed <= 0;
        max_dist <= 0;
        load <= 0;
        //mac_reset <= 0;
        //endmembers_column_counter_1 <= 0;
        col_ctr <= 0;
        //endmembers_row_counter_1 <= 0;
        //endmembers_row_counter_2 <= 0;
        inv_start <= 0;
        iter <= 0;
        p_mat_prod_valid <= 0;
        divider_d <= 1;
        divider_in_valid <= 0;
        beta <= 0;
        out_ctr <= 0;
        for (i = 0; i <= TOTAL_ENDMEMBERS; i = i + 1 ) begin
            endmembers_index[i] <= {$clog2(TOTAL_PIXELS){1'b1}};
        end
    end
    else begin
        case (state)
        IDLE : begin
            intr <= 1;
        end
        PRE_INIT: begin              //filling input in m1 via port 1
            endmembers_index[0] <= 0;
            if (in_axi_valid) begin
                intr <= 0;         
                if ( col_ctr == SPECTRAL_BANDS-1) begin
                    intr <= 1;
                end 
            end
              
        end
       INIT_m1 : begin
            if (in_axi_valid) begin
                intr <= 0;
//                if ( col_ctr == SPECTRAL_BANDS-1) begin
//                    col_ctr <= 0;
//                end
//                else begin
//                    col_ctr <= col_ctr + 1;  // to subtractor       
//                end
            end
            if (mac_valid_in) begin    
                if ( mac_ctr == SPECTRAL_BANDS-1) begin
                    intr <= 1;
                    //mac_reset <= 1;                   
                    mac_ctr <= 0;
                    if (in_pixel_counter == 1) begin
                        max_dist_changed <= 0;
                        if (!max_dist_changed) begin
                            intr <= 0;
                            max_dist <= 0;
                        end 
                    end
                    if ( mac_in > max_dist) begin
                        max_dist <= mac_in;
                        if ( in_pixel_counter == 0) begin
                            endmembers_index[0] <= TOTAL_PIXELS - 1;
                        end
                        else begin
                            endmembers_index[0] <= in_pixel_counter - 1;    
                        end
                        load <= 1;                       
                        max_dist_changed <= 1;                        
                    end
                    else begin    
                        load <= 0;
                    end
                end
                else begin
                    mac_ctr <= mac_ctr + 1;
                end
            end       
        end
        INIT_m2 : begin
            if (in_axi_valid) begin
                intr <= 0;
/*                if ( col_ctr == SPECTRAL_BANDS-1) begin
                    col_ctr <= 0;
                end
                else begin
                    col_ctr <= col_ctr + 1;  // to subtractor       
                end*/
            end
            if (mac_valid_in) begin    
                if ( mac_ctr == SPECTRAL_BANDS-1) begin
                    intr <= 1;
                   // mac_reset <= 1;                   
                    mac_ctr <= 0;
                    if (in_pixel_counter == 1) begin
                        max_dist_changed <= 0;
                        if (!max_dist_changed) begin
                            intr <= 0;
                            max_dist <= 0;
                        end 
                    end
                    if ( mac_in > max_dist) begin
                        max_dist <= mac_in;
                        if ( in_pixel_counter == 0) begin
                            endmembers_index[1] <= TOTAL_PIXELS - 1;
                        end
                        else begin
                            endmembers_index[1] <= in_pixel_counter - 1;    
                        end
                        load <= 1;                       
                        max_dist_changed <= 1;                        
                    end
                    else begin    
                        load <= 0;
                    end
                end
                else begin
                    mac_ctr <= mac_ctr + 1;
                end
            end       
        end
        INIT_P_1 : begin
            inv_start <= 1;
            max_dist <= 0;
            if (inv_done) begin
                inv_start <= 0;
            end
        end
        INIT_P_2 : begin
            mat_mult_start <= 1;
            if (mat_mult_done) begin
                mat_mult_start <= 0;
            end
        end
        INIT_P_3 : begin
            mat_mult_start <= 1;
            if (mat_mult_done) begin
                mat_mult_start <= 0;
                intr <= 1;
                iter <= iter + 1;
            end
        end
        MAX_NORM_1 : begin
            
            if (in_axi_valid) begin
                skip <= pixel_is_endmember;
                intr <= 0;
                if (col_ctr == SPECTRAL_BANDS-1) begin
                    load <= 0;
                end
            end
            
            if (p_mat_mac_valid) begin
                if (mac_ctr == SPECTRAL_BANDS-1) begin
                    mac_ctr <= 0;
                end
                else begin
                    mac_ctr <= mac_ctr + 1;
                end
            end
             
        end
    
        
        MAX_NORM_2 : begin
            if (mac_valid_in && !load) begin    
                if ( mac_ctr == SPECTRAL_BANDS-1) begin
                    intr <= 1;
                    //mac_reset <= 1;                   
                    mac_ctr <= 0;
                    if (in_pixel_counter == 1) begin
                        intr <= 0;
                    end
                    
                    if ( mac_in > max_dist /*& ~skip*/) begin
                        max_dist <= mac_in;
                        if ( in_pixel_counter == 0) begin
                            endmembers_index[iter + 1] <= TOTAL_PIXELS - 1;
                        end
                        else begin
                            endmembers_index[iter + 1] <= in_pixel_counter - 1;    
                        end
                        load <= 1;                                             
                    end
                end
                else begin
                    mac_ctr <= mac_ctr + 1;
                end
            end
            else if (load && col_ctr == SPECTRAL_BANDS - 1) begin
                load <= 0;
            end                   
        
        end
        
//        BETA : begin
//            divider_in_valid <= 1;
            
//            if (divider_out_valid) begin
//                divider_in_valid <= 0;
//                beta <= divider_out;
//                max_dist <= 0;
//            end                   
        
//        end
        
//        u_1 : begin
//            inv_start <= 1;
//            if (inv_done) begin
//                inv_start <= 0;
//            end
//        end
        
//        u_2 : begin
//            mat_mult_start <= 1;
//            if (mat_mult_done) begin
//                mat_mult_start <= 0;
//            end
//        end
        
//        u_3 : begin
//            mat_mult_start <= 1;
//            if (mat_mult_done) begin
//                mat_mult_start <= 0;
//                //iter <= iter + 1;
//            end
//        end
        
//        u_4 : begin
//            mat_mult_start <= 1;
//            if (mat_mult_done) begin
//                mat_mult_start <= 0;
//                //if (col_ctr == SPECTRAL_BANDS-1)
//                    //iter <= iter + 1;
//            end
//        end
        
//        UPDATE_P : begin
//            mat_mult_start <= 1;
//            if (mat_mult_done) begin
//                mat_mult_start <= 0;
//                //iter <= iter + 1;
//                intr <= 1; // next MAX_NORM
//            end
//        end
        
        OUT : begin
            if (in_axi_ready) begin
                if (out_ctr == TOTAL_ENDMEMBERS) begin
                    out_ctr <= 0;
                end
                else begin
                    out_ctr <= out_ctr + 1;
                end
            end
        end
        
        
        endcase
        
        
/*        if (mac_reset) begin
            mac_reset <= 0;
        end*/
        
       
        if (col_ctr_en) begin
            if ( col_ctr == SPECTRAL_BANDS-1) begin
                col_ctr <= 0;
            end
            else begin
                col_ctr <= col_ctr + 1;    
            end
        end
    
    end        
end

always @ (posedge clk) begin
    if (rst) begin
        state <= IDLE;
    end
    else begin
        case (state)
        IDLE : begin
            state <= PRE_INIT;
        end
        PRE_INIT: begin              //filling input in m1 via port 1
            if (in_axi_valid) begin   
                if ( col_ctr == SPECTRAL_BANDS-1) begin
                    state <= INIT_m2;                
                end 
            end             
        end
        INIT_m1 : begin
            if (mac_valid_in &&  mac_ctr == SPECTRAL_BANDS-1 && in_pixel_counter == 1) begin    
                if (max_dist_changed) begin
                    state <= INIT_m2;
                end
                else begin
                    state <= INIT_P_1;
                end
            end       
        end
        INIT_m2 : begin
            if (mac_valid_in &&  mac_ctr == SPECTRAL_BANDS-1 && in_pixel_counter == 1) begin    
                if (max_dist_changed) begin
                    state <= INIT_m1;
                end
                else begin
                    state <= INIT_P_1;
                end
            end       
        end
        INIT_P_1 : begin
            if (inv_done) begin
                state <= INIT_P_2;
            end
        end
        INIT_P_2 : begin
            if (mat_mult_done) begin
                state <= INIT_P_3;
            end
        end
        INIT_P_3 : begin
            if (mat_mult_done) begin
                state <= MAX_NORM_1;
            end
        end
        MAX_NORM_1 : begin
            if (p_mat_mac_valid) begin
                if (mac_ctr == SPECTRAL_BANDS-1) begin
                    state <= MAX_NORM_2;
                end
            end
        end
        
        MAX_NORM_2 : begin
            if (mac_valid_in && !load) begin
                if (mac_ctr == SPECTRAL_BANDS-1) begin
                    if (in_pixel_counter == 1 ) begin
                        if ( mac_in <= max_dist | skip) begin
                            if (iter == TOTAL_ENDMEMBERS-1)
                                state <= OUT;
                            else
                                state <= INIT_P_1;//BETA;
                        end
                    end    
                    else begin
                        state <= MAX_NORM_1;
                    end    
                end
            end
            else if (load && col_ctr == SPECTRAL_BANDS-1)
                if (iter == TOTAL_ENDMEMBERS-1)
                    state <= OUT;
                else
                    state <= INIT_P_1;//BETA;
        end
        
//        BETA : begin
///*            if (mac_valid_in) begin
//                if (mac_ctr == SPECTRAL_BANDS-1) begin
//                    state <= FINISH;
//                end
//            end   */ 
//            if (divider_out_valid) begin
//                state <= u_1;
//            end
//        end
//        u_1 : begin
//            if (beta == 0) begin
//                state <= OUT;
//            end
//            else if (inv_done) begin
//                state <= u_2;
//            end
//        end
//        u_2 : begin
//            if (mat_mult_done) begin
//                state <= u_3;
//            end
//        end
//        u_3 : begin
//            if (mat_mult_done) begin
//                state <= u_4;
//            end
//        end
//        u_4 : begin
//            if (mat_mult_done) begin
//                if (col_ctr == SPECTRAL_BANDS-1)
//                    state <= UPDATE_P;
//                else
//                    state <= u_3;
//            end
//        end
//        UPDATE_P : begin
//            if (mat_mult_done) begin
//                state <= MAX_NORM_1;
//            end
//        end
        OUT : begin
            if (out_ctr == TOTAL_ENDMEMBERS) begin
                state <= FINISH;
            end
        end
        
        endcase   
    end        
end

always @ (posedge clk) begin
    inv_valid_out <= inv_addr_valid_in;
    mat1_valid <= mat_mult_rd_addr_valid;
    mat2_valid <= mat_mult_rd_addr_valid;
end


always @ (*) begin
    col_ctr_en = 0;
    m1_wr_en_1 = 0;
    m1_wr_en_2 = 0;
    endmembers_wr_en_1 = 0;
    endmembers_wr_en_2 = 0;
    endmembers_column_1 = col_ctr;
    endmembers_column_2 = col_ctr;
    inter_wr_en_1 = 0;
    inter_wr_en_2 = 0;
    p_mat_wr_en_1 = 0;
    p_mat_wr_en_2 = 0;
    p_mat_in_valid = 0;
    p_mat_state = 0 ;
    mac_out_1 = 0;
    mac_out_2 = 0;
    inv_row = mat1_row;
    inv_col = mat1_col;
    mat1_dims_rows = iter;
    mat1_dims_cols = iter;
    mat2_dims_cols = SPECTRAL_BANDS-1;
    mat1 = inverse;
    mat2 = {{T_WIDTH - IN_WIDTH{sub2[IN_WIDTH - 1]}},sub2};
    mat_mult_mac_mode = 0;
    p_mat_row_1 = mat_mult_out_row;
    p_mat_row_2 = mat_mult_out_row;
    p_mat_col_1 = mat_mult_out_col;
    p_mat_col_2 = mat_mult_out_col;
    p_mat_in_1 = - mat_mult_out;
    endmembers_row_1 = 0;
    endmembers_row_2 = 0;
    inter_in_1 = mat_mult_out >>> 12; ///////////////////testing
    inter_in_2 = mat_mult_out;
    inter_col_1 = mat_mult_out_col;
    inter_col_2 = mat_mult_out_col;
    inter_row_1 = 1 + TOTAL_ENDMEMBERS - 2 + 1;
    inter_row_2 = 1 + TOTAL_ENDMEMBERS - 2 + 1; 
    finish = 0;
//    mux2_s = 'b10;
//    mux1_s = 0;
    sub_1_in_1 = endmembers_out_2;
    sub_1_in_2 = m1_out_2;
    mux0_s = 0;
    mac_reset = (mac_ctr == 0 & ~mac_valid_in) | (mac_ctr == SPECTRAL_BANDS-1 & mac_valid_in) ;
    mac_valid_out = 0;
    buffer_shift = in_axi_valid;
    mac_mode = 0;
    case (state)
    IDLE: begin
    end
    PRE_INIT: begin
        mux0_s = 'b1;
        m1_wr_en_1 = in_axi_valid;
        endmembers_row_1 = 0;
        endmembers_row_2 = 0;
        col_ctr_en = in_axi_valid;
    end
    INIT_m1: begin
//        mux2_s = 'b01;
//        mux1_s = 1;
        sub_1_in_1 = delayed_pixel_in;
        sub_1_in_2 = endmembers_out_2;
        m1_wr_en_1 = in_axi_valid & load;
        mac_out_1 = {{MAC_WIDTH - IN_WIDTH{sub1[IN_WIDTH - 1]}},sub1};
        mac_out_2 = {{MAC_WIDTH - IN_WIDTH{sub1[IN_WIDTH - 1]}},sub1};
        mac_valid_out = delayed_in_axi_valid;
        endmembers_row_1 = 0;
        endmembers_row_2 = 0;   
        col_ctr_en = in_axi_valid;  
    end
    INIT_m2: begin
//        mux2_s = 'b01;
//        mux1_s = 0;
        sub_1_in_1 = delayed_pixel_in;
        endmembers_wr_en_1 = in_axi_valid & load;
        mac_out_1 = {{MAC_WIDTH - IN_WIDTH{sub1[IN_WIDTH - 1]}},sub1};
        mac_out_2 = {{MAC_WIDTH - IN_WIDTH{sub1[IN_WIDTH - 1]}},sub1}; 
        mac_valid_out = delayed_in_axi_valid;  
        endmembers_row_1 = 0;
        endmembers_row_2 = 0;
        col_ctr_en = in_axi_valid;
    end
    INIT_P_1 : begin
        endmembers_column_1 = inv_new_vectorT_col;
        endmembers_column_2 = inv_U_row;
        endmembers_row_1 = inv_new_vectorT_row;
        endmembers_row_2 = inv_U_col;    
    end
    INIT_P_2 : begin
        inv_row = mat1_row;
        inv_col = mat1_col; 
        endmembers_column_1 = mat2_col;
        endmembers_row_1 = mat2_row;
        mat1_dims_rows = iter;
        mat1_dims_cols = iter;
        mat2_dims_cols = SPECTRAL_BANDS-1;
        mat1 = inverse; //>>>3; //////////////testing
        mat2 = {{T_WIDTH - IN_WIDTH{sub2[IN_WIDTH - 1]}},sub2};
        mat_mult_mac_mode = 11;
        inter_in_1 = mat_mult_out >>> 5; ///////////////////testing
        inter_wr_en_1 = mat_mult_out_valid;
        inter_col_1 = mat_mult_out_col;
        inter_row_1 = mat_mult_out_row;
        
 
   
    end
    INIT_P_3 : begin
        endmembers_column_1 = mat1_row;
        endmembers_row_1 = mat1_col; 
        inter_col_1 = mat2_col;
        inter_row_1 = mat2_row;
        mat1_dims_rows = SPECTRAL_BANDS-1;
        mat1_dims_cols = iter;
        mat2_dims_cols = SPECTRAL_BANDS-1;
        mat1 = {{T_WIDTH - IN_WIDTH{sub2[IN_WIDTH - 1]}},sub2};
        mat2 = inter_out_1;
        mat_mult_mac_mode = 0;
        p_mat_wr_en_1 = mat_mult_out_valid;
        p_mat_col_1 = mat_mult_out_col;
        p_mat_row_1 = mat_mult_out_row;
        
        if (p_mat_col_1 == p_mat_row_1 )
            p_mat_in_1 = {4'b0001,{28{1'b0}}} - mat_mult_out;
        else
            p_mat_in_1 = - mat_mult_out;   
   
    end
    
    MAX_NORM_1 : begin
//        mux2_s = 'b01;
        sub_1_in_1 = delayed_pixel_in;
        p_mat_state = 'b01;
        p_mat_col_2 = col_ctr;
        col_ctr_en = in_axi_valid;
        endmembers_row_1 = iter ;
        endmembers_wr_en_1 = load & in_axi_valid;
        p_mat_in_valid = delayed_in_axi_valid; 
    end
    
    MAX_NORM_2 : begin
        mac_out_1 = p_mat_prod;
        mac_out_2 = p_mat_prod;
        mac_valid_out = 1;
        col_ctr_en = load;
        endmembers_row_1 = iter;
        endmembers_wr_en_1 = load;
        buffer_shift = load;
        p_mat_state = 'b10; 
        mac_mode = 1;
    end
    
//    u_1 : begin
//        endmembers_column_1 = inv_new_vectorT_col;
//        endmembers_column_2 = inv_U_row;
//        endmembers_row_1 = inv_new_vectorT_row;
//        endmembers_row_2 = inv_U_col;    
//    end
//    u_2 : begin              // 4.28 * 32.0 = 4.28
//        inv_row = mat1_row;
//        inv_col = mat1_col; 
//        endmembers_column_1 = mat2_col;
//        endmembers_row_1 = mat2_row;
//        mat1_dims_rows = iter;
//        mat1_dims_cols = iter;
//        mat2_dims_cols = SPECTRAL_BANDS-1;
//        mat1 = inverse >>> 3; ////////////////////testing
//        mat2 = {{T_WIDTH - IN_WIDTH{sub2[IN_WIDTH - 1]}},sub2};
//        mat_mult_mac_mode = 0;
//        inter_in_1 = mat_mult_out >>> 9; //////////////////testing
//        inter_wr_en_1 = mat_mult_out_valid;
//        inter_col_1 = mat_mult_out_col;
//        inter_row_1 = mat_mult_out_row;
        
//    end
//    u_3 : begin              // 4.28 * 32.0 = 4.28
//        endmembers_column_1 = col_ctr;//mat1_row;
//        endmembers_row_1 = mat1_col; 
//        inter_col_1 = mat2_col;
//        inter_row_1 = mat2_row;
//        mat1_dims_rows = 1'b0;//SPECTRAL_BANDS-1;
//        mat1_dims_cols = iter;
//        mat2_dims_cols = SPECTRAL_BANDS-1;
//        mat1 = {{T_WIDTH - IN_WIDTH{sub2[IN_WIDTH - 1]}},sub2};
//        mat2 = inter_out_1;
//        mat_mult_mac_mode = 'b0;
//        inter_in_2 = mat_mult_out;
//        inter_wr_en_2 = mat_mult_out_valid;
//        inter_col_2 = mat_mult_out_col;
//        inter_row_2 = mat_mult_out_row + 1 + iter;
   
//    end
    
//    u_4 : begin                // 4.28 * 32.0 = 16.16
//        endmembers_column_1 = mat2_row;
//        endmembers_row_1 = iter+1;
//        inter_col_1 = mat1_col;
//        inter_row_1 = mat1_row + 1 + iter;
//        mat1_dims_rows = 1'b0;//SPECTRAL_BANDS-1;
//        mat1_dims_cols = SPECTRAL_BANDS-1;
//        mat2_dims_cols = 'b0;
//        mat2 = {{T_WIDTH - IN_WIDTH{sub2[IN_WIDTH - 1]}},sub2};
//        mat1 = inter_out_1;
//        mat_mult_mac_mode = 'b1;
//        inter_in_2 = mat_mult_out - {sub1,{T_WIDTH - IN_WIDTH{1'b0}}};
//        inter_wr_en_2 = mat_mult_out_valid;
//        //endmembers_column_2 = mat_mult_out_row ;
//        endmembers_row_2 = iter+1;  
//        inter_row_2 = 1 + TOTAL_ENDMEMBERS - 2 + 1;//mat_mult_out_col;
//        inter_col_2 = mat_mult_out_row + col_ctr;
//        col_ctr_en = mat_mult_done;
   
//    end
    
//    UPDATE_P : begin       //16.16 * 16.16 = 24.8
//        inter_col_1 = mat1_row;
//        inter_row_1 = 1 + TOTAL_ENDMEMBERS - 2 + 1;//mat1_col; 
//        inter_col_2 = mat2_col;
//        inter_row_2 = 1 + TOTAL_ENDMEMBERS - 2 + 1;//mat2_row;
//        mat1_dims_rows = SPECTRAL_BANDS-1;
//        mat1_dims_cols = 'b0;
//        mat2_dims_cols = SPECTRAL_BANDS-1;
//        mat1 = inter_out_1;
//        mat2 = inter_out_2;
//        mat_mult_mac_mode = 'b10;
//        p_mat_wr_en_1 = delayed_mat_mult_out_valid;
//        p_mat_col_1 = delayed_mat_mult_out_col;
//        p_mat_row_1 = delayed_mat_mult_out_row;
//        p_mat_col_2 = mat_mult_out_col;
//        p_mat_row_2 = mat_mult_out_row;
        
//        p_mat_in_1 = p_mat_out_2 - p_mat_update_prod[4 + 28 + 8 -1 -: 32];   
   
//    end

    
    FINISH: begin
        finish = 1;
    end
    
    default : begin
   
    end
    endcase
end


memory 
#(.SIZE(TOTAL_ENDMEMBERS*SPECTRAL_BANDS),
  .WIDTH(IN_WIDTH))
endmembers
(
.pixel_in1(endmembers_in_1),
.pixel_in2(endmembers_in_2),
.pixel_out1(endmembers_out_1),
.pixel_out2(endmembers_out_2),
.enable1(1'b1),
.wr_enable1(endmembers_wr_en_1),
.enable2(1'b1),
.wr_enable2(endmembers_wr_en_2),
.addr1(endmembers_addr_1),
.addr2(endmembers_addr_2),
.clk(clk)
    );

memory 
#(.SIZE(SPECTRAL_BANDS),
  .WIDTH(IN_WIDTH))
m1
(
.pixel_in1(m1_in_1),
.pixel_in2(m1_in_2),
.pixel_out1(m1_out_1),
.pixel_out2(m1_out_2),
.enable1(1'b1),
.wr_enable1(m1_wr_en_1),
.enable2(1'b1),
.wr_enable2(m2_wr_en_1),
.addr1(m1_addr_1),
.addr2(m1_addr_2),
.clk(clk)
    );
    
memory 
#(.SIZE((TOTAL_ENDMEMBERS+1)*SPECTRAL_BANDS),
  .WIDTH(T_WIDTH))
inter
(
.pixel_in1(inter_in_1),
.pixel_in2(inter_in_2),
.pixel_out1(inter_out_1),
.pixel_out2(inter_out_2),
.enable1(1'b1),
.wr_enable1(inter_wr_en_1),
.enable2(1'b1),
.wr_enable2(inter_wr_en_2),
.addr1(inter_addr_1),
.addr2(inter_addr_2),
.clk(clk)
    );
    
p_mat
  #(
    .SPECTRAL_BANDS(SPECTRAL_BANDS),
    .I_WIDTH(4),
    .F_WIDTH(28),
    .IN_I_WIDTH(32),
    .IN_F_WIDTH(0))
p_mat  
  (
    .clk(clk), 
    .rst(rst),
    .in_valid(p_mat_in_valid),
    .in_pixel({{T_WIDTH - IN_WIDTH{sub1[IN_WIDTH - 1]}},sub1}),
    .row_1(p_mat_row_1), 
    .row_2(p_mat_row_2), 
    .col_1(p_mat_col_1), 
    .col_2(p_mat_col_2),
    .wr_en_1(p_mat_wr_en_1), 
    .wr_en_2(p_mat_wr_en_2),
    //.mode(p_mat_mode),  // 1 if mult and norm
    .in_1(p_mat_in_1), 
    .in_2(p_mat_in_2),
    .out_1(p_mat_out_1), 
    .out_2(p_mat_out_2),
    .state(p_mat_state),
    .mac_valid(p_mat_mac_valid),
    .mac_rst(p_mat_mac_rst),
    .prod(p_mat_prod)
  );
          
//  divider
//  #(.I_WIDTH(32),
//    .F_WIDTH(0),
//    .OUT_I_WIDTH(4),
//    .OUT_F_WIDTH(28)
//  )  
//  beta_divider
//  (
//    .N_in({32'b1,{0{1'b0}}}), 
//    .D_in(max_dist),
//    .clk(clk), 
//    .rst(rst), 
//    .in_valid(divider_in_valid),
//    .ready(), 
//    .out_valid(divider_out_valid),
//    .out(divider_out)
//);    
       
       
endmodule
