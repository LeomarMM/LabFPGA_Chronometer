library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity CHRONO_COUNTER is
generic
(
	clock			:	integer;
	cmax			:	integer;
	dmax			:	std_logic_vector(23 downto 0)
);
port
(
	i_RST			:	in	std_logic;
	i_CLK			:	in	std_logic;
	i_ENA			:	in std_logic;
	o_DISPLAY5	:	out std_logic_vector(3 downto 0);
	o_DISPLAY4	:	out std_logic_vector(3 downto 0);
	o_DISPLAY3	:	out std_logic_vector(3 downto 0);
	o_DISPLAY2	:	out std_logic_vector(3 downto 0);
	o_DISPLAY1	:	out std_logic_vector(3 downto 0);
	o_DISPLAY0	:	out std_logic_vector(3 downto 0)
);
end CHRONO_COUNTER;

architecture behavioral of CHRONO_COUNTER is

	signal r_COUNTER	:	integer range 0 to cmax := 0;
	type display_array is array (5 downto 0) of std_logic_vector(3 downto 0);

begin

	process(i_CLK, i_RST)
		variable v_DISPLAY	:	display_array	:=	(OTHERS => x"0");
		constant v_DISPLIMIT	:	display_array	:=
		(
			5 =>	dmax(23 downto 20), 
			4 =>	dmax(19 downto 16), 
			3 =>	dmax(15 downto 12), 
			2 =>	dmax(11 downto 8), 
			1 =>	dmax(7 downto 4), 
			0 =>	dmax(3 downto 0)
		);
		variable v_CARRY		:	std_logic	:=	'0';
	begin
		o_DISPLAY5	<=	v_DISPLAY(5);
		o_DISPLAY4	<=	v_DISPLAY(4);
		o_DISPLAY3	<=	v_DISPLAY(3);
		o_DISPLAY2	<=	v_DISPLAY(2);
		o_DISPLAY1	<=	v_DISPLAY(1);
		o_DISPLAY0	<=	v_DISPLAY(0);
		if(i_RST = '1') then
			v_DISPLAY	:=	(OTHERS => x"0");
			v_CARRY		:=	'0';
		elsif(rising_edge(i_CLK)) then
			if(i_ENA = '1') then
				if(r_COUNTER = cmax) then

					r_COUNTER <= 0;

					if(v_DISPLAY(0) = v_DISPLIMIT(0)) then
						v_DISPLAY(0) := x"0";
						v_CARRY := '1';
					else
						v_DISPLAY(0) := v_DISPLAY(0) + 1;
						v_CARRY := '0';
					end if;

					if(v_CARRY = '1') then
						if(v_DISPLAY(1) = v_DISPLIMIT(1)) then
							v_DISPLAY(1) := x"0";
							v_CARRY := '1';
						else
							v_DISPLAY(1) := v_DISPLAY(1) + 1;
							v_CARRY := '0';
						end if;
					end if;
					
					if(v_CARRY = '1') then
						if(v_DISPLAY(2) = v_DISPLIMIT(2)) then
							v_DISPLAY(2) := x"0";
							v_CARRY := '1';
						else
							v_DISPLAY(2) := v_DISPLAY(2) + 1;
							v_CARRY := '0';
						end if;
					end if;

					if(v_CARRY = '1') then
						if(v_DISPLAY(3) = v_DISPLIMIT(3)) then
							v_DISPLAY(3) := x"0";
							v_CARRY := '1';
						else
							v_DISPLAY(3) := v_DISPLAY(3) + 1;
							v_CARRY := '0';
						end if;
					end if;

					if(v_CARRY = '1') then
						if(v_DISPLAY(4) = v_DISPLIMIT(4)) then
							v_DISPLAY(4) := x"0";
							v_CARRY := '1';
						else
							v_DISPLAY(4) := v_DISPLAY(4) + 1;
							v_CARRY := '0';
						end if;
					end if;

					if(v_CARRY = '1') then
						if(v_DISPLAY(5) = v_DISPLIMIT(5)) then
							v_DISPLAY(5) := x"0";
							v_CARRY := '0';
						else
							v_DISPLAY(5) := v_DISPLAY(5) + 1;
							v_CARRY := '0';
						end if;
					end if;

				else
					r_COUNTER <= r_COUNTER + 1;
				end if;
			end if;
		end if;
	end process;
end behavioral;