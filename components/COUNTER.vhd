--*************************************************************************************
--
-- Módulo		: COUNTER
-- Descrição	: Componente contador
-- 
-- Parâmetros Genéricos:
--
--					max_count	--> Vezes a serem contadas.
--					reverse		--> Se '0', contar do 0 ao número máximo, se não, contar do valor máximo para zero.
--
-- Entradas:
--					i_CLK			--> Sinal de clock para o contador.
--					i_RST			--> Sinal de reset do contador.
--					i_ENA			--> Sinal de enable do contador.
--
-- Saídas:
--					o_COUNT		--> Valor do contador interno do componente.
--					o_EQ			--> Indicador de fim da contagem.
--
--*************************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity COUNTER is
generic
(
	max_count	:	integer := 50;
	reverse		:	std_logic := '0'
	
);
port
(
	i_CLK		:	in std_logic;
	i_RST		:	in std_logic;
	i_ENA		:	in	std_logic := '1';
	o_COUNT	:	out integer range 0 to max_count;
	o_EQ		:	out std_logic
);
end COUNTER;



architecture behavioral of COUNTER is

	function REG_START(cond: std_logic; v_true, v_false: integer) return integer is
	begin
		if (cond = '1') then
			return v_true;
		else
			return v_false;
		end if;
	end function REG_START;

	signal r_COUNTER	:	integer range 0 to max_count := REG_START(reverse, max_count, 0);
	signal w_EQ			:	std_logic;

begin

	o_COUNT <= r_COUNTER;
	o_EQ <= w_EQ;
	w_EQ <= '1' when ((r_COUNTER = max_count and reverse = '0') or (r_COUNTER = 0 and reverse = '1')) else '0';

	process (i_CLK, i_RST, w_EQ, r_COUNTER)
	begin
		if(i_RST = '1') then
			if(reverse = '0') then 
				r_COUNTER <= 0;
			else
				r_COUNTER <= max_count;
			end if;
		elsif(rising_edge(i_CLK)) then
			if((w_EQ = '0' and i_ENA = '1')) then
				if(reverse = '0') then 
					r_COUNTER <= (r_COUNTER + 1);
				else
					r_COUNTER <= (r_COUNTER - 1);
				end if;
			end if;
		end if;
	end process;

end behavioral;