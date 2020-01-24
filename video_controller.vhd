-- ZTH1 computer video controller
-- 128 (y) * 192 (x) pixels, 16 colors (defined by LUT in RAM)
-- direct addressing of video RAM

-- version with monochrome sprites
-- Modifications:
-- 2020-12-23:     adjusted number of lines exactly to video RAM


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity video_controller is 
  port (clk25   : in std_logic := '0';
        addr    : out std_logic_vector(12 downto 0);
		  d_h     : in std_logic_vector(7 downto 0) := "00000000";
		  d_l     : in std_logic_vector(7 downto 0) := "00000000";
		  sp_col  : out std_logic_vector(7 downto 0);
		  rden    : out std_logic;
		  wren    : out std_logic;
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
	 variable x : integer range 0 to 1023 := 0;
	 variable y : integer range 0 to 1023 := 0;
	 variable a_r : std_logic_vector(15 downto 0);  -- current address to be read from video RAM
	 variable a_r_s : std_logic_vector(15 downto 0);  -- address to be read from video RAM at scanline start
	 variable reading_lut : std_logic := '0';
	 variable rd: std_logic := '0';
	 variable wr: std_logic := '0';
	 type color_comp is array (natural range <>) of std_logic_vector(7 downto 0);
	 variable lut : color_comp(0 to 47) := (others => "00000000");
	 variable state : integer range 0 to 255 := 0;
	 variable idx1 : integer range 0 to 255 := 0;                     -- indexation of LUT
	 variable idx2 : integer range 0 to 255 := 0;
	 variable d_read_h : std_logic_vector(7 downto 0);
	 variable d_read_l : std_logic_vector(7 downto 0);
	 variable pix : std_logic_vector(3 downto 0);
	 variable n: integer := 0; -- counter for the pixel height
	 -- sprites
	 variable sprt_active : std_logic_vector(11 downto 0);                 -- flag indicating if sprite active in frame
	 variable sprt_disp : std_logic_vector(11 downto 0) := "000000000000"; -- flag indicating if sprite displayed in current line
	 type sprt_coord is array (natural range <>) of integer range 0 to 1023;
	 variable sprt_x : sprt_coord(0 to 7);
	 variable sprt_y : sprt_coord(0 to 7);
	 variable reading_sprt_coord : std_logic := '0';
	 variable reading_sprt_color : std_logic := '0';
	 variable sprt_rdpx : std_logic := '0';
	 type v16 is array (natural range <>) of std_logic_vector(15 downto 0);
	 variable a_sprt_px : v16(0 to 7);
	 type pixc is array (natural range <>) of std_logic_vector(3 downto 0);
	 variable sprt_color : pixc(0 to 7) ;
	 type byte is array (natural range <>) of std_logic_vector(7 downto 0);
	 variable sprt_pxml : byte(0 to 7);
	 variable sprt_xcnt : sprt_coord(0 to 7) := (others => 0);  -- counters of sprite pixel 
	 variable spx : integer range 0 to 255 := 0;
	 variable spy : integer range 0 to 255 := 0;
	 variable y_max : integer range 0 to 1023 := 0;
	 variable sprt_line : std_logic_vector(7 downto 0);
	 variable col0 : std_logic_vector(3 downto 0);   -- if not 0, indicates which sprite (2 to 7) has collided with sprite 0. If 1: landscape collision
	 variable col1 : std_logic_vector(3 downto 0);   -- same for sprite 1
	 variable sprt0 : std_logic := '0';
	 variable sprt1 : std_logic := '0';
	 
	 begin
	   if (rising_edge(clk25)) then
		  
		  if (x = 0) and (y = 0) then
		    reading_lut := '1';
		     -- address of LUT
		    a_r := x"1800";
		    state := 0;
		    idx1 := 0;
		    idx2 := 24;
			 -- initialize sprite pixmap counters for reading
			 a_sprt_px(0) := x"182A";
			 a_sprt_px(1) := x"1832";
			 a_sprt_px(2) := x"183A";
			 a_sprt_px(3) := x"1842";
			 a_sprt_px(4) := x"184A";
			 a_sprt_px(5) := x"1852";
		    a_sprt_px(6) := x"185A";
			 a_sprt_px(7) := x"1862";
			 -- no sprite collision at beginning of frame (this might change...)
			 col0 := "0000";
			 col1 := "0000";
			 wr := '0';
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
				  reading_sprt_coord := '1';
				  -- prepare to start reading sprite coordinates and activity flags
				  a_r := x"1818"; -- address of sprite coordinate array (since right after LUT, maybe not necessary to define it)
				  idx1 := 0;
			   end if;
		    else
			   state := state + 1;
		    end if;
		  else
		    if (reading_sprt_coord = '1') then
		      disp_en <= '0';
			   case state is 
			     when 0 => rd := '1';
			     when 3 => sprt_active(idx1)  := d_h(7);
				            spy := to_integer(unsigned(d_h(6 downto 0)));
					         spx := to_integer(unsigned(d_l));
					         -- convert into physical pixels
						      sprt_y(idx1) := spy + spy + spy + 82;
						      sprt_x(idx1) := spx + spx + 276;
					  	      idx1 := idx1 + 1;
						      a_r := a_r + 1;
						      rd := '0';
			     when others => null;
		      end case;
		      if (state = 3) then
			     state := 0;
			     if (idx1 = 8) then
				    reading_sprt_coord := '0';
			       reading_sprt_color := '1';
	             idx1 := 0;			  
				    idx2 := 4;
				    a_r := x"1826"; -- address of sprite color table
			     end if;
			   else
			     state := state + 1;
		      end if;
			 else	
		      if (reading_sprt_color = '1') then
		        disp_en <= '0';
			     case state is 
			       when 0 => rd := '1';
			       when 3 => sprt_color(idx1)  := d_h(3 downto 0);
				              sprt_color(idx2)  := d_l(3 downto 0);
					      	  idx1 := idx1 + 1;
			 				     idx2 := idx2 + 1;
						        a_r := a_r + 1;
						        rd := '0';
			       when others => null;
		        end case;
		        if (state = 3) then
			       state := 0;
			       if (idx1 = 4) then
				      reading_sprt_color := '0';
						-- get ready to read video RAM
				      a_r_s := x"0000";
					   a_r := x"0000";
				      n := 0;
			       end if;
				  else
			       state := state + 1;
		        end if;
		      end if; 
		    end if;
		  end if;
		  
		  if ((reading_lut = '0') and (reading_sprt_coord = '0') and (reading_sprt_color = '0')) then
		    if (x >= 143) and (x < 794) and (y >= 34) and (y < 515) then
			   disp_en <= '1';
				if (x >= 276) and (x < 660) and (y >= 82) and (y < 466) then
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
				  -- display sprites over frame (if pix value not 0) and check for collisions 
				  
				  for i in 0 to 7 loop
				    if (x = sprt_x(i)) then sprt_xcnt(i) := 0; end if;
				  end loop;
				  
				  sprt0 := '0';
				  sprt1 := '0';
				  
				  -- not sure how "for.. loop" are synthesized (we want sequential, not parallel) => used dull copypasta coding 
				  
				  -- 0 and 1 = player sprites --
				  
				  if ((x >= sprt_x(0)) and (sprt_disp(0) = '1') and (sprt_xcnt(0) < 8)) then
				    idx2 := sprt_xcnt(0);
					 sprt_line := sprt_pxml(0);
					 if (sprt_line(idx2) /= '0') then
					   -- check for "landscape collision" (anything with color=1)
					   if (pix = "0001") then col0 := "0001"; end if;
					   pix := sprt_color(0);
					   sprt0 := '1';	
					 end if;
					 if ((state = 1) or (state = 3) or (state = 5) or (state = 7)) then sprt_xcnt(0) := sprt_xcnt(0) + 1; end if; 
				  end if;
				  
				  if ((x >= sprt_x(1)) and (sprt_disp(1) = '1') and (sprt_xcnt(1) < 8)) then
				    idx2 := sprt_xcnt(1);
					 sprt_line := sprt_pxml(1);
					 if (sprt_line(idx2) /= '0') then
					   -- check for "landscape collision" (anything with color=1)
					   if (pix = "0001") then col1 := "0001"; end if;
					   pix := sprt_color(1);
					   sprt1 := '1';	
					 end if;
					 if ((state = 1) or (state = 3) or (state = 5) or (state = 7)) then sprt_xcnt(1) := sprt_xcnt(1) + 1; end if; 
				  end if;
				  
				  if ((x >= sprt_x(2)) and (sprt_disp(2) = '1') and (sprt_xcnt(2) < 8)) then
				    idx2 := sprt_xcnt(2);
					 sprt_line := sprt_pxml(2);
					 if (sprt_line(idx2) /= '0') then
					   pix := sprt_color(2);
					   if (sprt0 = '1') then col0 := "0010"; end if;
					   if (sprt1 = '1') then col1 := "0010"; end if;	
					 end if;
					 if ((state = 1) or (state = 3) or (state = 5) or (state = 7)) then sprt_xcnt(2) := sprt_xcnt(2) + 1; end if; 
				  end if;
				  
				  if ((x >= sprt_x(3)) and (sprt_disp(3) = '1') and (sprt_xcnt(3) < 8)) then
				    idx2 := sprt_xcnt(3);
					 sprt_line := sprt_pxml(3);
					 if (sprt_line(idx2) /= '0') then
					   pix := sprt_color(3); 
						if (sprt0 = '1') then col0 := "0011"; end if;
					   if (sprt1 = '1') then col1 := "0011"; end if;	
					 end if;
					 if ((state = 1) or (state = 3) or (state = 5) or (state = 7)) then sprt_xcnt(3) := sprt_xcnt(3) + 1; end if; 
				  end if;
				  
				  if ((x >= sprt_x(4)) and (sprt_disp(4) = '1') and (sprt_xcnt(4) < 8)) then
				    idx2 := sprt_xcnt(4);
					 sprt_line := sprt_pxml(4);
					 if (sprt_line(idx2) /= '0') then
					   pix := sprt_color(4); 
						if (sprt0 = '1') then col0 := "0100"; end if;
					   if (sprt1 = '1') then col1 := "0100"; end if;	
					 end if;
					 if ((state = 1) or (state = 3) or (state = 5) or (state = 7)) then sprt_xcnt(4) := sprt_xcnt(4) + 1; end if; 
				  end if;
				  
				  if ((x >= sprt_x(5)) and (sprt_disp(5) = '1') and (sprt_xcnt(5) < 8)) then
				    idx2 := sprt_xcnt(5);
					 sprt_line := sprt_pxml(5);
					 if (sprt_line(idx2) /= '0') then
					   pix := sprt_color(5); 
						if (sprt0 = '1') then col0 := "0101"; end if;
					   if (sprt1 = '1') then col1 := "0101"; end if;	
					 end if;
					 if ((state = 1) or (state = 3) or (state = 5) or (state = 7)) then sprt_xcnt(5) := sprt_xcnt(5) + 1; end if; 
				  end if;
				  
				  if ((x >= sprt_x(6)) and (sprt_disp(6) = '1') and (sprt_xcnt(6) < 8)) then
				    idx2 := sprt_xcnt(6);
					 sprt_line := sprt_pxml(6);
					 if (sprt_line(idx2) /= '0') then
					   pix := sprt_color(6); 
						if (sprt0 = '1') then col0 := "0110"; end if;
					   if (sprt1 = '1') then col1 := "0110"; end if;	
					 end if;
					 if ((state = 1) or (state = 3) or (state = 5) or (state = 7)) then sprt_xcnt(6) := sprt_xcnt(6) + 1; end if; 
				  end if;
				  
				  if ((x >= sprt_x(7)) and (sprt_disp(7) = '1') and (sprt_xcnt(7) < 8)) then
				    idx2 := sprt_xcnt(7);
					 sprt_line := sprt_pxml(7);
					 if (sprt_line(idx2) /= '0') then
					   pix := sprt_color(7); 
						if (sprt0 = '1') then col0 := "0111"; end if;
					   if (sprt1 = '1') then col1 := "0111"; end if;	
					 end if;
					 if ((state = 1) or (state = 3) or (state = 5) or (state = 7)) then sprt_xcnt(7) := sprt_xcnt(7) + 1; end if; 
				  end if;
				  
				  idx1 := to_integer(unsigned(pix));
				  idx2 := idx1 + idx1 + idx1;
			 	  red <= lut(idx2);
				  idx2 := idx2 + 1;
				  green <= lut(idx2);
				  idx2 := idx2 + 1;
				  blue <= lut(idx2);
				  
				  if (state = 7) then state := 0; else state := state + 1; end if;
				  
			   else
				  -- read sprite pixmap lines when showing the left border
				  if  ((x >= 143) and (x < 272) and (y >= 82) and (y < 466)) then
				    -- check which sprites have to be displayed
				    if (x = 143) then
					   y_max := sprt_y(0) + 24;
						if ((y >= sprt_y(0)) and (y < y_max) and (sprt_active(0) = '1')) then sprt_disp(0) := '1'; else sprt_disp(0) := '0'; end if;
						 y_max := sprt_y(1) + 24;
						if ((y >= sprt_y(1)) and (y < y_max) and (sprt_active(1) = '1')) then sprt_disp(1) := '1'; else sprt_disp(1) := '0'; end if;
						 y_max := sprt_y(2) + 24;
						if ((y >= sprt_y(2)) and (y < y_max) and (sprt_active(2) = '1')) then sprt_disp(2) := '1'; else sprt_disp(2) := '0'; end if;
						 y_max := sprt_y(3) + 24;
						if ((y >= sprt_y(3)) and (y < y_max) and (sprt_active(3) = '1')) then sprt_disp(3) := '1'; else sprt_disp(3) := '0'; end if;
						 y_max := sprt_y(4) + 24;
						if ((y >= sprt_y(4)) and (y < y_max) and (sprt_active(4) = '1')) then sprt_disp(4) := '1'; else sprt_disp(4) := '0'; end if;
						 y_max := sprt_y(5) + 24;
						if ((y >= sprt_y(5)) and (y < y_max) and (sprt_active(5) = '1')) then sprt_disp(5) := '1'; else sprt_disp(5) := '0'; end if;
						 y_max := sprt_y(6) + 24;
						if ((y >= sprt_y(6)) and (y < y_max) and (sprt_active(6) = '1')) then sprt_disp(6) := '1'; else sprt_disp(6) := '0'; end if;
						 y_max := sprt_y(7) + 24;
						if ((y >= sprt_y(7)) and (y < y_max) and (sprt_active(7) = '1')) then sprt_disp(7) := '1'; else sprt_disp(7) := '0'; end if;
						idx1 := 0;
						idx2 := 0;
						state := 0;
						sprt_rdpx := '1';
					 else
					   if (sprt_rdpx = '1') then
					     if (sprt_disp(idx1) = '1') then
						    a_r := a_sprt_px(idx1);
					       case state is
				            when 0 => rd := '1';
				            when 3 => sprt_pxml(idx1) := d_h(7 downto 0);
									       rd := '0';
						      when others => null;
						    end case;
						  end if;
				        if (state = 3) then
						    state := 0;
						    idx1 := idx1 + 1;
						    if (idx1 = 8) then
						      -- prepare to get 1st pixel of line in video RAM
						      a_r := a_r_s;
							   sprt_rdpx := '0';
						    end if;
						  else
						    state := state + 1;
						  end if;
						end if;
				    end if;
				  end if;
				  -- get 1st pixels of line when showing the left border
				  if (x >= 272) and (x < 276) and (y >= 82) and (y < 466) then
				    case state is
				      when 0 => rd := '1';
				      when 3 => d_read_h := d_h;
					             d_read_l := d_l;
									 rd := '0';
						when others => null;
				    end case;
				    if (state = 3) then state := 0; else state := state + 1; end if;
				  end if;
				  -- write sprite collision status at end of useful frame
				  if ((x >= 143) and (x < 150) and (y = 466)) then
				    if (x = 143) then state := 0; end if;
				    a_r := x"1824";
			       case state is
			         when 0 => sp_col <= col1 & col0;
			         when 3 => wr := '1';
			         when 6 => wr := '0';
			         when others => null;
			       end case;
			       if (state = 6) then state := 0; else state := state + 1; end if;
				  end if;
				  
			     -- display border
				  red <= "00000000";
				  green <= "00000000";
				  blue <= "00000000";
			   end if;
		    else
			   disp_en <= '0';
		    end if;
		  end if;
		  -- do whatever the (x,y) situation:  
		  if (x < 96) then hsync <= '1'; else hsync <= '0'; end if;
		  if (y < 2) then vsync <= '1'; else vsync <= '0'; end if;
		  rden <= rd;
		  wren <= wr;
		  addr <= a_r(12 downto 0);
		  x := x + 1;
		  if (x = 810) then
		    -- end of scanline reached
		    x := 0;
			 state := 0;
		    y := y + 1;
		    if ((y > 82)  and (y < 466)) then
			   -- re-read line of video RAM to have ZTH1 pix height = 3 actual pix  
			   n := n + 1;
			   if (n = 3) then
				  n := 0;
				  a_r_s := a_r_s + 48;
				  -- increment sprite pixmap counters for next line
				  for i in 0 to 7 loop
				    if (sprt_disp(i)='1') then
				      a_sprt_px(i) := a_sprt_px(i) + 1;
				    end if;
				  end loop;
			   end if;
			   a_r := a_r_s;
		    end if;
			 -- end of frame reached
		    if (y >= 525) then y := 0; end if;
		  end if;
	   end if; -- if (rising_edge...	   
	 end process;
end behavior;
 
		  