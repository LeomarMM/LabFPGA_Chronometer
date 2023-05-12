--*************************************************************************************
--
--	Módulo		:	EDGE_DETECTOR
-- Descrição	:	Componente de detecção de borda.
--	Entradas:
--					i_CLK				--> Clock global.
--					i_RST				--> Reset assíncrono.
--					i_SIGNAL			--> Sinal de referência
--	Saídas:
--					o_EDGE_DOWN		--> Pulso de descida do sinal.
--
--*************************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity EDGE_DETECTOR is
port
(
	i_RST				:	in std_logic;
	i_CLK				:	in std_logic;	
	i_SIGNAL			:	in std_logic;
	o_EDGE_DOWN		:	out std_logic
);
end EDGE_DETECTOR;

architecture behavioral of EDGE_DETECTOR is

	signal r_FIRST, r_SECOND : std_logic;

begin

	U1 : process(i_CLK, i_RST)														
 	begin																							
		if (i_RST = '1')  then																	
			r_FIRST	<=	'0';																		
			r_SECOND	<=	'0';
		elsif rising_edge (i_CLK) then												
			r_FIRST		<= i_SIGNAL;																			
			r_SECOND		<= r_FIRST;																																				
		end if;																					
	end process U1;																

   o_EDGE_DOWN <= not(r_FIRST) and r_SECOND;							   

end behavioral;
