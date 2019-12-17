-- 10-bit shift register with differential output (feeding the HDMI connector)

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity tmds_output is
  port (clk250 :in std_logic;
		  d : in std_logic_vector(9 downto 0);
		  out_p : out std_logic;
		  out_n : out std_logic);
end tmds_output;

architecture behavior of tmds_output is
  signal bit_count : integer := 0;
  signal reg : std_logic_vector(9 downto 0) := (others => '0');
begin  
  process(clk250)
  begin
    if (clk250'event and clk250 = '1') then
	   out_p <= reg(0);
      out_n <= not reg(0);
	   if (bit_count = 9) then
		  reg <= d;
		else
		  reg(0) <= reg(1);
		  reg(1) <= reg(2);
		  reg(2) <= reg(3);
		  reg(3) <= reg(4);
		  reg(4) <= reg(5);
		  reg(5) <= reg(6);
		  reg(6) <= reg(7);
		  reg(7) <= reg(8);
		  reg(8) <= reg(9);
		  reg(9) <= '0';
      end if;
	   if (bit_count < 9) then
	     bit_count <= bit_count + 1;
	   else
		  bit_count <= 0;
	   end if;
	 end if;
  end process;
end behavior;
  
  