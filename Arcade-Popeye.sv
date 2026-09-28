//============================================================================
//  Arcade: Popeye
//
//  Port to MiSTer
//  Popeye by Dar (darfpga@aol.fr - sourceforge/darfpga )
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================


module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign USER_OUT  = '1;
assign LED_USER  = rom_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

wire [1:0] ar = status[15:14];

assign VIDEO_ARX =  (!ar) ? ( 12'd512) : (ar - 1'd1);
assign VIDEO_ARY =  (!ar) ? ( 12'd365) : 12'd0;



`include "build_id.v" 
localparam CONF_STR = {
	"RA_POPEYE;;",
	"H0OEF,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	//"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"O3,Scandoubler,Off,On;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire1,Fire2,Start 1P,Start 2P,Coin;",
	"jn,A,B,Start,Select,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys) // 40M
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire [15:0] audio_l, audio_r;

wire [15:0] joy1, joy2, joy3, joy4;
wire [15:0] joy = joy1 | joy2 | joy3 | joy4;
wire [15:0] joy1a, joy2a, joy3a, joy4a;

wire signed [8:0] mouse_x;
wire signed [8:0] mouse_y;
wire        mouse_strobe;
reg   [7:0] mouse_flags;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joy1),
	.joystick_1(joy2),
	.joystick_2(joy3),
	.joystick_3(joy4),

	.joystick_l_analog_0(joy1a),
	.joystick_l_analog_1(joy2a),
	.joystick_l_analog_2(joy3a),
	.joystick_l_analog_3(joy4a)

);

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

reg [7:0] mod = 0;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;


wire m_start1  = joy[6];
wire m_start2  = joy[7];
wire m_coin1   = joy[8];

wire m_right1  = joy1[0];
wire m_left1   = joy1[1];
wire m_down1   = joy1[2];
wire m_up1     = joy1[3];
wire m_fire1a  = joy1[4];
wire m_fire1b  = joy1[5];
//wire m_fire1c  = joy1[6];
//wire m_fire1d  = joy1[7];

wire m_right2  = joy2[0];
wire m_left2   = joy2[1];
wire m_down2   = joy2[2];
wire m_up2     = joy2[3];
wire m_fire2a  = joy2[4];
wire m_fire2b  = joy2[5];
//wire m_fire2c  = joy2[6];
//wire m_fire2d  = joy2[7];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
//wire m_fire_c  = m_fire1c | m_fire2c;
//wire m_fire_d  = m_fire1d | m_fire2d;

wire rom_download = ioctl_download && !ioctl_index;

wire [14:0] rom_addr;
wire  [7:0] rom_do;
wire [13:0] snd_addr;
wire  [7:0] snd_do;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire reset = status[0] | buttons[1] | rom_download;

// RetroAchievements tap (see RETROACHIEVEMENTS below)
wire        ra_cpu_wr;
wire [15:0] ra_cpu_addr;
wire  [7:0] ra_cpu_do;

popeye popeye
(
	.clock_40(clk_sys),
	.reset(reset),
	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_vblank(vblank),
	.video_hblank(hblank),
	.video_hs(hs),
	.video_vs(vs),
	.video_csync(cs),
	.video_ce(ce_pix),
	.tv15Khz_mode(~status[3]),
//	.separate_audio(1'b0),
	.audio_out_l(audio_l),
	.audio_out_r(audio_r),

	.dl_addr(ioctl_addr[16:0]),
	.dl_wr(ioctl_wr&rom_download),
	.dl_data(ioctl_dout),

	.coin(m_coin1),
	.start1(m_start1),
	.start2(m_start2),

	.right1(m_right),
	.left1(m_left),
	.up1(m_up),
	.down1(m_down),
	.fire10(m_fire_a),
	.fire11(m_fire_b),
 
	.right2(m_right),
	.left2(m_left),
	.up2(m_up),
	.down2(m_down),
	.fire20(m_fire_a),
	.fire21(m_fire_b),
	
	.skyskipr(|mod),

	              //  ...DCBA
	.sw1(sw[0]),  //  0000000 --  n.u.(3b hard wired)  / coinage(DCBA)
	
	              // PONMLKJI
	.sw2(sw[1]),  // 11000010 -- Cocktail(1b) / Service(1b) / Bonus(1b) / n.u.(3b) / life(2b)
 
	.service(sw[2][0]),

	.ra_cpu_wr(ra_cpu_wr),
	.ra_cpu_addr(ra_cpu_addr),
	.ra_cpu_do(ra_cpu_do)
);

wire ce_pix_old;
wire hs, vs, cs;
wire hblank, vblank;
wire HSync, VSync;
wire [2:0] r,g;
wire [1:0] b;
wire ce_pix;

arcade_video #(512,8) arcade_video
(
	.*,

	.clk_video(clk_sys),
	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(0)
);

assign AUDIO_L = { audio_l };
assign AUDIO_R = { audio_r };
assign AUDIO_S = 0;

///////////////////   RETROACHIEVEMENTS   //////////////////
//
// RAM mirror for the RetroAchievements fork of Main_MiSTer (popeye_ra_mirror.v,
// from jotego's jtframe via the RA jtcores fork). RA arcade sets are written
// against FinalBurn Neo, whose Popeye driver (d_popeye.cpp) exposes the
// MemIndex concatenation as "All Ram":
//     0x0000 DrvZ80RAM      0x0C00  Z80 8000-8BFF
//     0x0C00 DrvZ80RAM2     0x0200  Z80 8E80-8FFF (0x0C00-0x0D7F)
//     0x0E00 DrvVidRAM      0x0400  Z80 A000-A3FF
//     0x1200 DrvColorRAM    0x0400  Z80 A400-A7FF
//     0x1600 DrvSpriteRAM   0x0300  Z80 8C04-8E7F (0x1600-0x187B)
//     0x1900 DrvBGRAM       0x2000  Z80 C000-DFFF (Sky Skipper: FBNeo's
//                                   scrambled offset, bit 7 of the data -> 0x40)
//     0x3900 background_pos 3       Z80 8C00-8C02
//     0x3903 palette_bank   2       Z80 8C03
//     0x3905 bgbitmap       2 MB    rendered background bitmap, not mirrored
// Writes are mapped by the CPU address, as FBNeo does, although on the board
// 8000-87FF, 8800-8FFF (and the rest of 8000-9FFF) are one 2 kB RAM: the
// program only ever uses FBNeo's view. The Z80 is 8-bit: shadow byte k is RA
// address k; the ARM region table is the identity {0, 0x3905, 0}.
//
// Nothing else uses DDR in this core, so the mirror owns the port and copies
// (2k qwords, ~0.1 ms) at the start of every VBlank. Held off during ROM
// download.

reg        ra_we;
reg [13:0] ra_off;
reg  [7:0] ra_d;
always @(posedge clk_sys) begin
	reg [15:0] a;
	a = ra_cpu_addr;
	ra_d  <= ra_cpu_do;
	ra_we <= ra_cpu_wr;
	casez (a)
		16'b1000_0???_????_????,
		16'b1000_10??_????_????:                ra_off <= a[13:0] - 14'h0000;          // 8000-8BFF
		16'b1000_1100_0000_00??:                ra_off <= 14'h3900 + a[1:0];           // 8C00-8C03
		16'b1101_????_????_????,
		16'b1100_????_????_????:                ra_off <= |mod ? 14'h1900 + {a[11:6], ra_cpu_do[7], a[5:0]}
		                                                      : 14'h1900 + a[12:0];    // C000-DFFF
		16'b1010_00??_????_????:                ra_off <= 14'h0E00 + a[9:0];           // A000-A3FF
		16'b1010_01??_????_????:                ra_off <= 14'h1200 + a[9:0];           // A400-A7FF
		default: begin
			ra_off <= 14'h1600 + (a[13:0] - 14'h0C04);                                 // 8C04-8E7F
			if (a >= 16'h8E80 && a <= 16'h8FFF) ra_off <= 14'h0C00 + (a[13:0] - 14'h0E80);
			if (a <  16'h8C04 || a >  16'h8FFF) ra_we  <= 0;
		end
	endcase
end

wire  [7:0] ra_burstcnt, ra_be;
wire [28:0] ra_addr;
wire [63:0] ra_din;
wire        ra_ddr_we, ra_active;

popeye_ra_mirror #(.AW(14)) ra_mirror
(
	.rst(reset),
	.clk(clk_sys),
	.lvbl(~vblank),
	.hold(ioctl_download),
	.start_ok(1'b1),
	.wr_clk(clk_sys),
	.wr_word({ 2'd0, ra_off[13:1] }),
	.wr_din({ 2{ra_d} }),
	.wr_be(~ra_we ? 2'b00 : ra_off[0] ? 2'b10 : 2'b01),
	.active(ra_active),
	.ddr_busy(DDRAM_BUSY),
	.ddr_burstcnt(ra_burstcnt),
	.ddr_addr(ra_addr),
	.ddr_we(ra_ddr_we),
	.ddr_be(ra_be),
	.ddr_din(ra_din)
);

assign DDRAM_CLK      = clk_sys;
assign DDRAM_BURSTCNT = ra_burstcnt;
assign DDRAM_ADDR     = ra_addr;
assign DDRAM_DIN      = ra_din;
assign DDRAM_BE       = ra_be;
assign DDRAM_WE       = ra_ddr_we;
assign DDRAM_RD       = 1'b0;

endmodule
