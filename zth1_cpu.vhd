-- ZTH1 computer CPU

-- CPU main characteristics:
-- * 16-bit
-- * RISC
-- * Separated memory for instructions (Harvard architecture).
-- * Use of stack of registers (like Transputers).

-- This implementation has been taylored for a 16k RAM (2 * 8k) and 16k ROM (8192 16-bit words) computer. Bus sizes have been ajusted
-- RAM IP-core use separate in and out data buses.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all; 

entity zth1_cpu is 
  port (
         clk  : in std_logic;                        -- clock
			da   : out std_logic_vector(12 downto 0);   -- data address bus
			dhin : in std_logic_vector(7 downto 0);     -- data value bus, high-bytes, read
			dlin : in std_logic_vector(7 downto 0);     -- data value bus, low-bytes, read
			dhou : out std_logic_vector(7 downto 0);     -- data value bus, high-bytes, write
			dlou : out std_logic_vector(7 downto 0);     -- data value bus, low-bytes, write
			ia   : out std_logic_vector(12 downto 0);   -- instruction address bus
			iv   : in std_logic_vector(15 downto 0);    -- instruction value bus
			il   : in std_logic_vector(3 downto 0);    -- input lines (for peripheral)
			ol   : out std_logic_vector(3 downto 0);   -- output lines (for peripheral)
			irq  : in std_logic_vector(1 downto 0);     -- interrupt (vectors) requests, active at low state
			dhwr : out std_logic;                       -- write data (high bytes)
			dlwr : out std_logic;                       -- write data (low bytes)
			dhrd : out std_logic;                       -- read data (high bytes)
			dlrd : out std_logic;                       -- read data (low bytes)
			ird  : out std_logic                        -- read instruction
		 );
