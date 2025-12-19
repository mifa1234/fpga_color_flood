vlib work
vlib riviera

vlib riviera/xil_defaultlib
vlib riviera/xpm

vmap xil_defaultlib riviera/xil_defaultlib
vmap xpm riviera/xpm

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../ipstatic" \
"D:/xilinx/vivado_2019/Vivado/2019.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \

vcom -work xpm -93 \
"D:/xilinx/vivado_2019/Vivado/2019.1/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../ipstatic" \
"../../../../nexys_game_color_flood.srcs/sources_1/ip/clk_wiz_game/clk_wiz_game_clk_wiz.v" \
"../../../../nexys_game_color_flood.srcs/sources_1/ip/clk_wiz_game/clk_wiz_game.v" \

vlog -work xil_defaultlib \
"glbl.v"

