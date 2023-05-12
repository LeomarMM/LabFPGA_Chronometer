library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity DE1SoC is
generic
(
		baud				:	integer := 9600;
		clock				:	integer := 100000000
);
port
(
	i_CLK		:	in		std_logic;
	i_RX		:	in		std_logic;
	i_RST		:	in		std_logic;
	i_LEDS	:	in		std_logic_vector(9 downto 0);
	i_7S5		:	in		std_logic_vector(6 downto 0);
	i_7S4		:	in		std_logic_vector(6 downto 0);
	i_7S3		:	in		std_logic_vector(6 downto 0);
	i_7S2		:	in		std_logic_vector(6 downto 0);
	i_7S1		:	in		std_logic_vector(6 downto 0);
	i_7S0		:	in		std_logic_vector(6 downto 0);
	o_SWITCH	:	out	std_logic_vector(9 downto 0);
	o_BUTTON	:	out	std_logic_vector(3 downto 0);
	o_TX		:	out	std_logic
);
end DE1SoC;

architecture rtl of DE1SoC is

	component MONITOR is
	generic
	(
		baud				:	integer := baud;
		clock				:	integer := clock;
		bytes				:	integer := 11
	);
	port
	(
		i_RX		:	in std_logic;
		i_CLK		:	in std_logic;
		i_RST		:	in std_logic;
		i_PINS	:	in std_logic_vector(8*bytes-1 downto 0);
		o_TX		:	out std_logic;
		o_PINS	:	out std_logic_vector(8*bytes-1 downto 0)
	);
	end component;

	signal w_IPINS	:	std_logic_vector(87 downto 0);
	signal w_OPINS	:	std_logic_vector(87 downto 0);

begin

	U2 : MONITOR
	port map
	(
		i_RX		=> i_RX,
		i_CLK		=> i_CLK,
		i_RST		=> i_RST,
		i_PINS	=> w_IPINS,
		o_TX		=>	o_TX,
		o_PINS	=> w_OPINS
	);
	
	w_IPINS <=	"000000" & w_OPINS(81 downto 72) &
					"0000" &	w_OPINS(67 downto 64) & 
					"000000" & i_LEDS & 
					'0' & i_7S5 & 
					'0' & i_7S4 & 
					'0' & i_7S3 &
					'0' & i_7S2 & 
					'0' & i_7S1 & 
					'0' & i_7S0;

	o_SWITCH <= w_OPINS(81 downto 72);
	o_BUTTON <= w_OPINS(67 downto 64);

end rtl;