end zth1_cpu;	 
		 
		 
architecture behavior of zth1_cpu is
  signal pc : std_logic_vector(15 downto 0)  := x"FFFF";  -- program counter (address of next instruction to fetch)
  signal sp : std_logic_vector(15 downto 0)  := x"FF00";  -- RAM-stack pointer
  signal a :  std_logic_vector(15 downto 0)  := x"0000";  -- accumulator (= top of stack of registers), split into AH and AL
  signal b  : std_logic_vector(15 downto 0)  := x"0000";  -- b to h: other registers in stack  
  signal c  : std_logic_vector(15 downto 0)  := x"0000";
  signal d  : std_logic_vector(15 downto 0)  := x"0000";
  signal e  : std_logic_vector(15 downto 0)  := x"0000";
  signal f  : std_logic_vector(15 downto 0)  := x"0000";
  signal g  : std_logic_vector(15 downto 0)  := x"0000";
  signal h  : std_logic_vector(15 downto 0)  := x"0000";
  signal z  : std_logic := '0';                           -- a=zero flag
  signal cf : std_logic := '0';                           -- carry flag
  signal it : std_logic := '1';                           -- instruction toggle (specifies which byte in the 16-bit instruction word has to be executed)
  signal im : std_logic_vector(1 downto 0)   := "00";    -- interrupt mask (bit at 1= interrupt vector masked)
  signal ps0 : std_logic_vector(16 downto 0);              -- stack of pc and it values (used to return from calls to sub-routines)
  signal ps1 : std_logic_vector(16 downto 0);
  signal ps2 : std_logic_vector(16 downto 0);
  signal ps3 : std_logic_vector(16 downto 0);
  signal ps4 : std_logic_vector(16 downto 0);
  signal ps5 : std_logic_vector(16 downto 0);
  signal ps6 : std_logic_vector(16 downto 0);
  signal ps7 : std_logic_vector(16 downto 0);
  
  begin
    process(clk)
	   variable op : std_logic_vector(7 downto 0);   -- operand = current instruction to execute
		variable s  : std_logic_vector(16 downto 0);  -- dummy variable used for arithmetic operations on A and B
		variable n  : std_logic_vector(3 downto 0);   -- dummy variable (nibble)
		variable m  : std_logic_vector(1 downto 0);   -- dummy variable (2 bits)
		variable l  : std_logic_vector(15 downto 0);  -- dummy variable (word)
		variable init : std_logic := '1';             -- flag indicating initialization 
		variable ftch : std_logic := '1';             -- flag indicating a normal instruction fetch to do 
		begin
		  if (rising_edge(clk)) then
		    -- first cycle of CPU: no instruction fetched yet, execute a NOP and prepare to fetch instruction
		    if (init = '1') then
			   op := x"00";
				init := '0';
			 else
		      if (it = '0') then op := iv(15 downto 8); else op := iv(7 downto 0); end if;
			 end if;
			 
			 -- execute instruction
			 -- note: to handle GTH/GTL/GTW in one cycle, most instructions prepare to read RAM both banks (by pre-setting da/dhrd/dlrd/dhwr/dlwr)
			 case op is
			   -- note: LDH/LDL/PSH/PSL instructions are assumed to be stored at it=0 (i.e. in the high-byte of instruction word). Their argument (xx)
				--       is in the low-byte of the instruction word. Next instruction word will always been fetched after execution of LDH/LDL/PSH/PSL
				
			   -- LDH xx : AH <= xx
			   when x"01" => a(15 downto 8) <= iv(7 downto 0); 
				              da <= iv(4 downto 0) & a(7 downto 0);
				              pc <= pc + 1; ia <= pc(12 downto 0) + 1; ird <= '1'; it <= '0'; -- prepare to fetch next instruction 
								  dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  ftch := '0';
								  
				-- LDL xx : AL <= xx
				when x"02" => a(7 downto 0) <= iv(7 downto 0);
				              da <= a(12 downto 8) & iv(7 downto 0);
				              pc <= pc + 1; ia <= pc(12 downto 0) + 1; ird <= '1'; it <= '0';
								  dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								  ftch := '0'; 
								  
			   -- PSH xx : AH <= xx, shift stack down
				when x"03" => h <= g; g <= f; f <= e; e <= d; d <= c; c <= b; b <= a; a(15 downto 8) <= iv(7 downto 0); 
				              da <= iv(4 downto 0) & a(7 downto 0);
				              pc <= pc + 1; ia <= pc(12 downto 0) + 1; ird <= '1'; it <= '0';
								  dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								  ftch := '0';
								  
				-- AL <= xx, shift stack down
				when x"04" => h <= g; g <= f; f <= e; e <= d; d <= c; c <= b; b <= a; a(7 downto 0) <= iv(7 downto 0); 
				              da <= a(12 downto 8) & iv(7 downto 0);
				              pc <= pc + 1; ia <= pc(12 downto 0) + 1; ird <= '1'; it <= '0';
								  dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								  ftch := '0';
								  
				-- GTH : AH <= (A)
				when x"05" => a(15 downto 8) <= dhin;
				              da <= dhin(4 downto 0) & a(7 downto 0);
								  ftch := '1';
			  	              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- GTL : AL <= (A)
				when x"06" => a(7 downto 0) <= dlin;
				              da <= a(12 downto 8) & dlin;
								  ftch := '1';
				              dlrd <= '1'; dlwr <= '0'; dhrd <= '1'; dhwr <= '0';
								  
				-- GTW : A <= (A)
				when x"07" => a <= dhin & dlin;
				              da <= dhin(4 downto 0) & dlin;
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								  
				-- STH : (B) <= AL
				when x"08" => da <= b(12 downto 0); dhou <= a(15 downto 8);
				              ftch := '1';
				              dhrd <= '0'; dhwr <= '1';dlrd <= '0'; dlwr <= '0'; -- access to RAM (high-byte bank), write    
								  
				-- STL : (B) <= AL
				when x"09" => da <= b(12 downto 0); dlou <= a(7 downto 0);
				              ftch := '1';
			                 dlrd <= '0'; dlwr <= '1'; dhrd <= '0'; dhwr <= '0'; -- access to RAM (low-byte bank), write 
								  
				-- STW : (B) <= A
				when x"0A" => da <= b(12 downto 0); dhou <= a(15 downto 8); dlou <= a(7 downto 0);
				              ftch := '1';
				              dhrd <= '0'; dhwr <= '1'; dlrd <= '0'; dlwr <= '1'; -- access to RAM (both banks), write 
								  
				-- sWA :  AL <=> AH
				when x"0B" => a <= a(7 downto 0) & a(15 downto 8);
			                 da <= a(4 downto 0) & a(15 downto 8);
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- CLL : AL <= 0;
				when x"0C" => a(7 downto 0) <= x"00";
				              da <= a(12 downto 8) & x"00";
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- CLH : AH <= 0;
				when x"0D" => a(15 downto 8) <= x"00";
				              da <= "00000" & a(7 downto 0);
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- DUP : A => B, shift stack down
				when x"0E" => h <= g; g <= f; f <= e; e <= d; d <= c; c <= b; b <= a;
				              -- DA remains unchanged from previous cycle
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- DRP : drop A, shift stack up
				when x"0F" => da <= b(12 downto 0);
			                 a <= b; b <= c; c <= d; d <= e; e <= f; f<= g; 
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- SWP : A <=> B
			   when x"10" => da <= b(12 downto 0);
			                 a <= b; b <= a;
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- RU3 
				when x"11" => da <= b(12 downto 0);
				              a <= b; b <= c; c <= a;
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- RU4
				when x"12" => da <= b(12 downto 0);
			 	              a <= b; b <= c; c <= d; d <= a;
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- RD3
				when x"13" => da <= c(12 downto 0);
				              c <= b; b <= a; a <= c;
                          ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- RD4
				when x"14" => da <= d(12 downto 0);
				              d <= c; c <= b; b <= a; a <= d;
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- INC : A <= A + 1
				when x"15" => if (a = x"FFFF") then 
				                a <= x"0000";
									 da <= "0000000000000";
									 z <= '1';
									 cf <= '1';
								  else
									 a <= a + 1;
									 da <= a(12 downto 0) + 1;
									 z <= '0';
								    cf <= '0';
								  end if;
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
			   -- DEC : A <= A - 1
			   when x"16" => if (a = x"0000") then 
				                a <= x"FFFF";
									 da <= "1111111111111";
									 z <= '0';
									 cf <= '1';
								  else
								    if (a=x"0001") then
									   z <= '1';
									 else
									   z <= '0';
									 end if;
									 da <= a(12 downto 0) - 1;
									 a <= a - 1;
								    cf <= '0';
								  end if;
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
	        	-- ADD : A <= A + B
				when x"17" => s:= ("0" & a) + ("0" & b);
					           cf <= s(16);
					           if (s(15 downto 0) = x"0000") then z <= '1'; else z <= '0'; end if;
							     a <= s(15 downto 0);
								  ftch := '1';
								  da <= s(12 downto 0);
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								  
				-- SUB : A <= A - B
	    		when x"18" => s := ("0" & a) + not ("0" & b) + 1;
							     cf <= s(16); 
			                 if (s(15 downto 0) = x"0000") then z <= '1'; else z <= '0'; end if;
							     a <= s(15 downto 0);
								  da <= s(12 downto 0);
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- AND : A <= A & B
				when x"19" => s := ("0"& a) and ("0"& b);
				              cf <= '0';
								  if (s = 0) then z <= '1'; else z <= '0'; end if;
								  a <= s(15 downto 0);
								  da <= s(12 downto 0);
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
            -- ORR : A <= A | B
				when x"1A" => s := ("0" & a) or ("0" & b);
				              cf <= '0';
								  if (s = 0) then z <= '1'; else z <= '0'; end if;
								  a <= s(15 downto 0);
								  da <= s(12 downto 0);
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
            -- XOR : A <= A & B
				when x"1B" => s := ("0" & a) xor ("0"& b);
				              cf <= '0';
								  if (s = 0) then z <= '1'; else z <= '0'; end if;
								  a <= s(15 downto 0);
								  da <= s(12 downto 0);
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- NOT : A <= ~A
            when x"1C" => s:= not ("0" & A);
                          cf <= '0';
						        if (s = 0) then z <= '1'; else z <= '0'; end if;
								  a <= s(15 downto 0);
								  da <= s(12 downto 0);
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
			   -- NEG : A <= -A
            when x"1D" => s:= not ("0" & A) + 1;
				              cf <= '0';
						        if (s = 0) then z <= '1'; else z <= '0'; end if;
								  a <= s(15 downto 0);
								  da <= s(12 downto 0);
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
			   -- CCF: CF <= 0
			   when x"1E" => cf <= '0';
				              -- DA remains unchanged
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- SCF: CF <= 1
			   when x"1F" => cf <= '1';
				              ftch := '1';
				              -- DA remains unchanged
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- RRL: CF -> AL -> CF
				when x"20" => a <= a(15 downto 8) & cf & a(7 downto 1);
				              cf <= a(0);
								  da <= a(12 downto 8) & cf & a(7 downto 1);
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								  
				-- RRW: CF -> A -> CF
				when x"21" => a <= cf & a(15 downto 1);  
				              cf <= a(0);
								  da <= a(13 downto 1);
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- RLL: CF <- AL <- CF
				when x"22" => a <= a(15 downto 8) & a(6 downto 0) & cf;
				              cf <= a(7);
								  da <= a(12 downto 8) & a(6 downto 0) & cf;
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- RLW: CF <- A <- CF
				when x"23" => a <= a(14 downto 0) & cf;
				              cf <= a(15);
								  da <= a(11 downto 0) & cf;
								  ftch := '1';
				              dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0'; 
								  
				-- BTT: Z <- A[B]
				when x"24" => n := b(3 downto 0);
				              case n is
								    when "0000" => z <= a(0);
									 when "0001" => z <= a(1);
									 when "0010" => z <= a(2);
									 when "0011" => z <= a(3);
									 when "0100" => z <= a(4);
									 when "0101" => z <= a(5);
									 when "0110" => z <= a(6);
									 when "0111" => z <= a(7);
									 when "1000" => z <= a(8);
									 when "1001" => z <= a(9);
									 when "1010" => z <= a(10);
									 when "1011" => z <= a(11);
									 when "1100" => z <= a(12);
									 when "1101" => z <= a(13);
									 when "1110" => z <= a(14);
									 when "1111" => z <= a(15);
									 when others=> z <= '0';
								 end case;
								 ftch := '1';
								 -- DA remains unchanged
				             dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								 
			   -- CMP : compare A and B (unsigned integer)					 
			   when x"25" => s := ("0" & A) + not ("0" & B) + 1;
							     cf <= s(16); 
			                 if (s(15 downto 0) = x"0000") then z <= '1'; else z <= '0'; end if;
								  ftch := '1';
								  -- Since CMP is normally before a jump or call, RAM will not be read 
				              dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0'; 
								  
			   -- JMP : go to address in A ; shift stack up					  
			   when x"26" => pc <= a;
				              ia <= a(12 downto 0);
                          it <= '0'; -- fetch next instruction word
								  ird <= '1';
								  ftch := '0';
								  da <= b(12 downto 0);
				              a <= b; b <= c; c <= d; d <= e; e <= f; f<= g;
								  -- no GTH/GTL/GTW expected after => RAM will not be read
								  dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0'; 
								 
			   -- JPZ : JMP if Z=1
            when x"27" => if (z = '1') then
			                   pc <= a;
									 ia <= a(12 downto 0);
                            it <= '0'; 
									 ird <= '1';
									 ftch := '0';
				              else
								    ftch := '1';				 
								  end if;
								  da <= b(12 downto 0);
								  a <= b; b <= c; c <= d; d <= e; e <= f; f<= g; 
								  dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0'; 
								 
			   -- JNZ : JMP if Z=0
            when x"28" => if (z = '0') then
			                   pc <= a;
									 ia <= a(12 downto 0);
                            it <= '0';
								    ird <= '1'; 
									 ftch := '0'; 
				              else
								    ftch := '1';	  			  
								  end if;
								  da <= b(12 downto 0);
								  a <= b; b <= c; c <= d; d <= e; e <= f; f<= g; 
                          dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0'; 
								 
			   -- JPC : JMP if CF=1
            when x"29" => if (cf = '1') then
			                   pc <= a;
									 ia <= a(12 downto 0);
                            it <= '0';
								    ird <= '1';
									 ftch := '0';
								  else
								    ftch := '1';
								  end if;
								  da <= b(12 downto 0);
				              a <= b; b <= c; c <= d; d <= e; e <= f; f<= g; 		
						        dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0';
								 
			   -- JNC : JMP if CF=0
            when x"2A" => if (cf = '0') then
				                pc <= a;
			                   ia <= a(12 downto 0);
                            it <= '0';
								    ird <= '1';
									 ftch := '0';
								  else
								    ftch := '1';
								  end if;
								  da <= b(12 downto 0);
				              a <= b; b <= c; c <= d; d <= e; e <= f; f<= g;
								  dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0'; 
								 
			   -- CAL : call sub-routine at address in A; shift pc-stack down ; shift register-stack up 
            when x"2B" => ps7 <= ps6; ps6 <= ps5; ps5 <= ps4; ps4 <= ps3; ps3 <= ps2; ps2 <= ps1; ps1 <= ps0;
			                 if (it = '0') then 			  
						          s:= pc & "1"; -- 1st instruction at return from call will be current PC with IT=1
						        else
						          s:= (pc + 1) & "0";
						        end if;
								  ps0 <= s;
						        pc <= a; 
								  ia <= a(12 downto 0);
								  it <= '0';
								  ird <= '1'; 
								  ftch := '0';
								  da <= b(12 downto 0);
				              a <= b; b <= c; c <= d; d <= e; e <= f; f<= g;
								  dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0'; 
								 
			   -- CLZ : CAL if Z=1
            when x"2C" => if (z = '1') then  
                            ps7 <= ps6; ps6 <= ps5; ps5 <= ps4; ps4 <= ps3; ps3 <= ps2; ps2 <= ps1; ps1 <= ps0;
			                   if (it = '0') then 			  
						            s:= pc & "1"; -- 1st instruction at return from call will be current PC with IT=1
						          else
						            s:= (pc + 1) & "0";
						          end if;
									 ps0 <= s;
						          pc <= a;
									 ia <= a(12 downto 0);
                            it <= '0';
								    ird <= '1';
									 ftch := '0';
								  else
								    ftch := '1';
                          end if;
								  da <= b(12 downto 0);
								  a <= b; b <= c; c <= d; d <= e; e <= f; f<= g;
							     dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0'; 	
								
			   -- CNZ : CAL if Z=0
            when x"2D" => if (z = '0') then  
                            ps7 <= ps6; ps6 <= ps5; ps5 <= ps4; ps4 <= ps3; ps3 <= ps2; ps2 <= ps1; ps1 <= ps0;
			                   if (it = '0') then 			  
						            s:= pc & "1"; -- 1st instruction at return from call will be current PC with IT=1
						          else
						            s:= (pc + 1) & "0";
						          end if;
									 ps0 <= s;
						          pc <= a;
									 ia <= a(12 downto 0);
                            it <= '0';
								    ird <= '1';
									 ftch := '0';
								  else
								    ftch := '1';
								  end if;	
								  da <= b(12 downto 0);
				              a <= b; b <= c; c <= d; d <= e; e <= f; f<= g;
							     dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0'; 	 
                         							 
			   -- CLC : CAL if CF=1
            when x"2E" => if (cf = '1') then  
                            ps7 <= ps6; ps6 <= ps5; ps5 <= ps4; ps4 <= ps3; ps3 <= ps2; ps2 <= ps1; ps1 <= ps0;
			                   if (it = '0') then 			  
						            s:= pc & "1"; -- 1st instruction at return from call will be current PC with IT=1
						          else
						            s:= (pc + 1) & "0";
						          end if;
									 ps0 <= s;
						          pc <= a;
									 ia <= a(12 downto 0);
                            it <= '0';
								    ird <= '1';
									 ftch := '0';
								  else
								    ftch := '1';
								  end if;
								  da <= b(12 downto 0);
				              a <= b; b <= c; c <= d; d <= e; e <= f; f<= g; 	
                          dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0'; 
								 
			   -- CNC : CAL if CF=0
            when x"2F" => if (cf = '0') then  
                            ps7 <= ps6; ps6 <= ps5; ps5 <= ps4; ps4 <= ps3; ps3 <= ps2; ps2 <= ps1; ps1 <= ps0;
			                   if (it = '0') then 			  
						            s:= pc & "1"; -- 1st instruction at return from call will be current PC with IT=1
						          else
						            s:= (pc + 1) & "0";
						          end if;
									 ps0 <= s;
						          pc <= a;
									 ia <= a(12 downto 0);
                            it <= '0';
								    ird <= '1';
									 ftch := '0';
								  else
								    ftch := '1';
								  end if;	
								  da <= b(12 downto 0);
				              a <= b; b <= c; c <= d; d <= e; e <= f; f<= g; 	
                          dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0';		
								 
	         -- RET : return from subroutine
            when x"30" => pc <= ps0(16 downto 1);
				              ia <= ps0(13 downto 1);
                          it <= ps0(0);
			                 ird <= '1';  -- fetch instruction
								  ftch:='0';
			                 ps0 <= ps1; ps1 <= ps2; ps2 <= ps3; ps3 <= ps4; ps4 <= ps5; ps5 <= ps6; ps6 <= ps7; 					 
			                 dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								 
			   -- RTZ : return from subroutine if Z=1
            when x"31" => if (z = '1') then
			                   pc <= ps0(16 downto 1);
									 ia <= ps0(13 downto 1);
                            it <= ps0(0);
			                   ird <= '1';
									 ftch := '0';
			                   ps0 <= ps1; ps1 <= ps2; ps2 <= ps3; ps3 <= ps4; ps4 <= ps5; ps5 <= ps6; ps6 <= ps7;
			                 else
								    ftch := '1';
								  end if;
			                 dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								 
			   -- RNZ : return from subroutine if Z=1
            when x"32" => if (z = '0') then
			                   pc <= ps0(16 downto 1);
									 ia <= ps0(13 downto 1);
                            it <= ps0(0);
			                   ird <= '1';
									 ftch := '0';
			                   ps0 <= ps1; ps1 <= ps2; ps2 <= ps3; ps3 <= ps4; ps4 <= ps5; ps5 <= ps6; ps6 <= ps7;
			                 else
								    ftch := '0';
								  end if;
			                 dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';		
					 
	         -- RTC : return from subroutine if CF=1
            when x"33" => if (cf = '1') then
			                   pc <= ps0(16 downto 1);
									 ia <= ps0(13 downto 1);
                            it <= ps0(0);
			                   ird <= '1';
									 ftch := '0';
			                   ps0 <= ps1; ps1 <= ps2; ps2 <= ps3; ps3 <= ps4; ps4 <= ps5; ps5 <= ps6; ps6 <= ps7;
			                 else
								    ftch := '1';
								  end if;
			                 dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								 
			   -- RNC : return from subroutine if cf=1
            when x"34" => if (cf = '0') then
			                   pc <= ps0(16 downto 1);
									 ia <= ps0(13 downto 1);
                            it <= ps0(0);
			                   ird <= '1';
									 ftch := '0';
			                   ps0 <= ps1; ps1 <= ps2; ps2 <= ps3; ps3 <= ps4; ps4 <= ps5; ps5 <= ps6; ps6 <= ps7;
			                 else
								    ftch := '1';
								  end if;
			                 dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								 
            -- ENI : enable interrupt (indicated by 3 last bits of A)
			   when x"35" => case a is
			                   when x"0000" => m := "10";
									 when x"0001" => m := "01";
									 -- if a > max, enable all interrupts
									 when others => m := "00"; 
								  end case;
								  im <= im and m;
								  ftch := '1';
								  dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								 
			   -- DSI : disable interrupt (indicated by 3 last bits of A)
			   when x"36" => case a is
				                -- vector 0 (= reset) is not maskable
			                   when x"0000" => m:= "00";
							 	    when x"0001" => m:= "10";
									 -- if a > max, disable all interrupts except 0
									 when others => m:= "10";
							     end case;
							     im <= im or m;
								  ftch := '1';
							     dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								 
            -- PU1 : push A into RAM stack (step 1)
		      when x"37" => da <= sp(12 downto 0);
		                    dhou <= a(15 downto 8);
								  dlou <= a(7 downto 0);
								  ftch := '1';
							     dhrd <= '0'; dhwr <= '1'; dlrd <= '0'; dlwr <= '1';
							
		      -- PU2 : push A into RAM stack (step 2)
		      when x"38" => sp <= sp + 1;
				              ftch := '1';
						        dhrd <= '0'; dhwr <= '1'; dlrd <= '0'; dlwr <= '1';
							
		      -- PO1 : pop RAM stack into A (step 1)
		      when x"39" => da <= sp(12 downto 0) - 1;
				              ftch := '1';
						        dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
							
		      -- PO2 : pop RAM stack into A (step 2)
		      when x"3A" => a <= dhin & dlin;
		                    da <= dhin(4 downto 0) & dlin;
		                    sp <= sp - 1;
								  ftch := '1';
						        dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
		  
            -- (define IN/OUT instructions here)
            -- OUT : port(A) <= CF
				when x"3B" => case a is
				                when x"0000" => ol(0) <= cf;
									 when x"0001" => ol(1) <= cf;
									 when x"0002" => ol(2) <= cf;
									 when x"0003" => ol(3) <= cf;
									 -- if A > 3, set all output lines to CF
									 when others => ol <= cf & cf & cf & cf;
								  end case;
								  ftch := '1';
					           dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0';
								  
				-- INP : CF <= port(A)
            when x"3C" => case a is
                            when x"0000" => cf <= il(0);
									 when x"0001" => cf <= il(1);
									 when x"0002" => cf <= il(2);
									 when x"0003" => cf <= il(3);
									 when others => cf <= '1';
								  end case;
								  ftch := '1';
					           dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0'; 
								  
				-- SSP : SP <= A
				when x"3D" => sp <= a;
				              ftch := '1';
							     -- DA remains unchanged
						        dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
								  
				-- DOO : PC-stack <= PC (used with RET/RTZ/TNZ/RTC/RNC: allows "do...while" loops)
            --when x"3D" => ps7 <= ps6; ps6 <= ps5; ps5 <= ps4; ps4 <= ps3; ps3 <= ps2; ps2 <= ps1; ps1 <= ps0;
            --             s := pc & it
            --	(to be studied. Would need a "drop PC-stack" new instruction after RET/.. Also, this way of making "do...while" loops
				-- may overload the PC-stack (with embedded loops, etc...)
	
            -- NOP: no instruction (but prepare for reading data)
            when others => ftch := '1';
					            dhrd <= '1'; dhwr <= '0'; dlrd <= '1'; dlwr <= '0';
		   end case;
			
			-- manage interrupts
			if (irq /= "11") then
			  -- apply mask. Interrupt is activated if bit=0
			  m:= im or irq;
			  l := pc;
			  -- priority order of interrupts : max= lower priority, 0= higher priority
			  if (m(1) = '0') then l := x"0004"; end if;
			  -- vector 0 = computer reset
			  if (m(0) = '0') then l := x"0000"; end if;
			  if (l /= pc) then
			    if (l /= x"0000") then
				   -- save current PC if not reset
				   ps7 <= ps6; ps6 <= ps5; ps5 <= ps4; ps4 <= ps3; ps3 <= ps2; ps2 <= ps1; ps1 <= ps0;
			      -- PC and IT have already been set for next instruction (to be called after return from interrupt vector)
				   s:= pc & it;
				   ps0 <= s;
				 end if;					 
			    pc <= l;
				 ia <= l(12 downto 0);
			    it <= '0';
			    ird <= '1';
				 ftch := '0';
			    dhrd <= '0'; dhwr <= '0'; dlrd <= '0'; dlwr <= '0';
			  end if;
			end if;
			
			-- prepare to fetch next pair of instructions (if needed, depending on IT)
			if (ftch = '1') then
			  if (it = '1') then
			    pc <= pc + 1;
				 ia <= pc(12 downto 0) + 1;
				 ird <= '1';
			  else
			    ird <= '0';
			    ia <= pc(12 downto 0);
			  end if;
			  it <= not it;
			end if;
			
	    end if; -- if (rising_edge(clk))
	end process;
end behavior;