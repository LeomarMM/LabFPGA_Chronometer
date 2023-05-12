library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LOOPBACK is
	port
	(
		i_RST		: in std_logic;
		i_CLK		: in std_logic;
		i_DATA	: in std_logic_vector(7 downto 0);
		i_LOAD	: in std_logic;
		i_ND		: in std_logic;
		o_DATA	: out std_logic_vector(7 downto 0)
	);
end LOOPBACK;

architecture behavioral of LOOPBACK is

	component PAR2SER
	port
	(
		i_RST		: in std_logic;
		i_CLK		: in std_logic;
		i_LOAD	: in std_logic;
		i_ND		: in std_logic;
		i_DATA	: in std_logic_vector(7 downto 0);
		o_TX		: out std_logic
	);
	end component;

	component SER2PAR
	port
	(
		i_RST		: in std_logic;
		i_CLK		: in std_logic;
		i_ND		: in std_logic;
		o_DATA	: out std_logic_vector(7 downto 0);
		i_RX		: in std_logic
	);
	end component;

	signal r_ND	: std_logic;
	signal w_TX	: std_logic;

begin

	P2S	:	PAR2SER
	port map
	(
			i_RST		=> i_RST,
			i_CLK		=> i_CLK,
			i_LOAD	=> i_LOAD,
			i_ND		=> i_ND,
			i_DATA	=> i_DATA,
			o_TX		=> w_TX
	);

	S2P	:	SER2PAR
	port map
	(
			i_RST		=> i_RST,
			i_CLK		=> i_CLK,
			i_ND		=> r_ND,
			o_DATA	=> o_DATA,
			i_RX		=> w_TX
	);

	ND_DELAY: process(i_CLK, i_RST)
	begin

		if(i_RST = '1') then
			r_ND <= '0';
		elsif(falling_edge(i_CLK)) then

			r_ND <= i_ND;

		end if;
	end process;
end behavioral;