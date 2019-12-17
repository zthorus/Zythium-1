-- ZTH1 computer video controller
-- 128 (y) * 192 (x) pixels, 16 colors (defined by LUT in RAM)
-- direct addressing of video RAM

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity video_controller is 
  port (clk25   : in std_logic := '0';
        addr    : out std_logic_vector(12 downto 0);
		  d_h     : in std_logic_vector(7 downto 0) := "00000000";
		  d_l     : in std_logic_vector(7 downto 0) := "00000000";
		  rden    : out std_logic;
		  disp_en : out std_logic;
		  hsync   : out std_logic;
		  vsync   : out std_logic;
		  red     : out std_logic_vector(7 downto 0);
		  green   : out std_logic_vector(7 downto 0);
		  blue    : out std_logic_vector(7 downto 0)
		);
end video_controller;

architecture behavior of video_controller is
begin
  process(clk25)
	 variable x : integer := 0;
	 variable y : integer := 0;
	 variable a_r : std_logic_vector(15 downto 0);  -- current address to be read from video RAM
	 variable a_r_s : std_logic_vector(15 downto 0);  -- address to be read from video RAM at scanline start
	 variable reading_lut : std_logic := '0';
	 variable rd: std_logic := '0';
	 type color_comp is array (natural range <>) of std_logic_vector(7 downto 0);
	 variable lut : color_comp(0 to 47) := (others => "00000000");
	 variable state : integer := 0;
	 variable idx1 : integer := 0;                     -- indexation of LUT
	 variable idx2 : integer := 0;
	 variable d_read_h : std_logic_vector(7 downto 0);
	 variable d_read_l : std_logic_vector(7 downto 0);
	 variable pix : std_logic_vector(3 downto 0);
	 variable n: integer := 0; -- counter for the pixel height
	 
	 begin
	   if (rising_edge(clk25)) then
		  if (x = 0) and (y = 0) then
		    reading_lut := '1';
		     -- address of LUT
		    a_r := x"1800";
		    state := 0;
		    idx1 := 0;
		    idx2 := 24;
 		  end if;
		  if (reading_lut = '1') then
		    disp_en <= '0';
		    case state is 
			   when 0 => rd := '1';
			   when 3 => lut(idx1) := d_h;
				          lut(idx2) := d_l;
					  	    idx1 := idx1 + 1;
						    idx2 := idx2 + 1;
						    a_r := a_r + 1;
						    rd := '0';
			   when others => null;
		    end case;
		    if (state = 3) then
			   state := 0;
			   if (idx1 = 24) then
				  reading_lut := '0';
				  -- prepare to start reading video RAM
				  a_r_s := x"0000";
				  n := 0;
			   end if;
		    else
			   state := state + 1;
		    end if;
		  else
		    if (x >= 143) and (x < 794) and (y >= 34) and (y < 515) then
			 --if (x >= 1) and (x < 25) and (y >= 4) and (y < 12) then
			   disp_en <= '1';
				if (x >= 276) and (x < 660) and (y >= 82) and (y < 472) then
				--if (x >= 276) and (x < 660) and (y >= 82) and (y < 466) then
		      --if (x >= 5) and (x < 21) and (y >= 5) and (y < 11) then
			     -- actual display region
				  case state is
				    -- refresh values 1 out of 2 cycles to have ZTH1 pix width = 2 actual pix
				    when 0 => pix := d_read_h(7 downto 4);
					           a_r := a_r + 1;
						  	     rd := '0';
				    when 2 => pix := d_read_h(3 downto 0);
					           rd := '1';
				    when 4 => pix := d_read_l(7 downto 4);
				    when 6 => pix := d_read_l(3 downto 0);
				    when 7 => d_read_h := d_h;
					           d_read_l := d_l;
								  rd:= '0';
				    when others => null;
				  end case;
				  idx1 := to_integer(unsigned(pix));
				  idx2 := idx1 + idx1 + idx1;
			 	  red <= lut(idx2);
				  idx2 := idx2 + 1;
				  green <= lut(idx2);
				  idx2 := idx2 + 1;
				  blue <= lut(idx2);
				  if (state = 7) then state := 0; else state := state + 1; end if;
			   else
				  -- get 1st pixel of line when showing the left border 
				  --if (x < 5) and (x >= 1) and (y >= 5) and (y < 11) then
				  if (x >= 143) and (x < 147) and (y >= 82) and (y < 472) then
				  --if (x >= 143) and (x < 147) and (y >= 82) and (y < 466) then
				    case state is
				      when 0 => rd := '1';
				      when 3 => d_read_h := d_h;
					             d_read_l := d_l;
									 rd := '0';
						when others => null;
				    end case;
				    if (state = 3) then state := 0; else state := state + 1; end if;
				  end if;	 
			     -- display border
				  red <= "00011111";
				  green <= "00000000";
				  blue <= "00111111"; 
			   end if;
		    else
			   disp_en <= '0';
		    end if;
		  end if;
		  -- do whatever the (x,y) situation:  
		  if (x < 96) then hsync <= '1'; else hsync <= '0'; end if;
		  if (y < 2) then vsync <= '1'; else vsync <= '0'; end if;
		  --if (x < 1) then hsync <= '1'; else hsync <= '0'; end if;
		  --if (y < 2) then vsync <= '1'; else vsync <= '0'; end if;
		  rden <= rd;
		  addr <= a_r(12 downto 0);
		  x := x + 1;
		  if (x = 810) then
		  --if (x = 26) then
		    -- end of scanline reached
		    x := 0;
			 state := 0;
		    y := y + 1;
		    if (y > 82) then
			 --if (y >= 5) then
			   -- re-read line of video RAM to have ZTH1 pix height = 3 actual pix  
			   n := n + 1;
			   if (n = 3) then
				  n := 0;
				  a_r_s := a_r_s + 48;
			   end if;
			   a_r := a_r_s;
		    end if;
			 -- end of frame reached
		    if (y >= 525) then y := 0; end if;
			 --if (y > 11) then y := 0; end if;
		  end if;
	   end if; -- if (rising_edge...	   
	 end process;
end behavior;
 
		  