vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xil_defaultlib
vlib modelsim_lib/msim/xpm

vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib
vmap xpm modelsim_lib/msim/xpm

vlog -work xil_defaultlib -64 -incr -sv "+incdir+../../../ipstatic" \
"D:/xilinx/vivado_2019/Vivado/2019.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \

vcom -work xpm -64 -93 \
"D:/xilinx/vivado_2019/Vivado/2019.1/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib -64 -incr "+incdir+../../../ipstatic" \
"../../../../nexys_game_color_flood.srcs/sources_1/ip/clk_wiz_game/clk_wiz_game_clk_wiz.v" \
"../../../../nexys_game_color_flood.srcs/sources_1/ip/clk_wiz_game/clk_wiz_game.v" \

vlog -work xil_defaultlib \
"glbl.v"

