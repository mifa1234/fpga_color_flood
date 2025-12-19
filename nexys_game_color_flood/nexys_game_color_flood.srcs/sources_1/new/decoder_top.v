`timescale 1ns / 1ps


module decoder_top(
    input clk,
    
    input [26:0] value,
    input [7:0] value_dp,
    input  value_valid,
    
    output [7:0] enable_7seg,
    
    output        ca_o,
    output        cb_o,
    output        cc_o,
    output        cd_o,
    output        ce_o,
    output        cf_o,
    output        cg_o,
    output        dp_o
);
    
reg [7:0] value_dp_reg;
reg [6:0] value_7seg_one [0:7];    
reg [26:0] value_reg = 12345678;

reg [26:0] value_next [0:7];    


always@(posedge clk)
begin
    if(value_valid) begin
        value_reg <= value;
        value_dp_reg <= value_dp;
    end
end

reg [2:0] cnt_7seg = 0;
reg [8:0] divider_cnt = 0;//divider CLK/ 
always@(posedge clk)
begin
    {cnt_7seg, divider_cnt} <= {cnt_7seg, divider_cnt} + 1;
end


always@(posedge clk)
begin
 value_next[7] <= value_reg; 
 value_7seg_one[7] <= (value_next[7] < 'd10000000) ? 'd0 :
                           (value_next[7] < 'd20000000) ? 'd1 : 
                           (value_next[7] < 'd30000000) ? 'd2 : 
                           (value_next[7] < 'd40000000) ? 'd3 : 
                           (value_next[7] < 'd50000000) ? 'd4 : 
                           (value_next[7] < 'd60000000) ? 'd5 : 
                           (value_next[7] < 'd70000000) ? 'd6 : 
                           (value_next[7] < 'd80000000) ? 'd7 : 
                           (value_next[7] < 'd90000000) ? 'd8 :
                           'd9; 
                           
 value_next[6] <= value_next[7] - value_7seg_one[7]*10000000;     
 value_7seg_one[6] <= (value_next[6] < 'd1000000) ? 'd0 :
                           (value_next[6] < 'd2000000) ? 'd1 : 
                           (value_next[6] < 'd3000000) ? 'd2 : 
                           (value_next[6] < 'd4000000) ? 'd3 : 
                           (value_next[6] < 'd5000000) ? 'd4 : 
                           (value_next[6] < 'd6000000) ? 'd5 : 
                           (value_next[6] < 'd7000000) ? 'd6 : 
                           (value_next[6] < 'd8000000) ? 'd7 : 
                           (value_next[6] < 'd9000000) ? 'd8 :
                           'd9;    
                           
                           
 value_next[5] <= value_next[6] - value_7seg_one[6]*1000000;     
 value_7seg_one[5] <= (value_next[5] < 'd100000) ? 'd0 :
                           (value_next[5] < 'd200000) ? 'd1 : 
                           (value_next[5] < 'd300000) ? 'd2 : 
                           (value_next[5] < 'd400000) ? 'd3 : 
                           (value_next[5] < 'd500000) ? 'd4 : 
                           (value_next[5] < 'd600000) ? 'd5 : 
                           (value_next[5] < 'd700000) ? 'd6 : 
                           (value_next[5] < 'd800000) ? 'd7 : 
                           (value_next[5] < 'd900000) ? 'd8 :
                           'd9;    
                           
                           
 value_next[4] <= value_next[5] - value_7seg_one[5]*100000;     
 value_7seg_one[4] <= (value_next[4] < 'd10000) ? 'd0 :
                           (value_next[4] < 'd20000) ? 'd1 : 
                           (value_next[4] < 'd30000) ? 'd2 : 
                           (value_next[4] < 'd40000) ? 'd3 : 
                           (value_next[4] < 'd50000) ? 'd4 : 
                           (value_next[4] < 'd60000) ? 'd5 : 
                           (value_next[4] < 'd70000) ? 'd6 : 
                           (value_next[4] < 'd80000) ? 'd7 : 
                           (value_next[4] < 'd90000) ? 'd8 :
                           'd9;      
                           
                           
 value_next[3] <= value_next[4] - value_7seg_one[4]*10000;     
 value_7seg_one[3] <= (value_next[3] < 'd1000) ? 'd0 :
                           (value_next[3] < 'd2000) ? 'd1 : 
                           (value_next[3] < 'd3000) ? 'd2 : 
                           (value_next[3] < 'd4000) ? 'd3 : 
                           (value_next[3] < 'd5000) ? 'd4 : 
                           (value_next[3] < 'd6000) ? 'd5 : 
                           (value_next[3] < 'd7000) ? 'd6 : 
                           (value_next[3] < 'd8000) ? 'd7 : 
                           (value_next[3] < 'd9000) ? 'd8 :
                           'd9;    
                           
                           
                           
 value_next[2] <= value_next[3] - value_7seg_one[3]*1000;     
 value_7seg_one[2] <= (value_next[2] < 'd100) ? 'd0 :
                           (value_next[2] < 'd200) ? 'd1 : 
                           (value_next[2] < 'd300) ? 'd2 : 
                           (value_next[2] < 'd400) ? 'd3 : 
                           (value_next[2] < 'd500) ? 'd4 : 
                           (value_next[2] < 'd600) ? 'd5 : 
                           (value_next[2] < 'd700) ? 'd6 : 
                           (value_next[2] < 'd800) ? 'd7 : 
                           (value_next[2] < 'd900) ? 'd8 :
                           'd9;      
                           
                           
 value_next[1] <= value_next[2] - value_7seg_one[2]*100;     
 value_7seg_one[1] <= (value_next[1] < 'd10) ? 'd0 :
                           (value_next[1] < 'd20) ? 'd1 : 
                           (value_next[1] < 'd30) ? 'd2 : 
                           (value_next[1] < 'd40) ? 'd3 : 
                           (value_next[1] < 'd50) ? 'd4 : 
                           (value_next[1] < 'd60) ? 'd5 : 
                           (value_next[1] < 'd70) ? 'd6 : 
                           (value_next[1] < 'd80) ? 'd7 : 
                           (value_next[1] < 'd90) ? 'd8 :
                           'd9;   
                           
                           
 value_next[0] <= value_next[1] - value_7seg_one[1]*10;     
 value_7seg_one[0] <= (value_next[0] < 'd1) ? 'd0 :
                           (value_next[0] < 'd2) ? 'd1 : 
                           (value_next[0] < 'd3) ? 'd2 : 
                           (value_next[0] < 'd4) ? 'd3 : 
                           (value_next[0] < 'd5) ? 'd4 : 
                           (value_next[0] < 'd6) ? 'd5 : 
                           (value_next[0] < 'd7) ? 'd6 : 
                           (value_next[0] < 'd8) ? 'd7 : 
                           (value_next[0] < 'd9) ? 'd8 :
                           'd9;                                                                                                                                                                         

end


genvar i;
for (i=0; i < 8; i=i+1)
begin
    assign enable_7seg[i] = (cnt_7seg == i) ? 'd0 : 'd1;
end




wire [6:0] hex_data_i;
assign hex_data_i[6]   = value_dp_reg[cnt_7seg];  
assign hex_data_i[5:0] = value_7seg_one[cnt_7seg];  
    
decoder_7seg_dot decoder_7seg_dot(

  .hex_data_i(hex_data_i), //[6] - dot
  .ca_o(ca_o),
  .cb_o(cb_o),
  .cc_o(cc_o),
  .cd_o(cd_o),
  .ce_o(ce_o),
  .cf_o(cf_o),
  .cg_o(cg_o),
  .dp_o(dp_o)
);    
    
endmodule
