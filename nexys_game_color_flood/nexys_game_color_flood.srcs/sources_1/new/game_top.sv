`timescale 1ns / 1ps

module game_top(
    input clk_in,
    input rstn_pb,
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,
    output vga_v_sync,
    output vga_h_sync,
    input key_ok,
    input key_select_up,
    input key_select_down,
    input [1:0] mode_game,
    
    //7 segments indicators
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
    
    
logic clk, rstn;

clk_wiz_game clk_wiz_game
(
    .clk_out1(clk),    
    .locked  (rstn),       
    .clk_in1 (clk_in)
); 

logic [7:0] value_dp = 0;
logic [26:0] value_seg = 0;
logic result_game_valid, result_game_each_step_valid, value_seg_vld;
logic [7:0] result_player_1; //user 1
logic [7:0] result_player_2; //PC or user 2
logic [1:0] result_game_mode;    
logic [7:0] count_steps_player_1, count_steps_player_2;
    
game game_inst
(
    .clk       (clk       ),
    .rstn_pb   (rstn_pb   ),
    
    .vga_r     (vga_r     ),
    .vga_g     (vga_g     ),
    .vga_b     (vga_b     ),
    .vga_v_sync(vga_v_sync),
    .vga_h_sync(vga_h_sync),
    .vga_pixel_valid (),
    
    .mode_game (mode_game ),
    .key_ok    (key_ok    ),
    .key_select_up  (key_select_up),
    .key_select_down(key_select_down),
    
    .result_game_valid   (result_game_valid ),
    .result_game_each_step_valid   (result_game_each_step_valid ),
    .count_steps_player_1(count_steps_player_1),
    .count_steps_player_2(count_steps_player_2),
    .result_player_1     (result_player_1   ), //user 1
    .result_player_2     (result_player_2   ), //PC or user 2
    .result_game_mode    (result_game_mode  )
    );
    
    

always_ff@(posedge clk)
begin
    if(result_game_valid | result_game_each_step_valid) begin
        value_seg_vld <= 'd1;
        if(result_game_mode == 0) begin
            value_seg <= result_player_1*10000 + count_steps_player_1;
            value_dp <= 8'b00010000;
        end else begin
            value_seg <= 'd10002000 + result_player_1*10000 + result_player_2;
            value_dp  <= 8'b10001000;
        end
    end else begin
        value_seg_vld <= 'd0;
    end
end


decoder_top decoder_7seg(
    .clk         (clk        ),    
    .value       (value_seg    ), 
    .value_dp    (value_dp     ),
    .value_valid (value_seg_vld),    
    .enable_7seg (enable_7seg),    
    .ca_o        (ca_o),
    .cb_o        (cb_o),
    .cc_o        (cc_o),
    .cd_o        (cd_o),
    .ce_o        (ce_o),
    .cf_o        (cf_o),
    .cg_o        (cg_o),
    .dp_o        (dp_o)
);
    
    
        
endmodule
