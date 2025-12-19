`timescale 1ns / 1ps

module decoder_7seg_dot(
  //input clk,
  
  input [6:0]   hex_data_i, //[6] - dot

  output        ca_o,
  output        cb_o,
  output        cc_o,
  output        cd_o,
  output        ce_o,
  output        cf_o,
  output        cg_o,
  output        dp_o
);

wire [6:0] seg;
wire dot;
assign dot = ~hex_data_i[6];

assign seg = (hex_data_i[5:0] == 6'h0 ) ? 7'b1000000 :
             (hex_data_i[5:0] == 6'h1 ) ? 7'b1111001 :
             (hex_data_i[5:0] == 6'h2 ) ? 7'b0100100 :
             (hex_data_i[5:0] == 6'h3 ) ? 7'b0110000 :
             (hex_data_i[5:0] == 6'h4 ) ? 7'b0011001 :
             (hex_data_i[5:0] == 6'h5 ) ? 7'b0010010 :
             (hex_data_i[5:0] == 6'h6 ) ? 7'b0000010 :
             (hex_data_i[5:0] == 6'h7 ) ? 7'b1111000 :
             (hex_data_i[5:0] == 6'h8 ) ? 7'b0000000 :
             (hex_data_i[5:0] == 6'h9 ) ? 7'b0010000 :
             (hex_data_i[5:0] == 6'ha ) ? 7'b0001000 :
             (hex_data_i[5:0] == 6'hb ) ? 7'b0000011 :
             (hex_data_i[5:0] == 6'hc ) ? 7'b1000110 :
             (hex_data_i[5:0] == 6'hd ) ? 7'b0100001 :
             (hex_data_i[5:0] == 6'he ) ? 7'b0000110 :
             (hex_data_i[5:0] == 6'hf ) ? 7'b0001110 :
             (hex_data_i[5:0] == 6'h10) ? 7'b1111110 :
             (hex_data_i[5:0] == 6'h11) ? 7'b1111101 :
             (hex_data_i[5:0] == 6'h12) ? 7'b1111011 :
             (hex_data_i[5:0] == 6'h13) ? 7'b1110111 :
             (hex_data_i[5:0] == 6'h14) ? 7'b1101111 :
             (hex_data_i[5:0] == 6'h15) ? 7'b1011111 :
             (hex_data_i[5:0] == 6'h16) ? 7'b0111111 :
             (hex_data_i[5:0] == 6'h17) ? 7'b1111111 :
             (hex_data_i[5:0] == 6'h18) ? 7'b1000111 :
             'd0;

//reg [6:0] seg;
//reg dot;

//always@(*) 
//begin
//    case(hex_data_i[5:0]) // GFEDCBA
//      6'h0 : seg <= 7'b1000000; // ABCDEF
//      6'h1 : seg <= 7'b1111001; // BC
//      6'h2 : seg <= 7'b0100100; // ABDEG
//      6'h3 : seg <= 7'b0110000; // ABCDG
//      6'h4 : seg <= 7'b0011001; // BCFG
//      6'h5 : seg <= 7'b0010010; // ACDFG
//      6'h6 : seg <= 7'b0000010; // ACDEFG
//      6'h7 : seg <= 7'b1111000; // ABC
//      6'h8 : seg <= 7'b0000000; // ABCDEFG
//      6'h9 : seg <= 7'b0010000; // ABCDFG
//      6'ha : seg <= 7'b0001000; // ABCEFG
//      6'hb : seg <= 7'b0000011; // CDEFG
//      6'hc : seg <= 7'b1000110; // ADEF
//      6'hd : seg <= 7'b0100001; // BCDEG
//      6'he : seg <= 7'b0000110; // ADEFG
//      6'hf : seg <= 7'b0001110; // AEFG
//      6'h10: seg <= 7'b1111110; // A
//      6'h11: seg <= 7'b1111101; // B
//      6'h12: seg <= 7'b1111011; // C
//      6'h13: seg <= 7'b1110111; // D
//      6'h14: seg <= 7'b1101111; // E
//      6'h15: seg <= 7'b1011111; // F
//      6'h16: seg <= 7'b0111111; // G
//      6'h17: seg <= 7'b1111111; // off 101 0111
//      6'h18: seg <= 7'b1000111; // L
//    endcase
    
//    dot <= ~hex_data_i[6];
//end
  

  assign ca_o = seg[0];
  assign cb_o = seg[1];
  assign cc_o = seg[2];
  assign cd_o = seg[3];
  assign ce_o = seg[4];
  assign cf_o = seg[5];
  assign cg_o = seg[6];
  assign dp_o = dot;

endmodule
