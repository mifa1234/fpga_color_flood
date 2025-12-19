`timescale 1ns / 1ps


module game
#(
    parameter BG_COLOR = 12'h323,
    parameter COLOR_1  = 12'hF00,
    parameter COLOR_2  = 12'h0F0,
    parameter COLOR_3  = 12'h00F,
    parameter COLOR_4  = 12'hFF0,
    parameter COLOR_5  = 12'h0FF,
    parameter COLOR_TRACK_BAR  = 12'h888,
    parameter COLOR_TRACK_BAR_PC  = 12'hF55,
    parameter COLOR_TRACK_BAR_USER  = 12'h55F,
    
    parameter ANTI_BOUNCE_DELAY = 'd9_000_000,// freeze after click any button// if change then see "cnt_key"
    
    parameter DRAW_MARK = 0,
    parameter NEW_YEAR = 2, //0 - off, 1 - case 1, 2 - case 2
    parameter ENABLE_SIMPLE_AI = 1, //work if ONLY_GAME_MODE_0 == 0
    parameter ONLY_GAME_MODE_0 = 0, //if "0" then support all value for game_mode. if "1" then support only game_mode=0
    parameter INDICATE_WHO_STEP = 1 //indicate who makes the move in the game
)(
    input clk,    //give me 25MHz/ pixel clock for 640x480 60Hz mode
    input rstn_pb,
    
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,
    output logic vga_v_sync = 0,
    output logic vga_h_sync = 0,
    output logic vga_pixel_valid = 0,
    
    input [1:0] mode_game,
    input key_ok,
    input key_select_up,//For simplicity, you can use only one signal: or key_select_up, or key_select_down
    input key_select_down,
    
    output logic result_game_each_step_valid = 0,
    output logic result_game_valid = 0,
    output logic [7:0] count_steps_player_1 = 0,
    output logic [7:0] count_steps_player_2 = 0,
    output logic [7:0] result_player_1 = 0, //user 1
    output logic [7:0] result_player_2 = 0, //PC or user 2
    output logic [1:0] result_game_mode = 0
    );

localparam MODE_GAME_ONE = 0;
localparam MODE_GAME_TWO = 1;
localparam MODE_GAME_TWO_PLAYERS = 2;



logic [1:0] mode_game_reg = 0;
logic rstn_pb_reg = 0, key_ok_reg = 0;

always_ff@(posedge clk)
begin
    rstn_pb_reg <= rstn_pb;
    if(rstn_pb_reg == 0) begin//latch mode game 
        if(ONLY_GAME_MODE_0 == 0) begin
            mode_game_reg <= mode_game;
        end else begin
            mode_game_reg <= MODE_GAME_ONE;
        end
    end
    
    
end


logic [11:0] color_num [0:4];
logic [2:0] color_pre_rand_arr [0:127]; 
logic [6:0] color_rand_pos = 0;
    
logic [11:0] frame_buffer[19:0][14:0];//   
logic [0:0] mask_user[19:0][14:0];//   
logic [0:0] mask_pc[19:0][14:0];//   

logic [11:0] image_array [31:0][31:0]; //[width][height]



logic [5:0] select_color_bar = 3; 


logic [9:0] track_bar_USER = 'd0, track_bar_PC = 'd0; // for user value (0, 640), count from pixel[0]// for PC value (640,0) count from pixel[639]
logic [7:0] cur_result_USER = 0, cur_result_PC = 0, cnt_cur_result_USER = 0, cnt_cur_result_PC = 0;
logic [13:0] mul_cur_result_USER, mul_cur_result_PC;
logic [11:0] cur_color_USER, cur_color_PC, cur_chioce_color, color_USER;
logic conditions_select_isTRUE,  flg_first_launch_pc = 1, flg_first_launch = 1; //flg_recalc_user = 1,
logic change_color_pc = 0, change_color_ai = 0;
logic [1:0] win_player; // 0 - user, 1 - PC(or 2 user), 2 - nobody

logic [7:0] cnt_steps_player_1, cnt_steps_player_2;

logic AI_go = 0, AI_ready = 0;


typedef enum bit [3:0] {WAIT_OK, WAIT_OK_PC, STEP_USER, RE_CALC_MASK_USER, CALC_CUR_RESULT_USER, BEFORE_WAIT_OK_PC, STEP_PC, RE_CALC_MASK_PC, CALC_CUR_RESULT_PC, END_GAME, GAME_STOP, ERR_SEL_COLOR_USER} state_game_t; 
state_game_t state_game, state_game_prev;

logic [5:0] counter_frame_vga = 0;	
    
    
logic [24:0] cnt_key = 0;    
always_ff@(posedge clk)
begin
    if(change_color_pc | change_color_ai) begin
        if(select_color_bar == 11) begin
            select_color_bar <= 3;
        end else begin
            select_color_bar <= select_color_bar + 2;
        end
    end else if(cnt_key == ANTI_BOUNCE_DELAY) begin
        if((state_game == WAIT_OK) || ((state_game == WAIT_OK_PC) && (mode_game_reg == MODE_GAME_TWO_PLAYERS)) ) begin
            if(key_select_up) begin
                cnt_key <= 'd0;
                if(select_color_bar == 3) begin
                    select_color_bar <= 11;
                end else begin
                    select_color_bar <= select_color_bar - 2;
                end
            end else if(key_select_down) begin
                cnt_key <= 'd0;
                if(select_color_bar == 11) begin
                    select_color_bar <= 3;
                end else begin
                    select_color_bar <= select_color_bar + 2;
                end
            end
            
            //test work TRACK_BAR
            if(key_ok) begin
                key_ok_reg <= 1'b1;
                cnt_key <= 'd0;
            end else begin
                key_ok_reg <= 1'b0;
            end
        end
        
    end else begin
        cnt_key <= cnt_key + 1;
        key_ok_reg <= 1'b0;
    end
end    
    
logic [27:0] cnt_error_delay;  
logic [4:0] cnt_block_h = 'd0, cnt_block_w = 'd0;
logic [4:0] cnt_block_h_pc = 'd0, cnt_block_w_pc = 'd0;
logic [6:0] count_total_add_color = 0, count_total_add_color_pc = 0;
integer init_i, init_i2;
integer init_j1, init_j2;  
integer init_m1, init_m2;    
always_ff@(posedge clk)
begin
    if(rstn_pb_reg == 0) begin
        color_rand_pos = color_rand_pos + 1;
        ///////////////////////////////////////////////
        //initialization of the working frame_buffer //
        ///////////////////////////////////////////////
        for (init_i=0; init_i < 20; init_i=init_i+1)
        begin
            frame_buffer[init_i][0] <= BG_COLOR;
            frame_buffer[init_i][1] <= BG_COLOR;
            
            frame_buffer[init_i][13] <= BG_COLOR;
            frame_buffer[init_i][14] <= BG_COLOR;
        end        
        for (init_i2=2; init_i2 < 13; init_i2=init_i2+1)
        begin
            frame_buffer[0][init_i2]  <= BG_COLOR;
            frame_buffer[1][init_i2]  <= BG_COLOR;
            frame_buffer[2][init_i2]  <= BG_COLOR;                    
            frame_buffer[18][init_i2] <= BG_COLOR;
            frame_buffer[19][init_i2] <= BG_COLOR;
        end        
        for (init_j1=3; init_j1 < 18; init_j1=init_j1+1)
        begin        
            for (init_j2=2; init_j2 < 13; init_j2=init_j2+1)
            begin
                if((init_j1 == 3) && (init_j2 == 2)) begin 
                    cur_color_USER <= color_num[color_pre_rand_arr[color_rand_pos]];
                    color_USER = color_num[color_pre_rand_arr[color_rand_pos]];
                end
                if((init_j1 == 17) && (init_j2 == 12)) begin
                    if(color_num[color_pre_rand_arr[color_rand_pos]] == color_USER)begin
                        case(color_USER)
                            COLOR_1: begin
                                frame_buffer[init_j1][init_j2] <=  COLOR_2;
                                cur_color_PC <= COLOR_2;
                            end
                            COLOR_2: begin
                                frame_buffer[init_j1][init_j2] <=  COLOR_3;
                                cur_color_PC <= COLOR_3;
                            end
                            COLOR_3: begin
                                frame_buffer[init_j1][init_j2] <=  COLOR_4;
                                cur_color_PC <= COLOR_4;
                            end
                            COLOR_4: begin
                                frame_buffer[init_j1][init_j2] <=  COLOR_5;
                                cur_color_PC <= COLOR_5;
                            end
                            COLOR_5: begin
                                frame_buffer[init_j1][init_j2] <=  COLOR_1;
                                cur_color_PC <= COLOR_1;
                            end
                        endcase
                    end else begin
                        frame_buffer[init_j1][init_j2] <=  color_num[color_pre_rand_arr[color_rand_pos]];
                        cur_color_PC <= color_num[color_pre_rand_arr[color_rand_pos]];
                    end
                end else begin 
                    frame_buffer[init_j1][init_j2] <=  color_num[color_pre_rand_arr[color_rand_pos]];
                end
                color_rand_pos = color_rand_pos + 1;
            end
        end
       
        frame_buffer[1][3]  <= color_num[0];
        frame_buffer[1][5]  <= color_num[1];
        frame_buffer[1][7]  <= color_num[2];
        frame_buffer[1][9]  <= color_num[3];
        frame_buffer[1][11] <= color_num[4];
        ///////////////////////////////////////////
        //end initial frame_buffer               //
        ///////////////////////////////////////////
        
        for (init_m1=0; init_m1 < 20; init_m1=init_m1+1)
        begin        
            for (init_m2=0; init_m2 < 15; init_m2=init_m2+1)
            begin
                mask_user[init_m1][init_m2] <= 'd0;
                mask_pc[init_m1][init_m2] <= 'd0;
            end
        end
        
        
        state_game <= WAIT_OK;
        
        cnt_error_delay <= 'd0;
        
        flg_first_launch <= 1'b1;
        
        count_total_add_color <= 'd0;
        count_total_add_color_pc <= 'd0;
        
        cur_result_USER <= 0;
        cur_result_PC <= 0;
        cnt_cur_result_USER <= 0;
        cnt_cur_result_PC <= 0;
        
        change_color_pc <= 'd0;
        
        cnt_steps_player_1 <= 'd0;
        cnt_steps_player_2 <= 'd0;
        
    end else begin //main logic GAME
        case(state_game)
            WAIT_OK: begin
                if(key_ok_reg) begin
                    if(conditions_select_isTRUE) begin//check cinditions for step
                        if(flg_first_launch) begin
                            if(ONLY_GAME_MODE_0 == 0) begin
                            case(mode_game_reg)
                                MODE_GAME_ONE: begin
                                    mask_user[3][2] <= 1'b1;
                                    cur_result_USER <= 1;
                                    cnt_steps_player_1 <= 'd1;
                                    state_game <= RE_CALC_MASK_USER;
                                end
                                MODE_GAME_TWO: begin
                                    mask_user[3][2] <= 1'b1;
                                    cur_result_USER <= 1;
                                    cnt_steps_player_1 <= 'd1;
                                    
                                    mask_pc[17][12] <= 1'b1;                                        
                                    cur_result_PC <= 1;
                                    cnt_steps_player_2 <= 'd1;
                                    
                                    //first recalc user, second recalc PC
                                    state_game <= RE_CALC_MASK_USER;

                                end
                                MODE_GAME_TWO_PLAYERS: begin
                                    mask_user[3][2] <= 1'b1;
                                    cur_result_USER <= 1;
                                    cnt_steps_player_1 <= 'd1;
                                    
                                    mask_pc[17][12] <= 1'b1;                                        
                                    cur_result_PC <= 1;
                                    cnt_steps_player_2 <= 'd1;
                                    
                                    //first recalc user, second recalc PC
                                    state_game <= RE_CALC_MASK_USER;
                                end
                            endcase 
                            end else begin
                                mask_user[3][2] <= 1'b1;
                                cur_result_USER <= 1;
                                cnt_steps_player_1 <= 'd1;
                                state_game <= RE_CALC_MASK_USER;
                            end                                                                                
                            
                        end else begin
                            state_game <= STEP_USER;
                            cnt_steps_player_1 <= cnt_steps_player_1 + 1;
                        end                        
                        //counters for  recalc mask
                        cnt_block_w = 'd3;
                        cnt_block_h = 'd2;
                    end else begin//error
                        state_game <= ERR_SEL_COLOR_USER;
                        state_game_prev <= WAIT_OK;
                    end
                end
            end
            RE_CALC_MASK_USER: begin
                // counterS
                if(cnt_block_w == 17) begin
                    cnt_block_w <= 'd3;
                    if(cnt_block_h == 12) begin
                        cnt_block_h <= 'd2;
                        if(count_total_add_color == 0) begin //repeat calc if count_total_add_color > 0
                            if(flg_first_launch) begin
                                state_game <= STEP_USER;
                                flg_first_launch <= 'd0;
                            end else begin
                                state_game <= CALC_CUR_RESULT_USER;
                                cnt_cur_result_USER <= 'd0;
                            end
                        end
                        //count_total_add_color <= 'd0;
                    end else begin
                        cnt_block_h <= cnt_block_h + 1;
                    end
                end else begin
                    cnt_block_w <= cnt_block_w + 1;
                end
                
                //recalc MASK
                if((mask_user[cnt_block_w][cnt_block_h] == 0) & (mask_pc[cnt_block_w][cnt_block_h] == 0)) begin //need recalc this block
                    if(mask_user[cnt_block_w-1][cnt_block_h] == 1) begin
                        if(frame_buffer[cnt_block_w][cnt_block_h] == frame_buffer[cnt_block_w-1][cnt_block_h]) begin
                            mask_user[cnt_block_w][cnt_block_h] <= 1;
                            count_total_add_color <= ((cnt_block_w == 3)  && (cnt_block_h == 2)) ? 'd1 : count_total_add_color + 1;
                        end
                    end else if(mask_user[cnt_block_w+1][cnt_block_h] == 1) begin
                        if(frame_buffer[cnt_block_w][cnt_block_h] == frame_buffer[cnt_block_w+1][cnt_block_h]) begin
                            mask_user[cnt_block_w][cnt_block_h] <= 1;
                            count_total_add_color <= ((cnt_block_w == 3)  && (cnt_block_h == 2)) ? 'd1 : count_total_add_color + 1;
                        end
                    end else if(mask_user[cnt_block_w][cnt_block_h -1] == 1) begin
                        if(frame_buffer[cnt_block_w][cnt_block_h] == frame_buffer[cnt_block_w][cnt_block_h -1]) begin
                            mask_user[cnt_block_w][cnt_block_h] <= 1;
                            count_total_add_color <= ((cnt_block_w == 3)  && (cnt_block_h == 2)) ? 'd1 : count_total_add_color + 1;
                        end
                    end else if(mask_user[cnt_block_w][cnt_block_h +1] == 1) begin
                        if(frame_buffer[cnt_block_w][cnt_block_h] == frame_buffer[cnt_block_w][cnt_block_h +1]) begin
                            mask_user[cnt_block_w][cnt_block_h] <= 1;
                            count_total_add_color <= ((cnt_block_w == 3)  && (cnt_block_h == 2)) ? 'd1 : count_total_add_color + 1;
                        end
                    end else begin
                        if((cnt_block_w == 3)  && (cnt_block_h == 2)) count_total_add_color <= 'd0 ;
                    end
                end else begin
                    if((cnt_block_w == 3)  && (cnt_block_h == 2)) count_total_add_color <= 'd0 ;
                end               
            end
            STEP_USER: begin
                
                if(cnt_block_w == 17) begin
                    cnt_block_w <= 'd3;
                    if(cnt_block_h == 12) begin
                        cnt_block_h <= 'd2;
                        state_game <= RE_CALC_MASK_USER;
                        cur_color_USER <= cur_chioce_color;
                    end else begin
                        cnt_block_h <= cnt_block_h + 1;
                    end
                end else begin
                    cnt_block_w <= cnt_block_w + 1;
                end
                
                
                if(mask_user[cnt_block_w][cnt_block_h] == 1) begin //set new color
                    frame_buffer[cnt_block_w][cnt_block_h] <= cur_chioce_color;
                end
            
            
            end
            CALC_CUR_RESULT_USER: begin
                if(cnt_block_w == 17) begin
                    cnt_block_w <= 'd3;
                    if(cnt_block_h == 12) begin
                        cnt_block_h <= 'd2;
                        case(mode_game_reg)
                            MODE_GAME_ONE: begin
                                if((cnt_cur_result_USER == 164) & (mask_user[cnt_block_w][cnt_block_h] == 1)) begin                            
                                    state_game <= END_GAME;
                                    cur_result_USER <= cnt_cur_result_USER + 1;
                                end else begin
                                    state_game <= WAIT_OK;
                                    result_game_each_step_valid <= 1'b1;
                                    cur_result_USER <= cnt_cur_result_USER;
                                end   
                            end
                            MODE_GAME_TWO: begin
                                if((cur_result_PC + cnt_cur_result_USER == 164) & (mask_user[cnt_block_w][cnt_block_h] == 1)) begin //end game, all field accept
                                    state_game <= END_GAME;
                                    cur_result_USER <= cnt_cur_result_USER + 1;
                                end else begin
                                    state_game <= WAIT_OK_PC;
                                    result_game_each_step_valid <= 1'b1;
                                    cur_result_USER <= cnt_cur_result_USER;
                                end
                            end
                            MODE_GAME_TWO_PLAYERS: begin
                                if((cur_result_PC + cnt_cur_result_USER == 164) & (mask_user[cnt_block_w][cnt_block_h] == 1)) begin //end game, all field accept
                                    state_game <= END_GAME;
                                    cur_result_USER <= cnt_cur_result_USER + 1;
                                end else begin
                                    state_game <= BEFORE_WAIT_OK_PC;
                                    result_game_each_step_valid <= 1'b1;
                                    cur_result_USER <= cnt_cur_result_USER;
                                end
                            end
                        endcase 
                        count_steps_player_1 <= cnt_steps_player_1;
                        count_steps_player_2 <= cnt_steps_player_2;
                        result_player_1   <= cur_result_USER;
                        result_player_2   <= cur_result_PC;
                        result_game_mode  <= mode_game_reg;                    
                    end else begin
                        cnt_block_h <= cnt_block_h + 1;
                    end
                end else begin
                    cnt_block_w <= cnt_block_w + 1;
                end
                
                if(mask_user[cnt_block_w][cnt_block_h] == 1) begin //set new color
                    cnt_cur_result_USER <= cnt_cur_result_USER + 1;
                end
            end
            
            
            BEFORE_WAIT_OK_PC: begin
                if(ONLY_GAME_MODE_0 == 0) begin
                    if(cnt_error_delay == 'd2_000_000) begin
                        cnt_error_delay <= 'd0;
                        state_game <= WAIT_OK_PC;
                    end else begin
                        cnt_error_delay <= cnt_error_delay+1;
                    end
                end
            end
            //stepS PC
            WAIT_OK_PC: begin   
                if(ONLY_GAME_MODE_0 == 0) begin             
                    case(mode_game_reg)
                        MODE_GAME_TWO: begin
                            if(ENABLE_SIMPLE_AI == 1) begin//simple AI
                                if(AI_go & AI_ready) begin// AI select color, go next
                                    AI_go <= 1'b0;
                                    if(flg_first_launch_pc) begin
                                        state_game <= RE_CALC_MASK_PC;
                                    end else begin
                                        state_game <= STEP_PC;
                                        cnt_steps_player_2 <= cnt_steps_player_2 + 1;
                                    end
                                end else begin //start work AI
                                    AI_go <= 1'b1;
                                end
                            end else begin//super easy mode AI
                                if(change_color_pc) begin
                                    change_color_pc <= 'd0;
                                end else begin
                                    if(conditions_select_isTRUE) begin// super simple AI. select first true color
                                        if(flg_first_launch_pc) begin
                                            state_game <= RE_CALC_MASK_PC;
                                        end else begin
                                            state_game <= STEP_PC;
                                            cnt_steps_player_2 <= cnt_steps_player_2 + 1;
                                        end
                                    end else begin
                                        change_color_pc <= 'd1;
                                    end
                                end
                            end
                        end
                        MODE_GAME_TWO_PLAYERS: begin //wait OK from USER2
                            if(key_ok_reg) begin //user 2 most press button
                                if(conditions_select_isTRUE) begin
                                    if(flg_first_launch_pc) begin
                                        state_game <= RE_CALC_MASK_PC;
                                    end else begin
                                        state_game <= STEP_PC;
                                        cnt_steps_player_2 <= cnt_steps_player_2 + 1;
                                    end
                                end else begin
                                    state_game <= ERR_SEL_COLOR_USER;
                                    state_game_prev <= WAIT_OK_PC;// save cur status for return here
                                end
                            end
                        end
                    endcase                
                    
                    //counters for  recalc mask
                    cnt_block_w_pc = 'd3;
                    cnt_block_h_pc = 'd2;
                end
            end
            
            RE_CALC_MASK_PC: begin
                if(ONLY_GAME_MODE_0 == 0) begin
                    // counterS
                    if(cnt_block_w_pc == 17) begin
                        cnt_block_w_pc <= 'd3;
                        if(cnt_block_h_pc == 12) begin
                            cnt_block_h_pc <= 'd2;
                            if(count_total_add_color_pc == 0) begin //repeat calc if count_total_add_color_pc > 0
                                if(flg_first_launch_pc) begin
                                    state_game <= STEP_PC;
                                    flg_first_launch_pc <= 'd0;
                                end else begin
                                    state_game <= CALC_CUR_RESULT_PC;
                                    cnt_cur_result_PC <= 'd0;
                                end
                            end
                        end else begin
                            cnt_block_h_pc <= cnt_block_h_pc + 1;
                        end
                    end else begin
                        cnt_block_w_pc <= cnt_block_w_pc + 1;
                    end
                    
                    //recalc MASK
                    if((mask_user[cnt_block_w_pc][cnt_block_h_pc] == 0) & (mask_pc[cnt_block_w_pc][cnt_block_h_pc] == 0)) begin //need recalc this block
                        if(mask_pc[cnt_block_w_pc-1][cnt_block_h_pc] == 1) begin
                            if(frame_buffer[cnt_block_w_pc][cnt_block_h_pc] == frame_buffer[cnt_block_w_pc-1][cnt_block_h_pc]) begin
                                mask_pc[cnt_block_w_pc][cnt_block_h_pc] <= 1;
                                count_total_add_color_pc <= ((cnt_block_w_pc == 3)  && (cnt_block_h_pc == 2)) ? 'd1 : count_total_add_color_pc + 1;
                            end
                        end else if(mask_pc[cnt_block_w_pc+1][cnt_block_h_pc] == 1) begin
                            if(frame_buffer[cnt_block_w_pc][cnt_block_h_pc] == frame_buffer[cnt_block_w_pc+1][cnt_block_h_pc]) begin
                                mask_pc[cnt_block_w_pc][cnt_block_h_pc] <= 1;
                                count_total_add_color_pc <= ((cnt_block_w_pc == 3)  && (cnt_block_h_pc == 2)) ? 'd1 : count_total_add_color_pc + 1;
                            end
                        end else if(mask_pc[cnt_block_w_pc][cnt_block_h_pc -1] == 1) begin
                            if(frame_buffer[cnt_block_w_pc][cnt_block_h_pc] == frame_buffer[cnt_block_w_pc][cnt_block_h_pc -1]) begin
                                mask_pc[cnt_block_w_pc][cnt_block_h_pc] <= 1;
                                count_total_add_color_pc <= ((cnt_block_w_pc == 3)  && (cnt_block_h_pc == 2)) ? 'd1 : count_total_add_color_pc + 1;
                            end
                        end else if(mask_pc[cnt_block_w_pc][cnt_block_h_pc +1] == 1) begin
                            if(frame_buffer[cnt_block_w_pc][cnt_block_h_pc] == frame_buffer[cnt_block_w_pc][cnt_block_h_pc +1]) begin
                                mask_pc[cnt_block_w_pc][cnt_block_h_pc] <= 1;
                                count_total_add_color_pc <= ((cnt_block_w_pc == 3)  && (cnt_block_h_pc == 2)) ? 'd1 : count_total_add_color_pc + 1;
                            end
                        end else begin
                            if((cnt_block_w_pc == 3)  && (cnt_block_h_pc == 2)) count_total_add_color_pc <= 'd0 ;
                        end
                    end else begin
                        if((cnt_block_w_pc == 3)  && (cnt_block_h_pc == 2)) count_total_add_color_pc <= 'd0 ;
                    end  
                end             
            end
            
            STEP_PC: begin    
                if(ONLY_GAME_MODE_0 == 0) begin            
                if(cnt_block_w_pc == 17) begin
                    cnt_block_w_pc <= 'd3;
                    if(cnt_block_h_pc == 12) begin
                        cnt_block_h_pc <= 'd2;
                        state_game <= RE_CALC_MASK_PC;
                        cur_color_PC <= cur_chioce_color;
                    end else begin
                        cnt_block_h_pc <= cnt_block_h_pc + 1;
                    end
                end else begin
                    cnt_block_w_pc <= cnt_block_w_pc + 1;
                end
                
                
                if(mask_pc[cnt_block_w_pc][cnt_block_h_pc] == 1) begin //set new color
                    frame_buffer[cnt_block_w_pc][cnt_block_h_pc] <= cur_chioce_color;
                end  
                end          
            end
            
            
            CALC_CUR_RESULT_PC: begin
            if(ONLY_GAME_MODE_0 == 0) begin
                if(cnt_block_w_pc == 17) begin
                    cnt_block_w_pc <= 'd3;
                    if(cnt_block_h_pc == 12) begin
                        cnt_block_h_pc <= 'd2;                        
                        //this is only mode 2 player.
                        if(((cnt_cur_result_PC + cur_result_USER) == 164) & (mask_pc[cnt_block_w_pc][cnt_block_h_pc] == 1)) begin //end game, all field accept
                            state_game <= END_GAME;
                            cur_result_PC <= cnt_cur_result_PC + 1;
                        end else begin
                            state_game <= WAIT_OK; // goto first step user, again
                            result_game_each_step_valid <= 1'b1;
                            count_steps_player_1 <= cnt_steps_player_1;
                            count_steps_player_2 <= cnt_steps_player_2;
                            result_player_1   <= cur_result_USER;
                            result_player_2   <= cur_result_PC;
                            result_game_mode  <= mode_game_reg;
                            cur_result_PC <= cnt_cur_result_PC;
                        end
                 
                    end else begin
                        cnt_block_h_pc <= cnt_block_h_pc + 1;
                    end
                end else begin
                    cnt_block_w_pc <= cnt_block_w_pc + 1;
                end
                
                if(mask_pc[cnt_block_w_pc][cnt_block_h_pc] == 1) begin //set new color
                    cnt_cur_result_PC <= cnt_cur_result_PC + 1;
                end
                end
            end
            
            
            ERR_SEL_COLOR_USER: begin
                if(cnt_error_delay == 'd50_000_000) begin
                    cnt_error_delay <= 'd0;
                    if(state_game_prev == WAIT_OK_PC) begin
                        state_game <= WAIT_OK_PC;
                    end else begin
                        state_game <= WAIT_OK;
                    end
                end else begin
                    cnt_error_delay <= cnt_error_delay + 1;
                end
            end
            END_GAME: begin
                state_game <= GAME_STOP;
                
                result_game_valid <= 1;
                count_steps_player_1 <= cnt_steps_player_1;
                count_steps_player_2 <= cnt_steps_player_2;
                result_player_1   <= cur_result_USER;
                result_player_2   <= cur_result_PC;
                result_game_mode  <= mode_game_reg;
            end
            GAME_STOP: begin
                result_game_valid <= 0;
            end
            default: begin
            end
        endcase
        
        if(result_game_each_step_valid == 1'b1) begin
            result_game_each_step_valid <= 1'b0;
        end
        
        //inticate who step now
        if(INDICATE_WHO_STEP == 1) begin
            if(state_game == WAIT_OK) begin
                if(counter_frame_vga[5]) begin
                    frame_buffer[3][1] <= COLOR_TRACK_BAR_USER;
                end else begin
                    frame_buffer[3][1] <= BG_COLOR;
                end
                frame_buffer[18][12] <= BG_COLOR;
            end else if((ONLY_GAME_MODE_0 == 0) & (state_game == WAIT_OK_PC)) begin
                if(counter_frame_vga[5]) begin
                    frame_buffer[18][12] <= COLOR_TRACK_BAR_PC; 
                end else begin
                    frame_buffer[18][12] <= BG_COLOR;
                end
                frame_buffer[3][1] <= BG_COLOR; 
            end else begin
                frame_buffer[3][1] <= BG_COLOR;
                frame_buffer[18][12] <= BG_COLOR;
            end
        end
    end
end    
    
    
assign cur_chioce_color =  (select_color_bar == 3) ? COLOR_1 :
                           (select_color_bar == 5) ? COLOR_2 :    
                           (select_color_bar == 7) ? COLOR_3 :    
                           (select_color_bar == 9) ? COLOR_4 :    
                           (select_color_bar ==11) ? COLOR_5 :
                           'd0;    
                           
assign conditions_select_isTRUE = (mode_game_reg == MODE_GAME_ONE) ? (cur_chioce_color != cur_color_USER) :
                                  (mode_game_reg == MODE_GAME_TWO) ? (cur_chioce_color != cur_color_USER) && (cur_chioce_color != cur_color_PC) :
                                  (mode_game_reg == MODE_GAME_TWO_PLAYERS) ? (cur_chioce_color != cur_color_USER) && (cur_chioce_color != cur_color_PC) :
                                  'd0;                           
    
    
assign win_player = ((state_game == GAME_STOP) & (cur_result_USER > cur_result_PC)) ? 'd0 : // win player0
                    (state_game == GAME_STOP) ? 'd1 : //// win player2 or PC
                    2'd2;    //win no body
                    
//convert result to scale 0-640 pixels    
assign mul_cur_result_USER = cur_result_USER * 'd62; 
assign mul_cur_result_PC = cur_result_PC * 'd62  ;

always_ff@(posedge clk)
begin
    if(rstn_pb_reg == 0) begin
        track_bar_USER <= 0;
        track_bar_PC   <= 0; 
    end else begin
        //calc for USER count
        if(cur_result_USER == 165) begin //if "one mode" and "end game"         
            track_bar_USER <= 'd639;
        end else begin
            track_bar_USER <= mul_cur_result_USER[13:4];
        end
        
        //calc for PC count
        if((mode_game_reg == MODE_GAME_TWO) || (mode_game_reg == MODE_GAME_TWO_PLAYERS)) begin
        
            if(track_bar_PC == 165) begin        
                track_bar_PC <= 'd0;
            end else begin
                track_bar_PC <= 'd640 - mul_cur_result_PC[13:4];
            end
            
        end else begin
            track_bar_PC   <= 'd640;
        end
    end
end    
    
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//                          LOGIC AI
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////    

logic [1:0] state_ai = 0;
logic [3:0] cnt_change_color = 0;
logic [6:0] cnt_max_add_color = 0; //avialable rect to add
logic [5:0] select_max_color_bar_cur_choice;
logic [6:0] count_total_add_color_ai = 0;
logic [4:0] cnt_block_h_ai = 'd0, cnt_block_w_ai = 'd0;
//implementation of simple AI
//We're looking for squares that can be attached to the current state. 
//We're focusing on the current PC color and selecting ones that can be repainted in the selected color, 
//and it will be next to it. For a PC player
always_ff@(posedge clk)
begin
    if((ENABLE_SIMPLE_AI == 1) && (ONLY_GAME_MODE_0 == 0)) begin
        if(rstn_pb_reg == 0) begin
            AI_ready <= 'd0;
            state_ai <= 'd0;
            cnt_change_color <= 'd0;
            count_total_add_color_ai <= 'd0;
        end else begin
            case(state_ai)
                0: begin//wait start task
                    if(AI_go) begin
                        state_ai <= 1;
                    end
                    cnt_max_add_color <= 'd0;
                    cnt_block_h_ai = 'd2;
                    cnt_block_w_ai = 'd3;
                end
                1: begin//choice color
                    if(cnt_change_color == 5) begin
                        cnt_change_color <= 0;
                        state_ai <= 3;//end find color
                    end else begin
                        if(change_color_ai) begin
                            change_color_ai <= 'd0;
                        end else begin
                            if(conditions_select_isTRUE) begin                                
                                cnt_change_color <= 'd0;
                                state_ai <= 2;
                            end else begin
                                change_color_ai <= 1'b1;
                            end
                            cnt_change_color <= cnt_change_color + 1;
                        end
                        
                    end
                end
                2: begin // count color rect
                    // counterS
                    if(cnt_block_w_ai == 17) begin
                        cnt_block_w_ai <= 'd3;
                        if(cnt_block_h_ai == 12) begin
                            cnt_block_h_ai <= 'd2;
                            if(count_total_add_color_ai >= cnt_max_add_color) begin // find max number rect for adding
                                cnt_max_add_color <= count_total_add_color_ai;
                                select_max_color_bar_cur_choice <= select_color_bar;
                            end
                            state_ai <= 1; // goto next color for check
                            change_color_ai <= 1'b1;
                        end else begin
                            cnt_block_h_ai <= cnt_block_h_ai + 1;
                        end
                    end else begin
                        cnt_block_w_ai <= cnt_block_w_ai + 1;
                    end
                    
                    //recalc MASK
                    if((mask_user[cnt_block_w_ai][cnt_block_h_ai] == 0) & (mask_pc[cnt_block_w_ai][cnt_block_h_ai] == 0)) begin //need recalc this block
                        if(mask_pc[cnt_block_w_ai-1][cnt_block_h_ai] == 1) begin
                            if(cur_chioce_color == frame_buffer[cnt_block_w_ai][cnt_block_h_ai]) begin
                                count_total_add_color_ai <= ((cnt_block_w_ai == 3)  && (cnt_block_h_ai == 2)) ? 'd1 : count_total_add_color_ai + 1;
                            end
                        end else if(mask_pc[cnt_block_w_ai+1][cnt_block_h_ai] == 1) begin
                            if(cur_chioce_color == frame_buffer[cnt_block_w_ai][cnt_block_h_ai]) begin
                                count_total_add_color_ai <= ((cnt_block_w_ai == 3)  && (cnt_block_h_ai == 2)) ? 'd1 : count_total_add_color_ai + 1;
                            end
                        end else if(mask_pc[cnt_block_w_ai][cnt_block_h_ai -1] == 1) begin
                            if(cur_chioce_color == frame_buffer[cnt_block_w_ai][cnt_block_h_ai]) begin
                                count_total_add_color_ai <= ((cnt_block_w_ai == 3)  && (cnt_block_h_ai == 2)) ? 'd1 : count_total_add_color_ai + 1;
                            end
                        end else if(mask_pc[cnt_block_w_ai][cnt_block_h_ai +1] == 1) begin
                            if(cur_chioce_color == frame_buffer[cnt_block_w_ai][cnt_block_h_ai]) begin
                                count_total_add_color_ai <= ((cnt_block_w_ai == 3)  && (cnt_block_h_ai == 2)) ? 'd1 : count_total_add_color_ai + 1;
                            end
                        end else begin
                            if((cnt_block_w_ai == 3)  && (cnt_block_h_ai == 2)) count_total_add_color_ai <= 'd0 ;
                        end
                    end else begin
                        if((cnt_block_w_ai == 3)  && (cnt_block_h_ai == 2)) count_total_add_color_ai <= 'd0 ;
                    end  
                end
                3: begin // restore select color/ send to main FSM
                    if(change_color_ai) begin
                            change_color_ai <= 'd0;
                    end else begin
                        if(select_max_color_bar_cur_choice == select_color_bar) begin                                
                            if(AI_go & AI_ready) begin
                                state_ai <= 0;
                                AI_ready <= 'd0; 
                            end else begin
                                AI_ready <= 'd1;                                
                            end                            
                        end else begin
                            change_color_ai <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end
end    
 
    
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//                          OUTPUT VGA CODE
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////    
    
logic [3:0] r_vga = '0;
logic [3:0] g_vga = '0;
logic [3:0] b_vga = '0;


//resize _width VGA
assign vga_r = r_vga[3:0];
assign vga_g = g_vga[3:0];
assign vga_b = b_vga[3:0];


logic [10:0] cnt_h = 'd0;
logic [10:0] cnt_v = 'd0;

logic flg_imag;
assign flg_imag = (cnt_h < 'd640 && cnt_v < 'd480) ? 'd1 : 'd0;

always_ff@(posedge clk)
begin
    if(cnt_h >= 'd799) begin //640 + 16 + 96(sync) + 48
		cnt_h <= 'd0;
		if(cnt_v >= 'd524) begin //480 + 10 + 2(sync) + 33
			cnt_v <= 'd0;
			//if(INDICATE_WHO_STEP == 1) begin
			 counter_frame_vga <= counter_frame_vga + 1;
			//end			
		end else begin
			cnt_v <= cnt_v + 1;
		end
	end else begin
		cnt_h <= cnt_h + 1;		
	end	
end



always_ff@(posedge clk)
begin
     
     if(cnt_v[10:5] == 5'd14) begin //draw track bar //win_player
         {r_vga, g_vga, b_vga} <= (flg_imag  & (win_player == 2'd0) & counter_frame_vga[5] & (cnt_h < track_bar_USER) & ((cnt_v[4:0] == 5'd0) || (cnt_v[4:0] == 5'd31) || (cnt_h == 'd0) || (cnt_h == (track_bar_USER-1)))) ? 12'hFFF :
                                  (flg_imag  & (ONLY_GAME_MODE_0 == 0) & (win_player == 2'd1) & counter_frame_vga[5] & (cnt_h > track_bar_PC) & ((cnt_v[4:0] == 5'd0) || (cnt_v[4:0] == 5'd31) || (cnt_h == 'd639) || (cnt_h == (track_bar_PC+1)))) ? 12'hFFF :
                                  (flg_imag & (cnt_h < track_bar_USER)) ? COLOR_TRACK_BAR_USER : 
                                  (flg_imag & (cnt_h > track_bar_PC))   ? COLOR_TRACK_BAR_PC :
                                  (flg_imag) ? COLOR_TRACK_BAR :
                                   12'd0;
     end else if((cnt_h[10:5] == 6'd1) && (select_color_bar == cnt_v[10:5])) begin//draw rect select color// and X for error choice color
         r_vga <= (flg_imag & ((cnt_v[4:0]==5'd0) || (cnt_v[4:0]==5'd31) || (cnt_h[4:0] == 5'd0) || (cnt_h[4:0] == 5'd31))) ? ~frame_buffer[cnt_h[10:5]][cnt_v[10:5]][11:8] : //rect
                  (flg_imag & cnt_error_delay[22] & (state_game == ERR_SEL_COLOR_USER) & ((cnt_v[4:0]==cnt_h[4:0]) || (cnt_v[4:0]==(31 - cnt_h[4:0])) )) ? ~frame_buffer[cnt_h[10:5]][cnt_v[10:5]][11:8] :// draw X
                  (flg_imag) ? frame_buffer[cnt_h[10:5]][cnt_v[10:5]][11:8] : 
                  'd0;
         g_vga <= (flg_imag & ((cnt_v[4:0]==5'd0) || (cnt_v[4:0]==5'd31) || (cnt_h[4:0] == 5'd0) || (cnt_h[4:0] == 5'd31))) ? ~frame_buffer[cnt_h[10:5]][cnt_v[10:5]][7:4] : 
                  (flg_imag & cnt_error_delay[22] & (state_game == ERR_SEL_COLOR_USER) & ((cnt_v[4:0]==cnt_h[4:0]) || (cnt_v[4:0]==(31 - cnt_h[4:0])) )) ? ~frame_buffer[cnt_h[10:5]][cnt_v[10:5]][7:4] :
                  (flg_imag) ? frame_buffer[cnt_h[10:5]][cnt_v[10:5]][7:4] : 
                  'd0;
         b_vga <= (flg_imag & ((cnt_v[4:0]==5'd0) || (cnt_v[4:0]==5'd31) || (cnt_h[4:0] == 5'd0) || (cnt_h[4:0] == 5'd31))) ? ~frame_buffer[cnt_h[10:5]][cnt_v[10:5]][3:0] : 
                  (flg_imag & cnt_error_delay[22] & (state_game == ERR_SEL_COLOR_USER) & ((cnt_v[4:0]==cnt_h[4:0]) || (cnt_v[4:0]==(31 - cnt_h[4:0])) )) ? ~frame_buffer[cnt_h[10:5]][cnt_v[10:5]][3:0] :
                  (flg_imag) ? frame_buffer[cnt_h[10:5]][cnt_v[10:5]][3:0] : 
                  'd0;
     end else if((DRAW_MARK == 1) & (mask_user[cnt_h[10:5]][cnt_v[10:5]] == 1) & (cnt_v[4:0]==5'd15) & (cnt_h[4:0]==5'd15)) begin//DRAW_MARK in center rect for user player
         r_vga <= (flg_imag) ? 4'hF : 'd0;
         g_vga <= (flg_imag) ? 4'hF : 'd0;
         b_vga <= (flg_imag) ? 4'hF : 'd0;
    end else if((DRAW_MARK == 1) & (mask_pc[cnt_h[10:5]][cnt_v[10:5]] == 1) & (cnt_v[4:0]==5'd15) & (cnt_h[4:0]==5'd15)) begin//DRAW_MARK in center rect for PC player
         r_vga <= (flg_imag) ? 4'h0 : 'd0;
         g_vga <= (flg_imag) ? 4'h0 : 'd0;
         b_vga <= (flg_imag) ? 4'h0 : 'd0;         
     end else begin     
         if((NEW_YEAR != 0) & (image_array[cnt_v[4:0]][cnt_h[4:0]] != 0) & (frame_buffer[cnt_h[10:5]][cnt_v[10:5]] == BG_COLOR)) begin
             {r_vga, g_vga, b_vga} <= (flg_imag) ? image_array[cnt_v[4:0]][cnt_h[4:0]] : 'd0;
         end else begin
             r_vga <= (flg_imag) ? frame_buffer[cnt_h[10:5]][cnt_v[10:5]][11:8] : 'd0;
             g_vga <= (flg_imag) ? frame_buffer[cnt_h[10:5]][cnt_v[10:5]][7:4] : 'd0;
             b_vga <= (flg_imag) ? frame_buffer[cnt_h[10:5]][cnt_v[10:5]][3:0] : 'd0;
         end
	 end


	vga_h_sync <= (cnt_h>(640+16-1) && cnt_h<(640+16+96-1)) ? 'd0 : 'd1; // for 640*480 active level - low
	vga_v_sync <= (cnt_v>(480+10-1) && cnt_v<(480+10 +2-1)) ? 'd0 : 'd1; // for 640*480 active level - low
	
	vga_pixel_valid <= flg_imag;
end    



initial begin
   
    color_num[0] = COLOR_1;
    color_num[1] = COLOR_2;
    color_num[2] = COLOR_3;
    color_num[3] = COLOR_4;
    color_num[4] = COLOR_5;
    
    
end


initial begin
    color_pre_rand_arr[0] = 3'd2;
    color_pre_rand_arr[1] = 3'd4;
    color_pre_rand_arr[2] = 3'd1;
    color_pre_rand_arr[3] = 3'd3;
    color_pre_rand_arr[4] = 3'd0;
    color_pre_rand_arr[5] = 3'd4;
    color_pre_rand_arr[6] = 3'd2;
    color_pre_rand_arr[7] = 3'd1;
    color_pre_rand_arr[8] = 3'd3;
    color_pre_rand_arr[9] = 3'd4;
    color_pre_rand_arr[10] = 3'd0;
    color_pre_rand_arr[11] = 3'd2;
    color_pre_rand_arr[12] = 3'd4;
    color_pre_rand_arr[13] = 3'd1;
    color_pre_rand_arr[14] = 3'd3;
    color_pre_rand_arr[15] = 3'd2;
    color_pre_rand_arr[16] = 3'd0;
    color_pre_rand_arr[17] = 3'd4;
    color_pre_rand_arr[18] = 3'd1;
    color_pre_rand_arr[19] = 3'd3;
    color_pre_rand_arr[20] = 3'd4;
    color_pre_rand_arr[21] = 3'd2;
    color_pre_rand_arr[22] = 3'd0;
    color_pre_rand_arr[23] = 3'd1;
    color_pre_rand_arr[24] = 3'd3;
    color_pre_rand_arr[25] = 3'd4;
    color_pre_rand_arr[26] = 3'd2;
    color_pre_rand_arr[27] = 3'd1;
    color_pre_rand_arr[28] = 3'd0;
    color_pre_rand_arr[29] = 3'd3;
    color_pre_rand_arr[30] = 3'd4;
    color_pre_rand_arr[31] = 3'd2;
    color_pre_rand_arr[32] = 3'd1;
    color_pre_rand_arr[33] = 3'd3;
    color_pre_rand_arr[34] = 3'd0;
    color_pre_rand_arr[35] = 3'd4;
    color_pre_rand_arr[36] = 3'd2;
    color_pre_rand_arr[37] = 3'd1;
    color_pre_rand_arr[38] = 3'd3;
    color_pre_rand_arr[39] = 3'd4;
    color_pre_rand_arr[40] = 3'd0;
    color_pre_rand_arr[41] = 3'd2;
    color_pre_rand_arr[42] = 3'd4;
    color_pre_rand_arr[43] = 3'd1;
    color_pre_rand_arr[44] = 3'd3;
    color_pre_rand_arr[45] = 3'd2;
    color_pre_rand_arr[46] = 3'd0;
    color_pre_rand_arr[47] = 3'd4;
    color_pre_rand_arr[48] = 3'd1;
    color_pre_rand_arr[49] = 3'd3;
    color_pre_rand_arr[50] = 3'd4;
    color_pre_rand_arr[51] = 3'd2;
    color_pre_rand_arr[52] = 3'd1;
    color_pre_rand_arr[53] = 3'd0;
    color_pre_rand_arr[54] = 3'd3;
    color_pre_rand_arr[55] = 3'd4;
    color_pre_rand_arr[56] = 3'd2;
    color_pre_rand_arr[57] = 3'd1;
    color_pre_rand_arr[58] = 3'd3;
    color_pre_rand_arr[59] = 3'd4;
    color_pre_rand_arr[60] = 3'd0;
    color_pre_rand_arr[61] = 3'd2;
    color_pre_rand_arr[62] = 3'd4;
    color_pre_rand_arr[63] = 3'd1;
    color_pre_rand_arr[64] = 3'd3;
    color_pre_rand_arr[65] = 3'd2;
    color_pre_rand_arr[66] = 3'd0;
    color_pre_rand_arr[67] = 3'd4;
    color_pre_rand_arr[68] = 3'd1;
    color_pre_rand_arr[69] = 3'd3;
    color_pre_rand_arr[70] = 3'd4;
    color_pre_rand_arr[71] = 3'd2;
    color_pre_rand_arr[72] = 3'd1;
    color_pre_rand_arr[73] = 3'd0;
    color_pre_rand_arr[74] = 3'd3;
    color_pre_rand_arr[75] = 3'd4;
    color_pre_rand_arr[76] = 3'd2;
    color_pre_rand_arr[77] = 3'd1;
    color_pre_rand_arr[78] = 3'd3;
    color_pre_rand_arr[79] = 3'd4;
    color_pre_rand_arr[80] = 3'd0;
    color_pre_rand_arr[81] = 3'd2;
    color_pre_rand_arr[82] = 3'd4;
    color_pre_rand_arr[83] = 3'd1;
    color_pre_rand_arr[84] = 3'd3;
    color_pre_rand_arr[85] = 3'd2;
    color_pre_rand_arr[86] = 3'd0;
    color_pre_rand_arr[87] = 3'd4;
    color_pre_rand_arr[88] = 3'd1;
    color_pre_rand_arr[89] = 3'd3;
    color_pre_rand_arr[90] = 3'd4;
    color_pre_rand_arr[91] = 3'd2;
    color_pre_rand_arr[92] = 3'd1;
    color_pre_rand_arr[93] = 3'd0;
    color_pre_rand_arr[94] = 3'd3;
    color_pre_rand_arr[95] = 3'd4;
    color_pre_rand_arr[96] = 3'd2;
    color_pre_rand_arr[97] = 3'd1;
    color_pre_rand_arr[98] = 3'd3;
    color_pre_rand_arr[99] = 3'd4;
    color_pre_rand_arr[100] = 3'd3;
    color_pre_rand_arr[101] = 3'd1;
    color_pre_rand_arr[102] = 3'd2;
    color_pre_rand_arr[103] = 3'd4;
    color_pre_rand_arr[104] = 3'd0;
    color_pre_rand_arr[105] = 3'd3;
    color_pre_rand_arr[106] = 3'd1;
    color_pre_rand_arr[107] = 3'd2;
    color_pre_rand_arr[108] = 3'd4;
    color_pre_rand_arr[109] = 3'd0;
    color_pre_rand_arr[110] = 3'd1;
    color_pre_rand_arr[111] = 3'd3;
    color_pre_rand_arr[112] = 3'd2;
    color_pre_rand_arr[113] = 3'd4;
    color_pre_rand_arr[114] = 3'd0;
    color_pre_rand_arr[115] = 3'd1;
    color_pre_rand_arr[116] = 3'd3;
    color_pre_rand_arr[117] = 3'd2;
    color_pre_rand_arr[118] = 3'd4;
    color_pre_rand_arr[119] = 3'd0;
    color_pre_rand_arr[120] = 3'd1;
    color_pre_rand_arr[121] = 3'd3;
    color_pre_rand_arr[122] = 3'd2;
    color_pre_rand_arr[123] = 3'd4;
    color_pre_rand_arr[124] = 3'd1;
    color_pre_rand_arr[125] = 3'd0;
    color_pre_rand_arr[126] = 3'd3;
    color_pre_rand_arr[127] = 3'd2;
end

if(NEW_YEAR == 2) begin
    initial begin
           
        //  0
        image_array[0][0] = 12'h000;
        image_array[0][1] = 12'h000;
        image_array[0][2] = 12'h000;
        image_array[0][3] = 12'h000;
        image_array[0][4] = 12'h000;
        image_array[0][5] = 12'h000;
        image_array[0][6] = 12'h000;
        image_array[0][7] = 12'h000;
        image_array[0][8] = 12'h000;
        image_array[0][9] = 12'h000;
        image_array[0][10] = 12'h000;
        image_array[0][11] = 12'h000;
        image_array[0][12] = 12'h000;
        image_array[0][13] = 12'h000;
        image_array[0][14] = 12'h000;
        image_array[0][15] = 12'h000;
        image_array[0][16] = 12'h000;
        image_array[0][17] = 12'h000;
        image_array[0][18] = 12'h000;
        image_array[0][19] = 12'h000;
        image_array[0][20] = 12'h000;
        image_array[0][21] = 12'h000;
        image_array[0][22] = 12'h000;
        image_array[0][23] = 12'h000;
        image_array[0][24] = 12'h000;
        image_array[0][25] = 12'h000;
        image_array[0][26] = 12'h000;
        image_array[0][27] = 12'h000;
        image_array[0][28] = 12'h000;
        image_array[0][29] = 12'h000;
        image_array[0][30] = 12'h000;
        image_array[0][31] = 12'h000;
    
        //  1
        image_array[1][0] = 12'h000;
        image_array[1][1] = 12'h000;
        image_array[1][2] = 12'h000;
        image_array[1][3] = 12'h000;
        image_array[1][4] = 12'h000;
        image_array[1][5] = 12'h000;
        image_array[1][6] = 12'h000;
        image_array[1][7] = 12'h000;
        image_array[1][8] = 12'h000;
        image_array[1][9] = 12'h000;
        image_array[1][10] = 12'h000;
        image_array[1][11] = 12'h000;
        image_array[1][12] = 12'h000;
        image_array[1][13] = 12'h000;
        image_array[1][14] = 12'h000;
        image_array[1][15] = 12'h000;
        image_array[1][16] = 12'h000;
        image_array[1][17] = 12'h000;
        image_array[1][18] = 12'h000;
        image_array[1][19] = 12'h000;
        image_array[1][20] = 12'h000;
        image_array[1][21] = 12'h000;
        image_array[1][22] = 12'h000;
        image_array[1][23] = 12'h000;
        image_array[1][24] = 12'h000;
        image_array[1][25] = 12'h000;
        image_array[1][26] = 12'h000;
        image_array[1][27] = 12'h000;
        image_array[1][28] = 12'h000;
        image_array[1][29] = 12'h000;
        image_array[1][30] = 12'h000;
        image_array[1][31] = 12'h000;
    
        //  2
        image_array[2][0] = 12'h000;
        image_array[2][1] = 12'h000;
        image_array[2][2] = 12'h000;
        image_array[2][3] = 12'h000;
        image_array[2][4] = 12'h000;
        image_array[2][5] = 12'h000;
        image_array[2][6] = 12'h000;
        image_array[2][7] = 12'h000;
        image_array[2][8] = 12'h000;
        image_array[2][9] = 12'h000;
        image_array[2][10] = 12'h000;
        image_array[2][11] = 12'h000;
        image_array[2][12] = 12'h000;
        image_array[2][13] = 12'h000;
        image_array[2][14] = 12'h000;
        image_array[2][15] = 12'h000;
        image_array[2][16] = 12'h000;
        image_array[2][17] = 12'h000;
        image_array[2][18] = 12'h000;
        image_array[2][19] = 12'h000;
        image_array[2][20] = 12'h000;
        image_array[2][21] = 12'h000;
        image_array[2][22] = 12'h000;
        image_array[2][23] = 12'h000;
        image_array[2][24] = 12'h000;
        image_array[2][25] = 12'h000;
        image_array[2][26] = 12'h000;
        image_array[2][27] = 12'h000;
        image_array[2][28] = 12'h000;
        image_array[2][29] = 12'h000;
        image_array[2][30] = 12'h000;
        image_array[2][31] = 12'h000;
    
        //  3
        image_array[3][0] = 12'h000;
        image_array[3][1] = 12'h000;
        image_array[3][2] = 12'h000;
        image_array[3][3] = 12'h000;
        image_array[3][4] = 12'h000;
        image_array[3][5] = 12'h000;
        image_array[3][6] = 12'h000;
        image_array[3][7] = 12'h000;
        image_array[3][8] = 12'h000;
        image_array[3][9] = 12'h000;
        image_array[3][10] = 12'h000;
        image_array[3][11] = 12'h000;
        image_array[3][12] = 12'h000;
        image_array[3][13] = 12'h000;
        image_array[3][14] = 12'h000;
        image_array[3][15] = 12'h000;
        image_array[3][16] = 12'h000;
        image_array[3][17] = 12'h000;
        image_array[3][18] = 12'h000;
        image_array[3][19] = 12'h000;
        image_array[3][20] = 12'h000;
        image_array[3][21] = 12'h000;
        image_array[3][22] = 12'h000;
        image_array[3][23] = 12'h000;
        image_array[3][24] = 12'h000;
        image_array[3][25] = 12'h000;
        image_array[3][26] = 12'h000;
        image_array[3][27] = 12'h000;
        image_array[3][28] = 12'h000;
        image_array[3][29] = 12'h000;
        image_array[3][30] = 12'h000;
        image_array[3][31] = 12'h000;
    
        //  4
        image_array[4][0] = 12'h000;
        image_array[4][1] = 12'h000;
        image_array[4][2] = 12'h000;
        image_array[4][3] = 12'h000;
        image_array[4][4] = 12'h000;
        image_array[4][5] = 12'h000;
        image_array[4][6] = 12'h000;
        image_array[4][7] = 12'h000;
        image_array[4][8] = 12'h000;
        image_array[4][9] = 12'h000;
        image_array[4][10] = 12'h000;
        image_array[4][11] = 12'h000;
        image_array[4][12] = 12'h000;
        image_array[4][13] = 12'h000;
        image_array[4][14] = 12'h000;
        image_array[4][15] = 12'h063;
        image_array[4][16] = 12'h063;
        image_array[4][17] = 12'h000;
        image_array[4][18] = 12'h000;
        image_array[4][19] = 12'h000;
        image_array[4][20] = 12'h000;
        image_array[4][21] = 12'h000;
        image_array[4][22] = 12'h000;
        image_array[4][23] = 12'h000;
        image_array[4][24] = 12'h000;
        image_array[4][25] = 12'h000;
        image_array[4][26] = 12'h000;
        image_array[4][27] = 12'h000;
        image_array[4][28] = 12'h000;
        image_array[4][29] = 12'h000;
        image_array[4][30] = 12'h000;
        image_array[4][31] = 12'h000;
    
        //  5
        image_array[5][0] = 12'h000;
        image_array[5][1] = 12'h000;
        image_array[5][2] = 12'h000;
        image_array[5][3] = 12'h000;
        image_array[5][4] = 12'h000;
        image_array[5][5] = 12'h000;
        image_array[5][6] = 12'h000;
        image_array[5][7] = 12'h000;
        image_array[5][8] = 12'h000;
        image_array[5][9] = 12'h000;
        image_array[5][10] = 12'h000;
        image_array[5][11] = 12'h000;
        image_array[5][12] = 12'h000;
        image_array[5][13] = 12'h000;
        image_array[5][14] = 12'h042;
        image_array[5][15] = 12'h063;
        image_array[5][16] = 12'h063;
        image_array[5][17] = 12'h042;
        image_array[5][18] = 12'h000;
        image_array[5][19] = 12'h000;
        image_array[5][20] = 12'h000;
        image_array[5][21] = 12'h000;
        image_array[5][22] = 12'h000;
        image_array[5][23] = 12'h000;
        image_array[5][24] = 12'h000;
        image_array[5][25] = 12'h000;
        image_array[5][26] = 12'h000;
        image_array[5][27] = 12'h000;
        image_array[5][28] = 12'h000;
        image_array[5][29] = 12'h000;
        image_array[5][30] = 12'h000;
        image_array[5][31] = 12'h000;
    
        //  6
        image_array[6][0] = 12'h000;
        image_array[6][1] = 12'h000;
        image_array[6][2] = 12'h000;
        image_array[6][3] = 12'h000;
        image_array[6][4] = 12'h000;
        image_array[6][5] = 12'h000;
        image_array[6][6] = 12'h000;
        image_array[6][7] = 12'h000;
        image_array[6][8] = 12'h000;
        image_array[6][9] = 12'h000;
        image_array[6][10] = 12'h000;
        image_array[6][11] = 12'h000;
        image_array[6][12] = 12'h000;
        image_array[6][13] = 12'h031;
        image_array[6][14] = 12'h073;
        image_array[6][15] = 12'h063;
        image_array[6][16] = 12'h063;
        image_array[6][17] = 12'h073;
        image_array[6][18] = 12'h031;
        image_array[6][19] = 12'h000;
        image_array[6][20] = 12'h000;
        image_array[6][21] = 12'h000;
        image_array[6][22] = 12'h000;
        image_array[6][23] = 12'h000;
        image_array[6][24] = 12'h000;
        image_array[6][25] = 12'h000;
        image_array[6][26] = 12'h000;
        image_array[6][27] = 12'h000;
        image_array[6][28] = 12'h000;
        image_array[6][29] = 12'h000;
        image_array[6][30] = 12'h000;
        image_array[6][31] = 12'h000;
    
        //  7
        image_array[7][0] = 12'h000;
        image_array[7][1] = 12'h000;
        image_array[7][2] = 12'h000;
        image_array[7][3] = 12'h000;
        image_array[7][4] = 12'h000;
        image_array[7][5] = 12'h000;
        image_array[7][6] = 12'h000;
        image_array[7][7] = 12'h000;
        image_array[7][8] = 12'h000;
        image_array[7][9] = 12'h000;
        image_array[7][10] = 12'h000;
        image_array[7][11] = 12'h000;
        image_array[7][12] = 12'h042;
        image_array[7][13] = 12'h073;
        image_array[7][14] = 12'h063;
        image_array[7][15] = 12'h063;
        image_array[7][16] = 12'h063;
        image_array[7][17] = 12'h063;
        image_array[7][18] = 12'h073;
        image_array[7][19] = 12'h042;
        image_array[7][20] = 12'h000;
        image_array[7][21] = 12'h000;
        image_array[7][22] = 12'h000;
        image_array[7][23] = 12'h000;
        image_array[7][24] = 12'h000;
        image_array[7][25] = 12'h000;
        image_array[7][26] = 12'h000;
        image_array[7][27] = 12'h000;
        image_array[7][28] = 12'h000;
        image_array[7][29] = 12'h000;
        image_array[7][30] = 12'h000;
        image_array[7][31] = 12'h000;
    
        //  8
        image_array[8][0] = 12'h000;
        image_array[8][1] = 12'h000;
        image_array[8][2] = 12'h000;
        image_array[8][3] = 12'h000;
        image_array[8][4] = 12'h000;
        image_array[8][5] = 12'h000;
        image_array[8][6] = 12'h000;
        image_array[8][7] = 12'h000;
        image_array[8][8] = 12'h000;
        image_array[8][9] = 12'h000;
        image_array[8][10] = 12'h000;
        image_array[8][11] = 12'h063;
        image_array[8][12] = 12'h063;
        image_array[8][13] = 12'h063;
        image_array[8][14] = 12'h063;
        image_array[8][15] = 12'h063;
        image_array[8][16] = 12'h063;
        image_array[8][17] = 12'h063;
        image_array[8][18] = 12'h063;
        image_array[8][19] = 12'h063;
        image_array[8][20] = 12'h063;
        image_array[8][21] = 12'h000;
        image_array[8][22] = 12'h000;
        image_array[8][23] = 12'h000;
        image_array[8][24] = 12'h000;
        image_array[8][25] = 12'h000;
        image_array[8][26] = 12'h000;
        image_array[8][27] = 12'h000;
        image_array[8][28] = 12'h000;
        image_array[8][29] = 12'h000;
        image_array[8][30] = 12'h000;
        image_array[8][31] = 12'h000;
    
        //  9
        image_array[9][0] = 12'h000;
        image_array[9][1] = 12'h000;
        image_array[9][2] = 12'h000;
        image_array[9][3] = 12'h000;
        image_array[9][4] = 12'h000;
        image_array[9][5] = 12'h000;
        image_array[9][6] = 12'h000;
        image_array[9][7] = 12'h000;
        image_array[9][8] = 12'h000;
        image_array[9][9] = 12'h010;
        image_array[9][10] = 12'h084;
        image_array[9][11] = 12'hF72;
        image_array[9][12] = 12'h063;
        image_array[9][13] = 12'h063;
        image_array[9][14] = 12'h063;
        image_array[9][15] = 12'h063;
        image_array[9][16] = 12'h063;
        image_array[9][17] = 12'h063;
        image_array[9][18] = 12'h063;
        image_array[9][19] = 12'h063;
        image_array[9][20] = 12'hF72;
        image_array[9][21] = 12'h084;
        image_array[9][22] = 12'h010;
        image_array[9][23] = 12'h000;
        image_array[9][24] = 12'h000;
        image_array[9][25] = 12'h000;
        image_array[9][26] = 12'h000;
        image_array[9][27] = 12'h000;
        image_array[9][28] = 12'h000;
        image_array[9][29] = 12'h000;
        image_array[9][30] = 12'h000;
        image_array[9][31] = 12'h000;
    
        //  10
        image_array[10][0] = 12'h000;
        image_array[10][1] = 12'h000;
        image_array[10][2] = 12'h000;
        image_array[10][3] = 12'h000;
        image_array[10][4] = 12'h000;
        image_array[10][5] = 12'h000;
        image_array[10][6] = 12'h000;
        image_array[10][7] = 12'h000;
        image_array[10][8] = 12'h000;
        image_array[10][9] = 12'h000;
        image_array[10][10] = 12'h000;
        image_array[10][11] = 12'h032;
        image_array[10][12] = 12'h063;
        image_array[10][13] = 12'h073;
        image_array[10][14] = 12'h073;
        image_array[10][15] = 12'hF72;
        image_array[10][16] = 12'h073;
        image_array[10][17] = 12'h073;
        image_array[10][18] = 12'h073;
        image_array[10][19] = 12'h063;
        image_array[10][20] = 12'h032;
        image_array[10][21] = 12'h000;
        image_array[10][22] = 12'h000;
        image_array[10][23] = 12'h000;
        image_array[10][24] = 12'h000;
        image_array[10][25] = 12'h000;
        image_array[10][26] = 12'h000;
        image_array[10][27] = 12'h000;
        image_array[10][28] = 12'h000;
        image_array[10][29] = 12'h000;
        image_array[10][30] = 12'h000;
        image_array[10][31] = 12'h000;
    
        //  11
        image_array[11][0] = 12'h000;
        image_array[11][1] = 12'h000;
        image_array[11][2] = 12'h000;
        image_array[11][3] = 12'h000;
        image_array[11][4] = 12'h000;
        image_array[11][5] = 12'h000;
        image_array[11][6] = 12'h000;
        image_array[11][7] = 12'h000;
        image_array[11][8] = 12'h000;
        image_array[11][9] = 12'h000;
        image_array[11][10] = 12'h000;
        image_array[11][11] = 12'h000;
        image_array[11][12] = 12'h000;
        image_array[11][13] = 12'h000;
        image_array[11][14] = 12'h000;
        image_array[11][15] = 12'h000;
        image_array[11][16] = 12'h000;
        image_array[11][17] = 12'h000;
        image_array[11][18] = 12'h000;
        image_array[11][19] = 12'h000;
        image_array[11][20] = 12'h000;
        image_array[11][21] = 12'h000;
        image_array[11][22] = 12'h000;
        image_array[11][23] = 12'h000;
        image_array[11][24] = 12'h000;
        image_array[11][25] = 12'h000;
        image_array[11][26] = 12'h000;
        image_array[11][27] = 12'h000;
        image_array[11][28] = 12'h000;
        image_array[11][29] = 12'h000;
        image_array[11][30] = 12'h000;
        image_array[11][31] = 12'h000;
    
        //  12
        image_array[12][0] = 12'h000;
        image_array[12][1] = 12'h000;
        image_array[12][2] = 12'h000;
        image_array[12][3] = 12'h000;
        image_array[12][4] = 12'h000;
        image_array[12][5] = 12'h000;
        image_array[12][6] = 12'h000;
        image_array[12][7] = 12'h000;
        image_array[12][8] = 12'h000;
        image_array[12][9] = 12'h000;
        image_array[12][10] = 12'h000;
        image_array[12][11] = 12'h032;
        image_array[12][12] = 12'h073;
        image_array[12][13] = 12'h063;
        image_array[12][14] = 12'h063;
        image_array[12][15] = 12'h052;
        image_array[12][16] = 12'h052;
        image_array[12][17] = 12'h063;
        image_array[12][18] = 12'h063;
        image_array[12][19] = 12'h073;
        image_array[12][20] = 12'h032;
        image_array[12][21] = 12'h000;
        image_array[12][22] = 12'h000;
        image_array[12][23] = 12'h000;
        image_array[12][24] = 12'h000;
        image_array[12][25] = 12'h000;
        image_array[12][26] = 12'h000;
        image_array[12][27] = 12'h000;
        image_array[12][28] = 12'h000;
        image_array[12][29] = 12'h000;
        image_array[12][30] = 12'h000;
        image_array[12][31] = 12'h000;
    
        //  13
        image_array[13][0] = 12'h000;
        image_array[13][1] = 12'h000;
        image_array[13][2] = 12'h000;
        image_array[13][3] = 12'h000;
        image_array[13][4] = 12'h000;
        image_array[13][5] = 12'h000;
        image_array[13][6] = 12'h000;
        image_array[13][7] = 12'h000;
        image_array[13][8] = 12'h000;
        image_array[13][9] = 12'h000;
        image_array[13][10] = 12'h063;
        image_array[13][11] = 12'h073;
        image_array[13][12] = 12'h063;
        image_array[13][13] = 12'h063;
        image_array[13][14] = 12'h063;
        image_array[13][15] = 12'h063;
        image_array[13][16] = 12'h063;
        image_array[13][17] = 12'h063;
        image_array[13][18] = 12'h063;
        image_array[13][19] = 12'h063;
        image_array[13][20] = 12'h073;
        image_array[13][21] = 12'h063;
        image_array[13][22] = 12'h000;
        image_array[13][23] = 12'h000;
        image_array[13][24] = 12'h000;
        image_array[13][25] = 12'h000;
        image_array[13][26] = 12'h000;
        image_array[13][27] = 12'h000;
        image_array[13][28] = 12'h000;
        image_array[13][29] = 12'h000;
        image_array[13][30] = 12'h000;
        image_array[13][31] = 12'h000;
    
        //  14
        image_array[14][0] = 12'h000;
        image_array[14][1] = 12'h000;
        image_array[14][2] = 12'h000;
        image_array[14][3] = 12'h000;
        image_array[14][4] = 12'h000;
        image_array[14][5] = 12'h000;
        image_array[14][6] = 12'h000;
        image_array[14][7] = 12'h010;
        image_array[14][8] = 12'h042;
        image_array[14][9] = 12'h073;
        image_array[14][10] = 12'h063;
        image_array[14][11] = 12'h063;
        image_array[14][12] = 12'h063;
        image_array[14][13] = 12'h063;
        image_array[14][14] = 12'h063;
        image_array[14][15] = 12'h063;
        image_array[14][16] = 12'h063;
        image_array[14][17] = 12'h063;
        image_array[14][18] = 12'h063;
        image_array[14][19] = 12'h063;
        image_array[14][20] = 12'h063;
        image_array[14][21] = 12'h063;
        image_array[14][22] = 12'h073;
        image_array[14][23] = 12'h042;
        image_array[14][24] = 12'h010;
        image_array[14][25] = 12'h000;
        image_array[14][26] = 12'h000;
        image_array[14][27] = 12'h000;
        image_array[14][28] = 12'h000;
        image_array[14][29] = 12'h000;
        image_array[14][30] = 12'h000;
        image_array[14][31] = 12'h000;
    
        //  15
        image_array[15][0] = 12'h000;
        image_array[15][1] = 12'h000;
        image_array[15][2] = 12'h000;
        image_array[15][3] = 12'h000;
        image_array[15][4] = 12'h000;
        image_array[15][5] = 12'h000;
        image_array[15][6] = 12'h000;
        image_array[15][7] = 12'h031;
        image_array[15][8] = 12'h074;
        image_array[15][9] = 12'hFF0;
        image_array[15][10] = 12'h063;
        image_array[15][11] = 12'h063;
        image_array[15][12] = 12'h063;
        image_array[15][13] = 12'h063;
        image_array[15][14] = 12'h063;
        image_array[15][15] = 12'h063;
        image_array[15][16] = 12'h063;
        image_array[15][17] = 12'h063;
        image_array[15][18] = 12'h063;
        image_array[15][19] = 12'h063;
        image_array[15][20] = 12'h063;
        image_array[15][21] = 12'hFF0;
        image_array[15][22] = 12'h063;
        image_array[15][23] = 12'h074;
        image_array[15][24] = 12'h031;
        image_array[15][25] = 12'h000;
        image_array[15][26] = 12'h000;
        image_array[15][27] = 12'h000;
        image_array[15][28] = 12'h000;
        image_array[15][29] = 12'h000;
        image_array[15][30] = 12'h000;
        image_array[15][31] = 12'h000;
    
        //  16
        image_array[16][0] = 12'h000;
        image_array[16][1] = 12'h000;
        image_array[16][2] = 12'h000;
        image_array[16][3] = 12'h000;
        image_array[16][4] = 12'h000;
        image_array[16][5] = 12'h000;
        image_array[16][6] = 12'h000;
        image_array[16][7] = 12'h000;
        image_array[16][8] = 12'h000;
        image_array[16][9] = 12'h031;
        image_array[16][10] = 12'h052;
        image_array[16][11] = 12'h073;
        image_array[16][12] = 12'hE12;
        image_array[16][13] = 12'h073;
        image_array[16][14] = 12'h073;
        image_array[16][15] = 12'hFF0;
        image_array[16][16] = 12'h063;
        image_array[16][17] = 12'h073;
        image_array[16][18] = 12'h073;
        image_array[16][19] = 12'hE12;
        image_array[16][20] = 12'h073;
        image_array[16][21] = 12'h052;
        image_array[16][22] = 12'h031;
        image_array[16][23] = 12'h000;
        image_array[16][24] = 12'h000;
        image_array[16][25] = 12'h000;
        image_array[16][26] = 12'h000;
        image_array[16][27] = 12'h000;
        image_array[16][28] = 12'h000;
        image_array[16][29] = 12'h000;
        image_array[16][30] = 12'h000;
        image_array[16][31] = 12'h000;
    
        //  17
        image_array[17][0] = 12'h000;
        image_array[17][1] = 12'h000;
        image_array[17][2] = 12'h000;
        image_array[17][3] = 12'h000;
        image_array[17][4] = 12'h000;
        image_array[17][5] = 12'h000;
        image_array[17][6] = 12'h000;
        image_array[17][7] = 12'h000;
        image_array[17][8] = 12'h000;
        image_array[17][9] = 12'h000;
        image_array[17][10] = 12'h000;
        image_array[17][11] = 12'h000;
        image_array[17][12] = 12'h000;
        image_array[17][13] = 12'h000;
        image_array[17][14] = 12'h010;
        image_array[17][15] = 12'h011;
        image_array[17][16] = 12'h011;
        image_array[17][17] = 12'h010;
        image_array[17][18] = 12'h000;
        image_array[17][19] = 12'h000;
        image_array[17][20] = 12'h000;
        image_array[17][21] = 12'h000;
        image_array[17][22] = 12'h000;
        image_array[17][23] = 12'h000;
        image_array[17][24] = 12'h000;
        image_array[17][25] = 12'h000;
        image_array[17][26] = 12'h000;
        image_array[17][27] = 12'h000;
        image_array[17][28] = 12'h000;
        image_array[17][29] = 12'h000;
        image_array[17][30] = 12'h000;
        image_array[17][31] = 12'h000;
    
        //  18
        image_array[18][0] = 12'h000;
        image_array[18][1] = 12'h000;
        image_array[18][2] = 12'h000;
        image_array[18][3] = 12'h000;
        image_array[18][4] = 12'h000;
        image_array[18][5] = 12'h000;
        image_array[18][6] = 12'h000;
        image_array[18][7] = 12'h000;
        image_array[18][8] = 12'h000;
        image_array[18][9] = 12'h000;
        image_array[18][10] = 12'h053;
        image_array[18][11] = 12'h073;
        image_array[18][12] = 12'h063;
        image_array[18][13] = 12'h052;
        image_array[18][14] = 12'h042;
        image_array[18][15] = 12'h042;
        image_array[18][16] = 12'h042;
        image_array[18][17] = 12'h042;
        image_array[18][18] = 12'h052;
        image_array[18][19] = 12'h063;
        image_array[18][20] = 12'h073;
        image_array[18][21] = 12'h053;
        image_array[18][22] = 12'h000;
        image_array[18][23] = 12'h000;
        image_array[18][24] = 12'h000;
        image_array[18][25] = 12'h000;
        image_array[18][26] = 12'h000;
        image_array[18][27] = 12'h000;
        image_array[18][28] = 12'h000;
        image_array[18][29] = 12'h000;
        image_array[18][30] = 12'h000;
        image_array[18][31] = 12'h000;
    
        //  19
        image_array[19][0] = 12'h000;
        image_array[19][1] = 12'h000;
        image_array[19][2] = 12'h000;
        image_array[19][3] = 12'h000;
        image_array[19][4] = 12'h000;
        image_array[19][5] = 12'h000;
        image_array[19][6] = 12'h000;
        image_array[19][7] = 12'h000;
        image_array[19][8] = 12'h031;
        image_array[19][9] = 12'h073;
        image_array[19][10] = 12'h063;
        image_array[19][11] = 12'h063;
        image_array[19][12] = 12'h063;
        image_array[19][13] = 12'h063;
        image_array[19][14] = 12'h063;
        image_array[19][15] = 12'h063;
        image_array[19][16] = 12'h063;
        image_array[19][17] = 12'h063;
        image_array[19][18] = 12'h063;
        image_array[19][19] = 12'h063;
        image_array[19][20] = 12'h063;
        image_array[19][21] = 12'h063;
        image_array[19][22] = 12'h073;
        image_array[19][23] = 12'h031;
        image_array[19][24] = 12'h000;
        image_array[19][25] = 12'h000;
        image_array[19][26] = 12'h000;
        image_array[19][27] = 12'h000;
        image_array[19][28] = 12'h000;
        image_array[19][29] = 12'h000;
        image_array[19][30] = 12'h000;
        image_array[19][31] = 12'h000;
    
        //  20
        image_array[20][0] = 12'h000;
        image_array[20][1] = 12'h000;
        image_array[20][2] = 12'h000;
        image_array[20][3] = 12'h000;
        image_array[20][4] = 12'h000;
        image_array[20][5] = 12'h000;
        image_array[20][6] = 12'h021;
        image_array[20][7] = 12'h063;
        image_array[20][8] = 12'h073;
        image_array[20][9] = 12'h063;
        image_array[20][10] = 12'h063;
        image_array[20][11] = 12'h063;
        image_array[20][12] = 12'h063;
        image_array[20][13] = 12'h063;
        image_array[20][14] = 12'h063;
        image_array[20][15] = 12'h063;
        image_array[20][16] = 12'h063;
        image_array[20][17] = 12'h063;
        image_array[20][18] = 12'h063;
        image_array[20][19] = 12'h063;
        image_array[20][20] = 12'h063;
        image_array[20][21] = 12'h063;
        image_array[20][22] = 12'h063;
        image_array[20][23] = 12'h073;
        image_array[20][24] = 12'h063;
        image_array[20][25] = 12'h021;
        image_array[20][26] = 12'h000;
        image_array[20][27] = 12'h000;
        image_array[20][28] = 12'h000;
        image_array[20][29] = 12'h000;
        image_array[20][30] = 12'h000;
        image_array[20][31] = 12'h000;
    
        //  21
        image_array[21][0] = 12'h000;
        image_array[21][1] = 12'h000;
        image_array[21][2] = 12'h000;
        image_array[21][3] = 12'h000;
        image_array[21][4] = 12'h042;
        image_array[21][5] = 12'h063;
        image_array[21][6] = 12'h073;
        image_array[21][7] = 12'h063;
        image_array[21][8] = 12'h063;
        image_array[21][9] = 12'h063;
        image_array[21][10] = 12'h063;
        image_array[21][11] = 12'h063;
        image_array[21][12] = 12'h063;
        image_array[21][13] = 12'h063;
        image_array[21][14] = 12'h063;
        image_array[21][15] = 12'h063;
        image_array[21][16] = 12'h063;
        image_array[21][17] = 12'h063;
        image_array[21][18] = 12'h063;
        image_array[21][19] = 12'h063;
        image_array[21][20] = 12'h063;
        image_array[21][21] = 12'h063;
        image_array[21][22] = 12'h063;
        image_array[21][23] = 12'h063;
        image_array[21][24] = 12'h063;
        image_array[21][25] = 12'h073;
        image_array[21][26] = 12'h063;
        image_array[21][27] = 12'h042;
        image_array[21][28] = 12'h000;
        image_array[21][29] = 12'h000;
        image_array[21][30] = 12'h000;
        image_array[21][31] = 12'h000;
    
        //  22
        image_array[22][0] = 12'h000;
        image_array[22][1] = 12'h000;
        image_array[22][2] = 12'h000;
        image_array[22][3] = 12'h000;
        image_array[22][4] = 12'h031;
        image_array[22][5] = 12'h073;
        image_array[22][6] = 12'h063;
        image_array[22][7] = 12'hE12;
        image_array[22][8] = 12'h063;
        image_array[22][9] = 12'h063;
        image_array[22][10] = 12'h063;
        image_array[22][11] = 12'h063;
        image_array[22][12] = 12'h063;
        image_array[22][13] = 12'h063;
        image_array[22][14] = 12'h063;
        image_array[22][15] = 12'h063;
        image_array[22][16] = 12'h063;
        image_array[22][17] = 12'h063;
        image_array[22][18] = 12'h063;
        image_array[22][19] = 12'h063;
        image_array[22][20] = 12'h063;
        image_array[22][21] = 12'h063;
        image_array[22][22] = 12'h063;
        image_array[22][23] = 12'h063;
        image_array[22][24] = 12'hE12;
        image_array[22][25] = 12'h063;
        image_array[22][26] = 12'h073;
        image_array[22][27] = 12'h031;
        image_array[22][28] = 12'h000;
        image_array[22][29] = 12'h000;
        image_array[22][30] = 12'h000;
        image_array[22][31] = 12'h000;
    
        //  23
        image_array[23][0] = 12'h000;
        image_array[23][1] = 12'h000;
        image_array[23][2] = 12'h000;
        image_array[23][3] = 12'h000;
        image_array[23][4] = 12'h000;
        image_array[23][5] = 12'h000;
        image_array[23][6] = 12'h021;
        image_array[23][7] = 12'h052;
        image_array[23][8] = 12'h073;
        image_array[23][9] = 12'h073;
        image_array[23][10] = 12'h073;
        image_array[23][11] = 12'hFF0;
        image_array[23][12] = 12'h063;
        image_array[23][13] = 12'h063;
        image_array[23][14] = 12'h063;
        image_array[23][15] = 12'hE12;
        image_array[23][16] = 12'h063;
        image_array[23][17] = 12'h063;
        image_array[23][18] = 12'h063;
        image_array[23][19] = 12'hFF0;
        image_array[23][20] = 12'h063;
        image_array[23][21] = 12'h073;
        image_array[23][22] = 12'h073;
        image_array[23][23] = 12'h073;
        image_array[23][24] = 12'h052;
        image_array[23][25] = 12'h031;
        image_array[23][26] = 12'h000;
        image_array[23][27] = 12'h000;
        image_array[23][28] = 12'h000;
        image_array[23][29] = 12'h000;
        image_array[23][30] = 12'h000;
        image_array[23][31] = 12'h000;
    
        //  24
        image_array[24][0] = 12'h000;
        image_array[24][1] = 12'h000;
        image_array[24][2] = 12'h000;
        image_array[24][3] = 12'h000;
        image_array[24][4] = 12'h000;
        image_array[24][5] = 12'h000;
        image_array[24][6] = 12'h000;
        image_array[24][7] = 12'h000;
        image_array[24][8] = 12'h000;
        image_array[24][9] = 12'h000;
        image_array[24][10] = 12'h011;
        image_array[24][11] = 12'h021;
        image_array[24][12] = 12'h032;
        image_array[24][13] = 12'h042;
        image_array[24][14] = 12'h042;
        image_array[24][15] = 12'h042;
        image_array[24][16] = 12'h042;
        image_array[24][17] = 12'h042;
        image_array[24][18] = 12'h042;
        image_array[24][19] = 12'h032;
        image_array[24][20] = 12'h031;
        image_array[24][21] = 12'h011;
        image_array[24][22] = 12'h000;
        image_array[24][23] = 12'h000;
        image_array[24][24] = 12'h000;
        image_array[24][25] = 12'h000;
        image_array[24][26] = 12'h000;
        image_array[24][27] = 12'h000;
        image_array[24][28] = 12'h000;
        image_array[24][29] = 12'h000;
        image_array[24][30] = 12'h000;
        image_array[24][31] = 12'h000;
    
        //  25
        image_array[25][0] = 12'h000;
        image_array[25][1] = 12'h000;
        image_array[25][2] = 12'h000;
        image_array[25][3] = 12'h000;
        image_array[25][4] = 12'h000;
        image_array[25][5] = 12'h000;
        image_array[25][6] = 12'h000;
        image_array[25][7] = 12'h000;
        image_array[25][8] = 12'h000;
        image_array[25][9] = 12'h000;
        image_array[25][10] = 12'h000;
        image_array[25][11] = 12'h000;
        image_array[25][12] = 12'h000;
        image_array[25][13] = 12'h000;
        image_array[25][14] = 12'h100;
        image_array[25][15] = 12'h321;
        image_array[25][16] = 12'h321;
        image_array[25][17] = 12'h100;
        image_array[25][18] = 12'h000;
        image_array[25][19] = 12'h000;
        image_array[25][20] = 12'h000;
        image_array[25][21] = 12'h000;
        image_array[25][22] = 12'h000;
        image_array[25][23] = 12'h000;
        image_array[25][24] = 12'h000;
        image_array[25][25] = 12'h000;
        image_array[25][26] = 12'h000;
        image_array[25][27] = 12'h000;
        image_array[25][28] = 12'h000;
        image_array[25][29] = 12'h000;
        image_array[25][30] = 12'h000;
        image_array[25][31] = 12'h000;
    
        //  26
        image_array[26][0] = 12'h000;
        image_array[26][1] = 12'h000;
        image_array[26][2] = 12'h000;
        image_array[26][3] = 12'h000;
        image_array[26][4] = 12'h000;
        image_array[26][5] = 12'h000;
        image_array[26][6] = 12'h000;
        image_array[26][7] = 12'h000;
        image_array[26][8] = 12'h000;
        image_array[26][9] = 12'h000;
        image_array[26][10] = 12'h000;
        image_array[26][11] = 12'h000;
        image_array[26][12] = 12'h000;
        image_array[26][13] = 12'h000;
        image_array[26][14] = 12'h532;
        image_array[26][15] = 12'hEA6;
        image_array[26][16] = 12'hEA6;
        image_array[26][17] = 12'h532;
        image_array[26][18] = 12'h000;
        image_array[26][19] = 12'h000;
        image_array[26][20] = 12'h000;
        image_array[26][21] = 12'h000;
        image_array[26][22] = 12'h000;
        image_array[26][23] = 12'h000;
        image_array[26][24] = 12'h000;
        image_array[26][25] = 12'h000;
        image_array[26][26] = 12'h000;
        image_array[26][27] = 12'h000;
        image_array[26][28] = 12'h000;
        image_array[26][29] = 12'h000;
        image_array[26][30] = 12'h000;
        image_array[26][31] = 12'h000;
    
        //  27
        image_array[27][0] = 12'h000;
        image_array[27][1] = 12'h000;
        image_array[27][2] = 12'h000;
        image_array[27][3] = 12'h000;
        image_array[27][4] = 12'h000;
        image_array[27][5] = 12'h000;
        image_array[27][6] = 12'h000;
        image_array[27][7] = 12'h000;
        image_array[27][8] = 12'h000;
        image_array[27][9] = 12'h000;
        image_array[27][10] = 12'h000;
        image_array[27][11] = 12'h000;
        image_array[27][12] = 12'h000;
        image_array[27][13] = 12'h000;
        image_array[27][14] = 12'h432;
        image_array[27][15] = 12'hD95;
        image_array[27][16] = 12'hD95;
        image_array[27][17] = 12'h432;
        image_array[27][18] = 12'h000;
        image_array[27][19] = 12'h000;
        image_array[27][20] = 12'h000;
        image_array[27][21] = 12'h000;
        image_array[27][22] = 12'h000;
        image_array[27][23] = 12'h000;
        image_array[27][24] = 12'h000;
        image_array[27][25] = 12'h000;
        image_array[27][26] = 12'h000;
        image_array[27][27] = 12'h000;
        image_array[27][28] = 12'h000;
        image_array[27][29] = 12'h000;
        image_array[27][30] = 12'h000;
        image_array[27][31] = 12'h000;
    
        //  28
        image_array[28][0] = 12'h000;
        image_array[28][1] = 12'h000;
        image_array[28][2] = 12'h000;
        image_array[28][3] = 12'h000;
        image_array[28][4] = 12'h000;
        image_array[28][5] = 12'h000;
        image_array[28][6] = 12'h000;
        image_array[28][7] = 12'h000;
        image_array[28][8] = 12'h000;
        image_array[28][9] = 12'h000;
        image_array[28][10] = 12'h000;
        image_array[28][11] = 12'h000;
        image_array[28][12] = 12'h000;
        image_array[28][13] = 12'h000;
        image_array[28][14] = 12'h432;
        image_array[28][15] = 12'hD95;
        image_array[28][16] = 12'hD95;
        image_array[28][17] = 12'h432;
        image_array[28][18] = 12'h000;
        image_array[28][19] = 12'h000;
        image_array[28][20] = 12'h000;
        image_array[28][21] = 12'h000;
        image_array[28][22] = 12'h000;
        image_array[28][23] = 12'h000;
        image_array[28][24] = 12'h000;
        image_array[28][25] = 12'h000;
        image_array[28][26] = 12'h000;
        image_array[28][27] = 12'h000;
        image_array[28][28] = 12'h000;
        image_array[28][29] = 12'h000;
        image_array[28][30] = 12'h000;
        image_array[28][31] = 12'h000;
    
        //  29
        image_array[29][0] = 12'h000;
        image_array[29][1] = 12'h000;
        image_array[29][2] = 12'h000;
        image_array[29][3] = 12'h000;
        image_array[29][4] = 12'h000;
        image_array[29][5] = 12'h000;
        image_array[29][6] = 12'h000;
        image_array[29][7] = 12'h000;
        image_array[29][8] = 12'h000;
        image_array[29][9] = 12'h000;
        image_array[29][10] = 12'h000;
        image_array[29][11] = 12'h000;
        image_array[29][12] = 12'h000;
        image_array[29][13] = 12'h000;
        image_array[29][14] = 12'h432;
        image_array[29][15] = 12'hDA5;
        image_array[29][16] = 12'hDA5;
        image_array[29][17] = 12'h432;
        image_array[29][18] = 12'h000;
        image_array[29][19] = 12'h000;
        image_array[29][20] = 12'h000;
        image_array[29][21] = 12'h000;
        image_array[29][22] = 12'h000;
        image_array[29][23] = 12'h000;
        image_array[29][24] = 12'h000;
        image_array[29][25] = 12'h000;
        image_array[29][26] = 12'h000;
        image_array[29][27] = 12'h000;
        image_array[29][28] = 12'h000;
        image_array[29][29] = 12'h000;
        image_array[29][30] = 12'h000;
        image_array[29][31] = 12'h000;
    
        //  30
        image_array[30][0] = 12'h000;
        image_array[30][1] = 12'h000;
        image_array[30][2] = 12'h000;
        image_array[30][3] = 12'h000;
        image_array[30][4] = 12'h000;
        image_array[30][5] = 12'h000;
        image_array[30][6] = 12'h000;
        image_array[30][7] = 12'h000;
        image_array[30][8] = 12'h000;
        image_array[30][9] = 12'h000;
        image_array[30][10] = 12'h000;
        image_array[30][11] = 12'h000;
        image_array[30][12] = 12'h000;
        image_array[30][13] = 12'h000;
        image_array[30][14] = 12'h321;
        image_array[30][15] = 12'h863;
        image_array[30][16] = 12'h863;
        image_array[30][17] = 12'h321;
        image_array[30][18] = 12'h000;
        image_array[30][19] = 12'h000;
        image_array[30][20] = 12'h000;
        image_array[30][21] = 12'h000;
        image_array[30][22] = 12'h000;
        image_array[30][23] = 12'h000;
        image_array[30][24] = 12'h000;
        image_array[30][25] = 12'h000;
        image_array[30][26] = 12'h000;
        image_array[30][27] = 12'h000;
        image_array[30][28] = 12'h000;
        image_array[30][29] = 12'h000;
        image_array[30][30] = 12'h000;
        image_array[30][31] = 12'h000;
    
        //  31
        image_array[31][0] = 12'h000;
        image_array[31][1] = 12'h000;
        image_array[31][2] = 12'h000;
        image_array[31][3] = 12'h000;
        image_array[31][4] = 12'h000;
        image_array[31][5] = 12'h000;
        image_array[31][6] = 12'h000;
        image_array[31][7] = 12'h000;
        image_array[31][8] = 12'h000;
        image_array[31][9] = 12'h000;
        image_array[31][10] = 12'h000;
        image_array[31][11] = 12'h000;
        image_array[31][12] = 12'h000;
        image_array[31][13] = 12'h000;
        image_array[31][14] = 12'h000;
        image_array[31][15] = 12'h000;
        image_array[31][16] = 12'h000;
        image_array[31][17] = 12'h000;
        image_array[31][18] = 12'h000;
        image_array[31][19] = 12'h000;
        image_array[31][20] = 12'h000;
        image_array[31][21] = 12'h000;
        image_array[31][22] = 12'h000;
        image_array[31][23] = 12'h000;
        image_array[31][24] = 12'h000;
        image_array[31][25] = 12'h000;
        image_array[31][26] = 12'h000;
        image_array[31][27] = 12'h000;
        image_array[31][28] = 12'h000;
        image_array[31][29] = 12'h000;
        image_array[31][30] = 12'h000;
        image_array[31][31] = 12'h000;
    end

end else if(NEW_YEAR == 1) begin
    
    initial begin
         //  0
        image_array[0][0] = 12'h000;
        image_array[0][1] = 12'h000;
        image_array[0][2] = 12'h000;
        image_array[0][3] = 12'h000;
        image_array[0][4] = 12'h000;
        image_array[0][5] = 12'h000;
        image_array[0][6] = 12'h000;
        image_array[0][7] = 12'h000;
        image_array[0][8] = 12'h000;
        image_array[0][9] = 12'h000;
        image_array[0][10] = 12'h000;
        image_array[0][11] = 12'h000;
        image_array[0][12] = 12'h000;
        image_array[0][13] = 12'h000;
        image_array[0][14] = 12'h000;
        image_array[0][15] = 12'h000;
        image_array[0][16] = 12'h000;
        image_array[0][17] = 12'h000;
        image_array[0][18] = 12'h000;
        image_array[0][19] = 12'h000;
        image_array[0][20] = 12'h000;
        image_array[0][21] = 12'h000;
        image_array[0][22] = 12'h000;
        image_array[0][23] = 12'h000;
        image_array[0][24] = 12'h000;
        image_array[0][25] = 12'h000;
        image_array[0][26] = 12'h000;
        image_array[0][27] = 12'h000;
        image_array[0][28] = 12'h000;
        image_array[0][29] = 12'h000;
        image_array[0][30] = 12'h000;
        image_array[0][31] = 12'h000;
    
        //  1
        image_array[1][0] = 12'h000;
        image_array[1][1] = 12'h000;
        image_array[1][2] = 12'h000;
        image_array[1][3] = 12'h000;
        image_array[1][4] = 12'h000;
        image_array[1][5] = 12'h000;
        image_array[1][6] = 12'h000;
        image_array[1][7] = 12'h000;
        image_array[1][8] = 12'h000;
        image_array[1][9] = 12'h000;
        image_array[1][10] = 12'h000;
        image_array[1][11] = 12'h000;
        image_array[1][12] = 12'h000;
        image_array[1][13] = 12'h000;
        image_array[1][14] = 12'h000;
        image_array[1][15] = 12'h000;
        image_array[1][16] = 12'h000;
        image_array[1][17] = 12'h000;
        image_array[1][18] = 12'h000;
        image_array[1][19] = 12'h000;
        image_array[1][20] = 12'h000;
        image_array[1][21] = 12'h000;
        image_array[1][22] = 12'h000;
        image_array[1][23] = 12'h000;
        image_array[1][24] = 12'h000;
        image_array[1][25] = 12'h000;
        image_array[1][26] = 12'h000;
        image_array[1][27] = 12'h000;
        image_array[1][28] = 12'h000;
        image_array[1][29] = 12'h000;
        image_array[1][30] = 12'h000;
        image_array[1][31] = 12'h000;
    
        //  2
        image_array[2][0] = 12'h000;
        image_array[2][1] = 12'h000;
        image_array[2][2] = 12'h000;
        image_array[2][3] = 12'h000;
        image_array[2][4] = 12'h000;
        image_array[2][5] = 12'h000;
        image_array[2][6] = 12'h000;
        image_array[2][7] = 12'h000;
        image_array[2][8] = 12'h000;
        image_array[2][9] = 12'h000;
        image_array[2][10] = 12'h000;
        image_array[2][11] = 12'h000;
        image_array[2][12] = 12'h000;
        image_array[2][13] = 12'h000;
        image_array[2][14] = 12'h000;
        image_array[2][15] = 12'h000;
        image_array[2][16] = 12'h000;
        image_array[2][17] = 12'h000;
        image_array[2][18] = 12'h000;
        image_array[2][19] = 12'h000;
        image_array[2][20] = 12'h000;
        image_array[2][21] = 12'h000;
        image_array[2][22] = 12'h000;
        image_array[2][23] = 12'h000;
        image_array[2][24] = 12'h000;
        image_array[2][25] = 12'h000;
        image_array[2][26] = 12'h000;
        image_array[2][27] = 12'h000;
        image_array[2][28] = 12'h000;
        image_array[2][29] = 12'h000;
        image_array[2][30] = 12'h000;
        image_array[2][31] = 12'h000;
    
        //  3
        image_array[3][0] = 12'h000;
        image_array[3][1] = 12'h000;
        image_array[3][2] = 12'h000;
        image_array[3][3] = 12'h000;
        image_array[3][4] = 12'h000;
        image_array[3][5] = 12'h000;
        image_array[3][6] = 12'h000;
        image_array[3][7] = 12'h000;
        image_array[3][8] = 12'h000;
        image_array[3][9] = 12'h000;
        image_array[3][10] = 12'h000;
        image_array[3][11] = 12'h000;
        image_array[3][12] = 12'h000;
        image_array[3][13] = 12'h000;
        image_array[3][14] = 12'h000;
        image_array[3][15] = 12'h000;
        image_array[3][16] = 12'h000;
        image_array[3][17] = 12'h000;
        image_array[3][18] = 12'h000;
        image_array[3][19] = 12'h000;
        image_array[3][20] = 12'h000;
        image_array[3][21] = 12'h000;
        image_array[3][22] = 12'h000;
        image_array[3][23] = 12'h000;
        image_array[3][24] = 12'h000;
        image_array[3][25] = 12'h000;
        image_array[3][26] = 12'h000;
        image_array[3][27] = 12'h000;
        image_array[3][28] = 12'h000;
        image_array[3][29] = 12'h000;
        image_array[3][30] = 12'h000;
        image_array[3][31] = 12'h000;
    
        //  4
        image_array[4][0] = 12'h000;
        image_array[4][1] = 12'h000;
        image_array[4][2] = 12'h000;
        image_array[4][3] = 12'h000;
        image_array[4][4] = 12'h000;
        image_array[4][5] = 12'h000;
        image_array[4][6] = 12'h000;
        image_array[4][7] = 12'h000;
        image_array[4][8] = 12'h000;
        image_array[4][9] = 12'h000;
        image_array[4][10] = 12'h000;
        image_array[4][11] = 12'h000;
        image_array[4][12] = 12'h000;
        image_array[4][13] = 12'h000;
        image_array[4][14] = 12'h000;
        image_array[4][15] = 12'h063;
        image_array[4][16] = 12'h063;
        image_array[4][17] = 12'h000;
        image_array[4][18] = 12'h000;
        image_array[4][19] = 12'h000;
        image_array[4][20] = 12'h000;
        image_array[4][21] = 12'h000;
        image_array[4][22] = 12'h000;
        image_array[4][23] = 12'h000;
        image_array[4][24] = 12'h000;
        image_array[4][25] = 12'h000;
        image_array[4][26] = 12'h000;
        image_array[4][27] = 12'h000;
        image_array[4][28] = 12'h000;
        image_array[4][29] = 12'h000;
        image_array[4][30] = 12'h000;
        image_array[4][31] = 12'h000;
    
        //  5
        image_array[5][0] = 12'h000;
        image_array[5][1] = 12'h000;
        image_array[5][2] = 12'h000;
        image_array[5][3] = 12'h000;
        image_array[5][4] = 12'h000;
        image_array[5][5] = 12'h000;
        image_array[5][6] = 12'h000;
        image_array[5][7] = 12'h000;
        image_array[5][8] = 12'h000;
        image_array[5][9] = 12'h000;
        image_array[5][10] = 12'h000;
        image_array[5][11] = 12'h000;
        image_array[5][12] = 12'h000;
        image_array[5][13] = 12'h000;
        image_array[5][14] = 12'h042;
        image_array[5][15] = 12'h063;
        image_array[5][16] = 12'h063;
        image_array[5][17] = 12'h042;
        image_array[5][18] = 12'h000;
        image_array[5][19] = 12'h000;
        image_array[5][20] = 12'h000;
        image_array[5][21] = 12'h000;
        image_array[5][22] = 12'h000;
        image_array[5][23] = 12'h000;
        image_array[5][24] = 12'h000;
        image_array[5][25] = 12'h000;
        image_array[5][26] = 12'h000;
        image_array[5][27] = 12'h000;
        image_array[5][28] = 12'h000;
        image_array[5][29] = 12'h000;
        image_array[5][30] = 12'h000;
        image_array[5][31] = 12'h000;
    
        //  6
        image_array[6][0] = 12'h000;
        image_array[6][1] = 12'h000;
        image_array[6][2] = 12'h000;
        image_array[6][3] = 12'h000;
        image_array[6][4] = 12'h000;
        image_array[6][5] = 12'h000;
        image_array[6][6] = 12'h000;
        image_array[6][7] = 12'h000;
        image_array[6][8] = 12'h000;
        image_array[6][9] = 12'h000;
        image_array[6][10] = 12'h000;
        image_array[6][11] = 12'h000;
        image_array[6][12] = 12'h000;
        image_array[6][13] = 12'h031;
        image_array[6][14] = 12'h073;
        image_array[6][15] = 12'h063;
        image_array[6][16] = 12'h063;
        image_array[6][17] = 12'h073;
        image_array[6][18] = 12'h031;
        image_array[6][19] = 12'h000;
        image_array[6][20] = 12'h000;
        image_array[6][21] = 12'h000;
        image_array[6][22] = 12'h000;
        image_array[6][23] = 12'h000;
        image_array[6][24] = 12'h000;
        image_array[6][25] = 12'h000;
        image_array[6][26] = 12'h000;
        image_array[6][27] = 12'h000;
        image_array[6][28] = 12'h000;
        image_array[6][29] = 12'h000;
        image_array[6][30] = 12'h000;
        image_array[6][31] = 12'h000;
    
        //  7
        image_array[7][0] = 12'h000;
        image_array[7][1] = 12'h000;
        image_array[7][2] = 12'h000;
        image_array[7][3] = 12'h000;
        image_array[7][4] = 12'h000;
        image_array[7][5] = 12'h000;
        image_array[7][6] = 12'h000;
        image_array[7][7] = 12'h000;
        image_array[7][8] = 12'h000;
        image_array[7][9] = 12'h000;
        image_array[7][10] = 12'h000;
        image_array[7][11] = 12'h000;
        image_array[7][12] = 12'h042;
        image_array[7][13] = 12'h073;
        image_array[7][14] = 12'h063;
        image_array[7][15] = 12'h063;
        image_array[7][16] = 12'h063;
        image_array[7][17] = 12'h063;
        image_array[7][18] = 12'h073;
        image_array[7][19] = 12'h042;
        image_array[7][20] = 12'h000;
        image_array[7][21] = 12'h000;
        image_array[7][22] = 12'h000;
        image_array[7][23] = 12'h000;
        image_array[7][24] = 12'h000;
        image_array[7][25] = 12'h000;
        image_array[7][26] = 12'h000;
        image_array[7][27] = 12'h000;
        image_array[7][28] = 12'h000;
        image_array[7][29] = 12'h000;
        image_array[7][30] = 12'h000;
        image_array[7][31] = 12'h000;
    
        //  8
        image_array[8][0] = 12'h000;
        image_array[8][1] = 12'h000;
        image_array[8][2] = 12'h000;
        image_array[8][3] = 12'h000;
        image_array[8][4] = 12'h000;
        image_array[8][5] = 12'h000;
        image_array[8][6] = 12'h000;
        image_array[8][7] = 12'h000;
        image_array[8][8] = 12'h000;
        image_array[8][9] = 12'h000;
        image_array[8][10] = 12'h000;
        image_array[8][11] = 12'h063;
        image_array[8][12] = 12'h063;
        image_array[8][13] = 12'h063;
        image_array[8][14] = 12'h063;
        image_array[8][15] = 12'h063;
        image_array[8][16] = 12'h063;
        image_array[8][17] = 12'h063;
        image_array[8][18] = 12'h063;
        image_array[8][19] = 12'h063;
        image_array[8][20] = 12'h063;
        image_array[8][21] = 12'h000;
        image_array[8][22] = 12'h000;
        image_array[8][23] = 12'h000;
        image_array[8][24] = 12'h000;
        image_array[8][25] = 12'h000;
        image_array[8][26] = 12'h000;
        image_array[8][27] = 12'h000;
        image_array[8][28] = 12'h000;
        image_array[8][29] = 12'h000;
        image_array[8][30] = 12'h000;
        image_array[8][31] = 12'h000;
    
        //  9
        image_array[9][0] = 12'h000;
        image_array[9][1] = 12'h000;
        image_array[9][2] = 12'h000;
        image_array[9][3] = 12'h000;
        image_array[9][4] = 12'h000;
        image_array[9][5] = 12'h000;
        image_array[9][6] = 12'h000;
        image_array[9][7] = 12'h000;
        image_array[9][8] = 12'h000;
        image_array[9][9] = 12'h010;
        image_array[9][10] = 12'h084;
        image_array[9][11] = 12'h073;
        image_array[9][12] = 12'h063;
        image_array[9][13] = 12'h063;
        image_array[9][14] = 12'h063;
        image_array[9][15] = 12'h063;
        image_array[9][16] = 12'h063;
        image_array[9][17] = 12'h063;
        image_array[9][18] = 12'h063;
        image_array[9][19] = 12'h063;
        image_array[9][20] = 12'h073;
        image_array[9][21] = 12'h084;
        image_array[9][22] = 12'h010;
        image_array[9][23] = 12'h000;
        image_array[9][24] = 12'h000;
        image_array[9][25] = 12'h000;
        image_array[9][26] = 12'h000;
        image_array[9][27] = 12'h000;
        image_array[9][28] = 12'h000;
        image_array[9][29] = 12'h000;
        image_array[9][30] = 12'h000;
        image_array[9][31] = 12'h000;
    
        //  10
        image_array[10][0] = 12'h000;
        image_array[10][1] = 12'h000;
        image_array[10][2] = 12'h000;
        image_array[10][3] = 12'h000;
        image_array[10][4] = 12'h000;
        image_array[10][5] = 12'h000;
        image_array[10][6] = 12'h000;
        image_array[10][7] = 12'h000;
        image_array[10][8] = 12'h000;
        image_array[10][9] = 12'h000;
        image_array[10][10] = 12'h000;
        image_array[10][11] = 12'h032;
        image_array[10][12] = 12'h063;
        image_array[10][13] = 12'h073;
        image_array[10][14] = 12'h073;
        image_array[10][15] = 12'h073;
        image_array[10][16] = 12'h073;
        image_array[10][17] = 12'h073;
        image_array[10][18] = 12'h073;
        image_array[10][19] = 12'h063;
        image_array[10][20] = 12'h032;
        image_array[10][21] = 12'h000;
        image_array[10][22] = 12'h000;
        image_array[10][23] = 12'h000;
        image_array[10][24] = 12'h000;
        image_array[10][25] = 12'h000;
        image_array[10][26] = 12'h000;
        image_array[10][27] = 12'h000;
        image_array[10][28] = 12'h000;
        image_array[10][29] = 12'h000;
        image_array[10][30] = 12'h000;
        image_array[10][31] = 12'h000;
    
        //  11
        image_array[11][0] = 12'h000;
        image_array[11][1] = 12'h000;
        image_array[11][2] = 12'h000;
        image_array[11][3] = 12'h000;
        image_array[11][4] = 12'h000;
        image_array[11][5] = 12'h000;
        image_array[11][6] = 12'h000;
        image_array[11][7] = 12'h000;
        image_array[11][8] = 12'h000;
        image_array[11][9] = 12'h000;
        image_array[11][10] = 12'h000;
        image_array[11][11] = 12'h000;
        image_array[11][12] = 12'h000;
        image_array[11][13] = 12'h000;
        image_array[11][14] = 12'h000;
        image_array[11][15] = 12'h000;
        image_array[11][16] = 12'h000;
        image_array[11][17] = 12'h000;
        image_array[11][18] = 12'h000;
        image_array[11][19] = 12'h000;
        image_array[11][20] = 12'h000;
        image_array[11][21] = 12'h000;
        image_array[11][22] = 12'h000;
        image_array[11][23] = 12'h000;
        image_array[11][24] = 12'h000;
        image_array[11][25] = 12'h000;
        image_array[11][26] = 12'h000;
        image_array[11][27] = 12'h000;
        image_array[11][28] = 12'h000;
        image_array[11][29] = 12'h000;
        image_array[11][30] = 12'h000;
        image_array[11][31] = 12'h000;
    
        //  12
        image_array[12][0] = 12'h000;
        image_array[12][1] = 12'h000;
        image_array[12][2] = 12'h000;
        image_array[12][3] = 12'h000;
        image_array[12][4] = 12'h000;
        image_array[12][5] = 12'h000;
        image_array[12][6] = 12'h000;
        image_array[12][7] = 12'h000;
        image_array[12][8] = 12'h000;
        image_array[12][9] = 12'h000;
        image_array[12][10] = 12'h000;
        image_array[12][11] = 12'h032;
        image_array[12][12] = 12'h073;
        image_array[12][13] = 12'h063;
        image_array[12][14] = 12'h063;
        image_array[12][15] = 12'h052;
        image_array[12][16] = 12'h052;
        image_array[12][17] = 12'h063;
        image_array[12][18] = 12'h063;
        image_array[12][19] = 12'h073;
        image_array[12][20] = 12'h032;
        image_array[12][21] = 12'h000;
        image_array[12][22] = 12'h000;
        image_array[12][23] = 12'h000;
        image_array[12][24] = 12'h000;
        image_array[12][25] = 12'h000;
        image_array[12][26] = 12'h000;
        image_array[12][27] = 12'h000;
        image_array[12][28] = 12'h000;
        image_array[12][29] = 12'h000;
        image_array[12][30] = 12'h000;
        image_array[12][31] = 12'h000;
    
        //  13
        image_array[13][0] = 12'h000;
        image_array[13][1] = 12'h000;
        image_array[13][2] = 12'h000;
        image_array[13][3] = 12'h000;
        image_array[13][4] = 12'h000;
        image_array[13][5] = 12'h000;
        image_array[13][6] = 12'h000;
        image_array[13][7] = 12'h000;
        image_array[13][8] = 12'h000;
        image_array[13][9] = 12'h000;
        image_array[13][10] = 12'h063;
        image_array[13][11] = 12'h073;
        image_array[13][12] = 12'h063;
        image_array[13][13] = 12'h063;
        image_array[13][14] = 12'h063;
        image_array[13][15] = 12'h063;
        image_array[13][16] = 12'h063;
        image_array[13][17] = 12'h063;
        image_array[13][18] = 12'h063;
        image_array[13][19] = 12'h063;
        image_array[13][20] = 12'h073;
        image_array[13][21] = 12'h063;
        image_array[13][22] = 12'h000;
        image_array[13][23] = 12'h000;
        image_array[13][24] = 12'h000;
        image_array[13][25] = 12'h000;
        image_array[13][26] = 12'h000;
        image_array[13][27] = 12'h000;
        image_array[13][28] = 12'h000;
        image_array[13][29] = 12'h000;
        image_array[13][30] = 12'h000;
        image_array[13][31] = 12'h000;
    
        //  14
        image_array[14][0] = 12'h000;
        image_array[14][1] = 12'h000;
        image_array[14][2] = 12'h000;
        image_array[14][3] = 12'h000;
        image_array[14][4] = 12'h000;
        image_array[14][5] = 12'h000;
        image_array[14][6] = 12'h000;
        image_array[14][7] = 12'h010;
        image_array[14][8] = 12'h042;
        image_array[14][9] = 12'h073;
        image_array[14][10] = 12'h063;
        image_array[14][11] = 12'h063;
        image_array[14][12] = 12'h063;
        image_array[14][13] = 12'h063;
        image_array[14][14] = 12'h063;
        image_array[14][15] = 12'h063;
        image_array[14][16] = 12'h063;
        image_array[14][17] = 12'h063;
        image_array[14][18] = 12'h063;
        image_array[14][19] = 12'h063;
        image_array[14][20] = 12'h063;
        image_array[14][21] = 12'h063;
        image_array[14][22] = 12'h073;
        image_array[14][23] = 12'h042;
        image_array[14][24] = 12'h010;
        image_array[14][25] = 12'h000;
        image_array[14][26] = 12'h000;
        image_array[14][27] = 12'h000;
        image_array[14][28] = 12'h000;
        image_array[14][29] = 12'h000;
        image_array[14][30] = 12'h000;
        image_array[14][31] = 12'h000;
    
        //  15
        image_array[15][0] = 12'h000;
        image_array[15][1] = 12'h000;
        image_array[15][2] = 12'h000;
        image_array[15][3] = 12'h000;
        image_array[15][4] = 12'h000;
        image_array[15][5] = 12'h000;
        image_array[15][6] = 12'h000;
        image_array[15][7] = 12'h031;
        image_array[15][8] = 12'h074;
        image_array[15][9] = 12'h063;
        image_array[15][10] = 12'h063;
        image_array[15][11] = 12'h063;
        image_array[15][12] = 12'h063;
        image_array[15][13] = 12'h063;
        image_array[15][14] = 12'h063;
        image_array[15][15] = 12'h063;
        image_array[15][16] = 12'h063;
        image_array[15][17] = 12'h063;
        image_array[15][18] = 12'h063;
        image_array[15][19] = 12'h063;
        image_array[15][20] = 12'h063;
        image_array[15][21] = 12'h063;
        image_array[15][22] = 12'h063;
        image_array[15][23] = 12'h074;
        image_array[15][24] = 12'h031;
        image_array[15][25] = 12'h000;
        image_array[15][26] = 12'h000;
        image_array[15][27] = 12'h000;
        image_array[15][28] = 12'h000;
        image_array[15][29] = 12'h000;
        image_array[15][30] = 12'h000;
        image_array[15][31] = 12'h000;
    
        //  16
        image_array[16][0] = 12'h000;
        image_array[16][1] = 12'h000;
        image_array[16][2] = 12'h000;
        image_array[16][3] = 12'h000;
        image_array[16][4] = 12'h000;
        image_array[16][5] = 12'h000;
        image_array[16][6] = 12'h000;
        image_array[16][7] = 12'h000;
        image_array[16][8] = 12'h000;
        image_array[16][9] = 12'h031;
        image_array[16][10] = 12'h052;
        image_array[16][11] = 12'h073;
        image_array[16][12] = 12'h073;
        image_array[16][13] = 12'h073;
        image_array[16][14] = 12'h073;
        image_array[16][15] = 12'h063;
        image_array[16][16] = 12'h063;
        image_array[16][17] = 12'h073;
        image_array[16][18] = 12'h073;
        image_array[16][19] = 12'h073;
        image_array[16][20] = 12'h073;
        image_array[16][21] = 12'h052;
        image_array[16][22] = 12'h031;
        image_array[16][23] = 12'h000;
        image_array[16][24] = 12'h000;
        image_array[16][25] = 12'h000;
        image_array[16][26] = 12'h000;
        image_array[16][27] = 12'h000;
        image_array[16][28] = 12'h000;
        image_array[16][29] = 12'h000;
        image_array[16][30] = 12'h000;
        image_array[16][31] = 12'h000;
    
        //  17
        image_array[17][0] = 12'h000;
        image_array[17][1] = 12'h000;
        image_array[17][2] = 12'h000;
        image_array[17][3] = 12'h000;
        image_array[17][4] = 12'h000;
        image_array[17][5] = 12'h000;
        image_array[17][6] = 12'h000;
        image_array[17][7] = 12'h000;
        image_array[17][8] = 12'h000;
        image_array[17][9] = 12'h000;
        image_array[17][10] = 12'h000;
        image_array[17][11] = 12'h000;
        image_array[17][12] = 12'h000;
        image_array[17][13] = 12'h000;
        image_array[17][14] = 12'h010;
        image_array[17][15] = 12'h011;
        image_array[17][16] = 12'h011;
        image_array[17][17] = 12'h010;
        image_array[17][18] = 12'h000;
        image_array[17][19] = 12'h000;
        image_array[17][20] = 12'h000;
        image_array[17][21] = 12'h000;
        image_array[17][22] = 12'h000;
        image_array[17][23] = 12'h000;
        image_array[17][24] = 12'h000;
        image_array[17][25] = 12'h000;
        image_array[17][26] = 12'h000;
        image_array[17][27] = 12'h000;
        image_array[17][28] = 12'h000;
        image_array[17][29] = 12'h000;
        image_array[17][30] = 12'h000;
        image_array[17][31] = 12'h000;
    
        //  18
        image_array[18][0] = 12'h000;
        image_array[18][1] = 12'h000;
        image_array[18][2] = 12'h000;
        image_array[18][3] = 12'h000;
        image_array[18][4] = 12'h000;
        image_array[18][5] = 12'h000;
        image_array[18][6] = 12'h000;
        image_array[18][7] = 12'h000;
        image_array[18][8] = 12'h000;
        image_array[18][9] = 12'h000;
        image_array[18][10] = 12'h053;
        image_array[18][11] = 12'h073;
        image_array[18][12] = 12'h063;
        image_array[18][13] = 12'h052;
        image_array[18][14] = 12'h042;
        image_array[18][15] = 12'h042;
        image_array[18][16] = 12'h042;
        image_array[18][17] = 12'h042;
        image_array[18][18] = 12'h052;
        image_array[18][19] = 12'h063;
        image_array[18][20] = 12'h073;
        image_array[18][21] = 12'h053;
        image_array[18][22] = 12'h000;
        image_array[18][23] = 12'h000;
        image_array[18][24] = 12'h000;
        image_array[18][25] = 12'h000;
        image_array[18][26] = 12'h000;
        image_array[18][27] = 12'h000;
        image_array[18][28] = 12'h000;
        image_array[18][29] = 12'h000;
        image_array[18][30] = 12'h000;
        image_array[18][31] = 12'h000;
    
        //  19
        image_array[19][0] = 12'h000;
        image_array[19][1] = 12'h000;
        image_array[19][2] = 12'h000;
        image_array[19][3] = 12'h000;
        image_array[19][4] = 12'h000;
        image_array[19][5] = 12'h000;
        image_array[19][6] = 12'h000;
        image_array[19][7] = 12'h000;
        image_array[19][8] = 12'h031;
        image_array[19][9] = 12'h073;
        image_array[19][10] = 12'h063;
        image_array[19][11] = 12'h063;
        image_array[19][12] = 12'h063;
        image_array[19][13] = 12'h063;
        image_array[19][14] = 12'h063;
        image_array[19][15] = 12'h063;
        image_array[19][16] = 12'h063;
        image_array[19][17] = 12'h063;
        image_array[19][18] = 12'h063;
        image_array[19][19] = 12'h063;
        image_array[19][20] = 12'h063;
        image_array[19][21] = 12'h063;
        image_array[19][22] = 12'h073;
        image_array[19][23] = 12'h031;
        image_array[19][24] = 12'h000;
        image_array[19][25] = 12'h000;
        image_array[19][26] = 12'h000;
        image_array[19][27] = 12'h000;
        image_array[19][28] = 12'h000;
        image_array[19][29] = 12'h000;
        image_array[19][30] = 12'h000;
        image_array[19][31] = 12'h000;
    
        //  20
        image_array[20][0] = 12'h000;
        image_array[20][1] = 12'h000;
        image_array[20][2] = 12'h000;
        image_array[20][3] = 12'h000;
        image_array[20][4] = 12'h000;
        image_array[20][5] = 12'h000;
        image_array[20][6] = 12'h021;
        image_array[20][7] = 12'h063;
        image_array[20][8] = 12'h073;
        image_array[20][9] = 12'h063;
        image_array[20][10] = 12'h063;
        image_array[20][11] = 12'h063;
        image_array[20][12] = 12'h063;
        image_array[20][13] = 12'h063;
        image_array[20][14] = 12'h063;
        image_array[20][15] = 12'h063;
        image_array[20][16] = 12'h063;
        image_array[20][17] = 12'h063;
        image_array[20][18] = 12'h063;
        image_array[20][19] = 12'h063;
        image_array[20][20] = 12'h063;
        image_array[20][21] = 12'h063;
        image_array[20][22] = 12'h063;
        image_array[20][23] = 12'h073;
        image_array[20][24] = 12'h063;
        image_array[20][25] = 12'h021;
        image_array[20][26] = 12'h000;
        image_array[20][27] = 12'h000;
        image_array[20][28] = 12'h000;
        image_array[20][29] = 12'h000;
        image_array[20][30] = 12'h000;
        image_array[20][31] = 12'h000;
    
        //  21
        image_array[21][0] = 12'h000;
        image_array[21][1] = 12'h000;
        image_array[21][2] = 12'h000;
        image_array[21][3] = 12'h000;
        image_array[21][4] = 12'h042;
        image_array[21][5] = 12'h063;
        image_array[21][6] = 12'h073;
        image_array[21][7] = 12'h063;
        image_array[21][8] = 12'h063;
        image_array[21][9] = 12'h063;
        image_array[21][10] = 12'h063;
        image_array[21][11] = 12'h063;
        image_array[21][12] = 12'h063;
        image_array[21][13] = 12'h063;
        image_array[21][14] = 12'h063;
        image_array[21][15] = 12'h063;
        image_array[21][16] = 12'h063;
        image_array[21][17] = 12'h063;
        image_array[21][18] = 12'h063;
        image_array[21][19] = 12'h063;
        image_array[21][20] = 12'h063;
        image_array[21][21] = 12'h063;
        image_array[21][22] = 12'h063;
        image_array[21][23] = 12'h063;
        image_array[21][24] = 12'h063;
        image_array[21][25] = 12'h073;
        image_array[21][26] = 12'h063;
        image_array[21][27] = 12'h042;
        image_array[21][28] = 12'h000;
        image_array[21][29] = 12'h000;
        image_array[21][30] = 12'h000;
        image_array[21][31] = 12'h000;
    
        //  22
        image_array[22][0] = 12'h000;
        image_array[22][1] = 12'h000;
        image_array[22][2] = 12'h000;
        image_array[22][3] = 12'h000;
        image_array[22][4] = 12'h031;
        image_array[22][5] = 12'h073;
        image_array[22][6] = 12'h063;
        image_array[22][7] = 12'h063;
        image_array[22][8] = 12'h063;
        image_array[22][9] = 12'h063;
        image_array[22][10] = 12'h063;
        image_array[22][11] = 12'h063;
        image_array[22][12] = 12'h063;
        image_array[22][13] = 12'h063;
        image_array[22][14] = 12'h063;
        image_array[22][15] = 12'h063;
        image_array[22][16] = 12'h063;
        image_array[22][17] = 12'h063;
        image_array[22][18] = 12'h063;
        image_array[22][19] = 12'h063;
        image_array[22][20] = 12'h063;
        image_array[22][21] = 12'h063;
        image_array[22][22] = 12'h063;
        image_array[22][23] = 12'h063;
        image_array[22][24] = 12'h063;
        image_array[22][25] = 12'h063;
        image_array[22][26] = 12'h073;
        image_array[22][27] = 12'h031;
        image_array[22][28] = 12'h000;
        image_array[22][29] = 12'h000;
        image_array[22][30] = 12'h000;
        image_array[22][31] = 12'h000;
    
        //  23
        image_array[23][0] = 12'h000;
        image_array[23][1] = 12'h000;
        image_array[23][2] = 12'h000;
        image_array[23][3] = 12'h000;
        image_array[23][4] = 12'h000;
        image_array[23][5] = 12'h000;
        image_array[23][6] = 12'h021;
        image_array[23][7] = 12'h052;
        image_array[23][8] = 12'h073;
        image_array[23][9] = 12'h073;
        image_array[23][10] = 12'h073;
        image_array[23][11] = 12'h063;
        image_array[23][12] = 12'h063;
        image_array[23][13] = 12'h063;
        image_array[23][14] = 12'h063;
        image_array[23][15] = 12'h063;
        image_array[23][16] = 12'h063;
        image_array[23][17] = 12'h063;
        image_array[23][18] = 12'h063;
        image_array[23][19] = 12'h063;
        image_array[23][20] = 12'h063;
        image_array[23][21] = 12'h073;
        image_array[23][22] = 12'h073;
        image_array[23][23] = 12'h073;
        image_array[23][24] = 12'h052;
        image_array[23][25] = 12'h031;
        image_array[23][26] = 12'h000;
        image_array[23][27] = 12'h000;
        image_array[23][28] = 12'h000;
        image_array[23][29] = 12'h000;
        image_array[23][30] = 12'h000;
        image_array[23][31] = 12'h000;
    
        //  24
        image_array[24][0] = 12'h000;
        image_array[24][1] = 12'h000;
        image_array[24][2] = 12'h000;
        image_array[24][3] = 12'h000;
        image_array[24][4] = 12'h000;
        image_array[24][5] = 12'h000;
        image_array[24][6] = 12'h000;
        image_array[24][7] = 12'h000;
        image_array[24][8] = 12'h000;
        image_array[24][9] = 12'h000;
        image_array[24][10] = 12'h011;
        image_array[24][11] = 12'h021;
        image_array[24][12] = 12'h032;
        image_array[24][13] = 12'h042;
        image_array[24][14] = 12'h042;
        image_array[24][15] = 12'h042;
        image_array[24][16] = 12'h042;
        image_array[24][17] = 12'h042;
        image_array[24][18] = 12'h042;
        image_array[24][19] = 12'h032;
        image_array[24][20] = 12'h031;
        image_array[24][21] = 12'h011;
        image_array[24][22] = 12'h000;
        image_array[24][23] = 12'h000;
        image_array[24][24] = 12'h000;
        image_array[24][25] = 12'h000;
        image_array[24][26] = 12'h000;
        image_array[24][27] = 12'h000;
        image_array[24][28] = 12'h000;
        image_array[24][29] = 12'h000;
        image_array[24][30] = 12'h000;
        image_array[24][31] = 12'h000;
    
        //  25
        image_array[25][0] = 12'h000;
        image_array[25][1] = 12'h000;
        image_array[25][2] = 12'h000;
        image_array[25][3] = 12'h000;
        image_array[25][4] = 12'h000;
        image_array[25][5] = 12'h000;
        image_array[25][6] = 12'h000;
        image_array[25][7] = 12'h000;
        image_array[25][8] = 12'h000;
        image_array[25][9] = 12'h000;
        image_array[25][10] = 12'h000;
        image_array[25][11] = 12'h000;
        image_array[25][12] = 12'h000;
        image_array[25][13] = 12'h000;
        image_array[25][14] = 12'h100;
        image_array[25][15] = 12'h321;
        image_array[25][16] = 12'h321;
        image_array[25][17] = 12'h100;
        image_array[25][18] = 12'h000;
        image_array[25][19] = 12'h000;
        image_array[25][20] = 12'h000;
        image_array[25][21] = 12'h000;
        image_array[25][22] = 12'h000;
        image_array[25][23] = 12'h000;
        image_array[25][24] = 12'h000;
        image_array[25][25] = 12'h000;
        image_array[25][26] = 12'h000;
        image_array[25][27] = 12'h000;
        image_array[25][28] = 12'h000;
        image_array[25][29] = 12'h000;
        image_array[25][30] = 12'h000;
        image_array[25][31] = 12'h000;
    
        //  26
        image_array[26][0] = 12'h000;
        image_array[26][1] = 12'h000;
        image_array[26][2] = 12'h000;
        image_array[26][3] = 12'h000;
        image_array[26][4] = 12'h000;
        image_array[26][5] = 12'h000;
        image_array[26][6] = 12'h000;
        image_array[26][7] = 12'h000;
        image_array[26][8] = 12'h000;
        image_array[26][9] = 12'h000;
        image_array[26][10] = 12'h000;
        image_array[26][11] = 12'h000;
        image_array[26][12] = 12'h000;
        image_array[26][13] = 12'h000;
        image_array[26][14] = 12'h532;
        image_array[26][15] = 12'hEA6;
        image_array[26][16] = 12'hEA6;
        image_array[26][17] = 12'h532;
        image_array[26][18] = 12'h000;
        image_array[26][19] = 12'h000;
        image_array[26][20] = 12'h000;
        image_array[26][21] = 12'h000;
        image_array[26][22] = 12'h000;
        image_array[26][23] = 12'h000;
        image_array[26][24] = 12'h000;
        image_array[26][25] = 12'h000;
        image_array[26][26] = 12'h000;
        image_array[26][27] = 12'h000;
        image_array[26][28] = 12'h000;
        image_array[26][29] = 12'h000;
        image_array[26][30] = 12'h000;
        image_array[26][31] = 12'h000;
    
        //  27
        image_array[27][0] = 12'h000;
        image_array[27][1] = 12'h000;
        image_array[27][2] = 12'h000;
        image_array[27][3] = 12'h000;
        image_array[27][4] = 12'h000;
        image_array[27][5] = 12'h000;
        image_array[27][6] = 12'h000;
        image_array[27][7] = 12'h000;
        image_array[27][8] = 12'h000;
        image_array[27][9] = 12'h000;
        image_array[27][10] = 12'h000;
        image_array[27][11] = 12'h000;
        image_array[27][12] = 12'h000;
        image_array[27][13] = 12'h000;
        image_array[27][14] = 12'h432;
        image_array[27][15] = 12'hD95;
        image_array[27][16] = 12'hD95;
        image_array[27][17] = 12'h432;
        image_array[27][18] = 12'h000;
        image_array[27][19] = 12'h000;
        image_array[27][20] = 12'h000;
        image_array[27][21] = 12'h000;
        image_array[27][22] = 12'h000;
        image_array[27][23] = 12'h000;
        image_array[27][24] = 12'h000;
        image_array[27][25] = 12'h000;
        image_array[27][26] = 12'h000;
        image_array[27][27] = 12'h000;
        image_array[27][28] = 12'h000;
        image_array[27][29] = 12'h000;
        image_array[27][30] = 12'h000;
        image_array[27][31] = 12'h000;
    
        //  28
        image_array[28][0] = 12'h000;
        image_array[28][1] = 12'h000;
        image_array[28][2] = 12'h000;
        image_array[28][3] = 12'h000;
        image_array[28][4] = 12'h000;
        image_array[28][5] = 12'h000;
        image_array[28][6] = 12'h000;
        image_array[28][7] = 12'h000;
        image_array[28][8] = 12'h000;
        image_array[28][9] = 12'h000;
        image_array[28][10] = 12'h000;
        image_array[28][11] = 12'h000;
        image_array[28][12] = 12'h000;
        image_array[28][13] = 12'h000;
        image_array[28][14] = 12'h432;
        image_array[28][15] = 12'hD95;
        image_array[28][16] = 12'hD95;
        image_array[28][17] = 12'h432;
        image_array[28][18] = 12'h000;
        image_array[28][19] = 12'h000;
        image_array[28][20] = 12'h000;
        image_array[28][21] = 12'h000;
        image_array[28][22] = 12'h000;
        image_array[28][23] = 12'h000;
        image_array[28][24] = 12'h000;
        image_array[28][25] = 12'h000;
        image_array[28][26] = 12'h000;
        image_array[28][27] = 12'h000;
        image_array[28][28] = 12'h000;
        image_array[28][29] = 12'h000;
        image_array[28][30] = 12'h000;
        image_array[28][31] = 12'h000;
    
        //  29
        image_array[29][0] = 12'h000;
        image_array[29][1] = 12'h000;
        image_array[29][2] = 12'h000;
        image_array[29][3] = 12'h000;
        image_array[29][4] = 12'h000;
        image_array[29][5] = 12'h000;
        image_array[29][6] = 12'h000;
        image_array[29][7] = 12'h000;
        image_array[29][8] = 12'h000;
        image_array[29][9] = 12'h000;
        image_array[29][10] = 12'h000;
        image_array[29][11] = 12'h000;
        image_array[29][12] = 12'h000;
        image_array[29][13] = 12'h000;
        image_array[29][14] = 12'h432;
        image_array[29][15] = 12'hDA5;
        image_array[29][16] = 12'hDA5;
        image_array[29][17] = 12'h432;
        image_array[29][18] = 12'h000;
        image_array[29][19] = 12'h000;
        image_array[29][20] = 12'h000;
        image_array[29][21] = 12'h000;
        image_array[29][22] = 12'h000;
        image_array[29][23] = 12'h000;
        image_array[29][24] = 12'h000;
        image_array[29][25] = 12'h000;
        image_array[29][26] = 12'h000;
        image_array[29][27] = 12'h000;
        image_array[29][28] = 12'h000;
        image_array[29][29] = 12'h000;
        image_array[29][30] = 12'h000;
        image_array[29][31] = 12'h000;
    
        //  30
        image_array[30][0] = 12'h000;
        image_array[30][1] = 12'h000;
        image_array[30][2] = 12'h000;
        image_array[30][3] = 12'h000;
        image_array[30][4] = 12'h000;
        image_array[30][5] = 12'h000;
        image_array[30][6] = 12'h000;
        image_array[30][7] = 12'h000;
        image_array[30][8] = 12'h000;
        image_array[30][9] = 12'h000;
        image_array[30][10] = 12'h000;
        image_array[30][11] = 12'h000;
        image_array[30][12] = 12'h000;
        image_array[30][13] = 12'h000;
        image_array[30][14] = 12'h321;
        image_array[30][15] = 12'h863;
        image_array[30][16] = 12'h863;
        image_array[30][17] = 12'h321;
        image_array[30][18] = 12'h000;
        image_array[30][19] = 12'h000;
        image_array[30][20] = 12'h000;
        image_array[30][21] = 12'h000;
        image_array[30][22] = 12'h000;
        image_array[30][23] = 12'h000;
        image_array[30][24] = 12'h000;
        image_array[30][25] = 12'h000;
        image_array[30][26] = 12'h000;
        image_array[30][27] = 12'h000;
        image_array[30][28] = 12'h000;
        image_array[30][29] = 12'h000;
        image_array[30][30] = 12'h000;
        image_array[30][31] = 12'h000;
    
        //  31
        image_array[31][0] = 12'h000;
        image_array[31][1] = 12'h000;
        image_array[31][2] = 12'h000;
        image_array[31][3] = 12'h000;
        image_array[31][4] = 12'h000;
        image_array[31][5] = 12'h000;
        image_array[31][6] = 12'h000;
        image_array[31][7] = 12'h000;
        image_array[31][8] = 12'h000;
        image_array[31][9] = 12'h000;
        image_array[31][10] = 12'h000;
        image_array[31][11] = 12'h000;
        image_array[31][12] = 12'h000;
        image_array[31][13] = 12'h000;
        image_array[31][14] = 12'h000;
        image_array[31][15] = 12'h000;
        image_array[31][16] = 12'h000;
        image_array[31][17] = 12'h000;
        image_array[31][18] = 12'h000;
        image_array[31][19] = 12'h000;
        image_array[31][20] = 12'h000;
        image_array[31][21] = 12'h000;
        image_array[31][22] = 12'h000;
        image_array[31][23] = 12'h000;
        image_array[31][24] = 12'h000;
        image_array[31][25] = 12'h000;
        image_array[31][26] = 12'h000;
        image_array[31][27] = 12'h000;
        image_array[31][28] = 12'h000;
        image_array[31][29] = 12'h000;
        image_array[31][30] = 12'h000;
        image_array[31][31] = 12'h000;
    end
end

endmodule
