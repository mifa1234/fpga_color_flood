# fpga_color_flood
Implementation of the ColorFlood game on FPGA. Vendor-agnostic.


# ColorFlood Game for FPGA

**Vendor-agnostic implementation** of the classic *Color Flood* (a.k.a. *Flood-It*) game on FPGA. Designed to be easy to port, customize, and run on a wide range of development boards.

##  Features

- Supports **3 game modes**:
  - Single-player (vs static field)
  - Player vs AI
  - Player vs Player
- Configurable colors, UI elements, and game logic
- Optional simple AI opponent
- Resource-efficient: fits in ~5k LUTs (Artix-7) when using single-player mode only
- Built-in anti-bounce logic for buttons
- Optional step counters and territory indicators

##  Module Parameters (`game.sv`)

| Parameter | Description |
|----------|-------------|
| `BG_COLOR` | Background color (recommended: distinct from other colors) |
| `COLOR_1`–`COLOR_5` | Colors of game tiles (default values compatible with RGB111) |
| `COLOR_TRACK_BAR` | Color of unclaimed progress bar area |
| `COLOR_TRACK_BAR_PC` | Progress bar color for FPGA/second player |
| `COLOR_TRACK_BAR_USER` | Progress bar color for first player |
| `ANTI_BOUNCE_DELAY` | Button debounce delay in clock cycles @ 25 MHz |
| `DRAW_MARK` | When `1`, draws dots in tile centers for manual counting |
| `NEW_YEAR` | Festive theme (try values `0`, `1`, `2`) |
| `ENABLE_SIMPLE_AI` | Enables basic AI that maximizes tile capture per move |
| `ONLY_GAME_MODE_0` | When `1`, disables multi-player/AI logic to reduce resource usage |
| `INDICATE_WHO_STEP` | Shows whose turn it is (can be disabled to save resources) |

> **Safe customizations**:
> - Modify `color_rand_pos` (random seed offset)
> - Redefine `color_pre_rand_arr` with values `0–4` (custom initial board)
> - Replace `image_array` (32×32 pixel image, e.g., the New Year tree)

##  How to Run

### For Nexys A7 users
1. Clone the repo:  
   ```bash
   git clone https://github.com/mifa1234/fpga_color_flood.git
   ```
2. Open the `nexys_game_color_flood` project in Vivado
3. Generate bitstream and program your board

### For other FPGA boards
Create a wrapper for `game.sv` with these required signals:

#### Clock & Reset
- `clk` – **25.175 MHz** (VGA pixel clock for 640×480@60Hz)
- `rstn_pb` – active-low reset (1 = not pressed)

#### VGA Output
- `vga_r[3:0]`, `vga_g[3:0]`, `vga_b[3:0]`
- `vga_h_sync`, `vga_v_sync`
- `vga_pixel_valid` (required when using HDMI via rgb2dvi)

#### Controls (all active-high)
- `key_ok` – confirm selection
- `key_select_up`, `key_select_down` – color selection (one can be omitted for cyclic selection)
- `mode_game[1:0]` – game mode selection:
  - `00` = single player
  - `01` = vs AI
  - `10` = two players

#### Optional Statistics Outputs
- `result_game_each_step_valid` – pulses after each move
- `result_game_valid` – asserts at game end
- `count_steps_player_1`, `count_steps_player_2` – move counters
- `result_player_1`, `result_player_2` – captured tiles count (max 165)
- `result_game_mode` – game mode during play

##  Resource Usage
- **Single-player only** (`ONLY_GAME_MODE_0 = 1`): ~5,000 LUTs on Artix-7
- **Full mode** (with AI & multiplayer): fits in most mid-range FPGAs

##  License
MIT License