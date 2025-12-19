-makelib ies_lib/xil_defaultlib -sv \
  "D:/xilinx/vivado_2019/Vivado/2019.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
-endlib
-makelib ies_lib/xpm \
  "D:/xilinx/vivado_2019/Vivado/2019.1/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib ies_lib/xil_defaultlib \
  "../../../../nexys_game_color_flood.srcs/sources_1/ip/clk_wiz_game/clk_wiz_game_clk_wiz.v" \
  "../../../../nexys_game_color_flood.srcs/sources_1/ip/clk_wiz_game/clk_wiz_game.v" \
-endlib
-makelib ies_lib/xil_defaultlib \
  glbl.v
-endlib

