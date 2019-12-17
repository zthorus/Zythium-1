--
-- ZTH computer, based on ZTH1 CPU. RAM: 2 * 8k. ROM: 16k 

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity zth1 is 
  port(
        clk    : in std_logic;                       -- CPU clock
		  --clk_25MHz : in std_logic;
        --clk_250MHz : in std_logic;
		  il     : in std_logic_vector(3 downto 0);    -- input lines (for peripheral)
		  ol     : out std_logic_vector(3 downto 0);   -- output lines (for peripheral)
        irq    : in std_logic_vector(1 downto 0);    -- interrupt requests
		  tmds_clk_n     : out std_logic;
		  tmds_clk_p     : out std_logic;
		  tmds_d0_n      : out std_logic;
		  tmds_d0_p      : out std_logic;
		  tmds_d1_n      : out std_logic;
		  tmds_d1_p      : out std_logic;
		  tmds_d2_n      : out std_logic;
		  tmds_d2_p      : out std_logic
		);
end zth1;

architecture behavior of zth1 is

  -- ZTH1 to RAM signals
  signal ram_a_zbus : std_logic_vector(12 downto 0);
  signal ram_h_rd_zbus : std_logic_vector(7 downto 0);
  signal ram_l_rd_zbus : std_logic_vector(7 downto 0);
  signal ram_h_wr_zbus : std_logic_vector(7 downto 0);
  signal ram_l_wr_zbus : std_logic_vector(7 downto 0);
  signal ram_h_zwren : std_logic;
  signal ram_l_zwren : std_logic;
  signal ram_h_zrden : std_logic;
  signal ram_l_zrden : std_logic;
  -- Video-controller to RAM signals
  signal ram_a_vbus : std_logic_vector(12 downto 0);
  signal ram_h_rd_vbus : std_logic_vector(7 downto 0);
  signal ram_l_rd_vbus : std_logic_vector(7 downto 0);
  signal ram_vrden : std_logic;
  -- ZTH1 to ROM signals
  signal rom_a_bus : std_logic_vector(12 downto 0);
  signal rom_d_bus : std_logic_vector(15 downto 0);
  signal rom_rden : std_logic;
  -- Video system signals
  signal d_en : std_logic;
  signal hsyn : std_logic;
  signal vsyn : std_logic;
  signal red_c : std_logic_vector(7 downto 0);
  signal grn_c : std_logic_vector(7 downto 0);
  signal blu_c : std_logic_vector(7 downto 0);
  signal tmds_r : std_logic_vector(9 downto 0);
  signal tmds_g : std_logic_vector(9 downto 0);
  signal tmds_b : std_logic_vector(9 downto 0);
  
  signal mem_clk : std_logic;
  signal clk_25MHz : std_logic;
  signal clk_250MHz : std_logic;
  
  signal gnd : std_logic := '0';
  signal gnd8 : std_logic_vector(7 downto 0) := "00000000";

begin
  cpu : entity work.zth1_cpu port map(clk,ram_a_zbus,ram_h_rd_zbus,ram_l_rd_zbus,ram_h_wr_zbus,ram_l_wr_zbus,rom_a_bus,rom_d_bus,il,ol,irq,
	                                   ram_h_zwren,ram_l_zwren,ram_h_zrden,ram_l_zrden,rom_rden);
												  
  data_ram_h : entity work.ram_h port map(ram_a_zbus,ram_a_vbus,mem_clk,ram_h_wr_zbus,gnd8,ram_h_zrden,ram_vrden,ram_h_zwren,gnd,ram_h_rd_zbus,ram_h_rd_vbus);
  data_ram_l : entity work.ram_l port map(ram_a_zbus,ram_a_vbus,mem_clk,ram_l_wr_zbus,gnd8,ram_l_zrden,ram_vrden,ram_l_zwren,gnd,ram_l_rd_zbus,ram_l_rd_vbus);
  instruction_rom : entity work.rom port map(rom_a_bus,mem_clk,rom_rden,rom_d_bus);
  
  video_ctrl : entity work.video_controller port map(clk_25MHz,ram_a_vbus,ram_h_rd_vbus,ram_l_rd_vbus,ram_vrden,d_en,hsyn,vsyn,red_c,grn_c,blu_c);
  tmds_enc_red   : entity work.tmds_encoder port map(clk_25MHz,d_en,gnd,gnd,red_c,tmds_r);
  tmds_enc_green : entity work.tmds_encoder port map(clk_25MHz,d_en,gnd,gnd,grn_c,tmds_g);
  tmds_enc_blue  : entity work.tmds_encoder port map(clk_25MHz,d_en,hsyn,vsyn,blu_c,tmds_b);
  tmds_out_red   : entity work.tmds_output port map(clk_250MHz,tmds_r,tmds_d2_p,tmds_d2_n);
  tmds_out_green : entity work.tmds_output port map(clk_250MHz,tmds_g,tmds_d1_p,tmds_d1_n);
  tmds_out_blue  : entity work.tmds_output port map(clk_250MHz,tmds_b,tmds_d0_p,tmds_d0_n);
  
  clks  : entity work.clocks port map(clk,clk_25MHz,clk_250MHz,open);
  tmds_clk_n <= not clk_25MHz;
  tmds_clk_p <= clk_25MHz;
  mem_clk <= not clk;
  
end behavior;