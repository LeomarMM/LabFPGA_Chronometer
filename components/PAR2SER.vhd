--*************************************************************************************
--
-- Modulo		:	PAR2SER
-- Descriçao	:	Conversor paralelo-serial.
--
-- Entradas:
--					i_CLK		--> Clock global.
--					i_RST		--> Reset assíncrono da FPGA.
--					i_DATA	--> Palavra de 8 bits que será serializada.
--					i_LOAD	--> Pulso pra carregar o serializador com a palavra.
--					i_ND		--> Sinal que informa o serializador para mandar um novo bit para a serial UART (TX)
-- Saídas:
--					o_TX		--> Conteúdo serializado.
--
--*************************************************************************************

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;

entity PAR2SER is
 	generic
	(
		word_size	:	integer		:= 8;
		rst_val		:	std_logic	:= '0'
	);
	port
	(
		i_RST		: in std_logic;
		i_CLK		: in std_logic;
		i_LOAD	: in std_logic;
		i_ND		: in std_logic;
		i_DATA	: in std_logic_vector(word_size-1 downto 0);
		o_TX		: out std_logic
	);
end PAR2SER;

architecture Behavioral of PAR2SER is
----------------------------------------------------------------------------------------------
-- Sinais internos.
----------------------------------------------------------------------------------------------
	signal r_DATA	: std_logic_vector (i_DATA'range);
	signal r_ND		: std_logic;
----------------------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------------------
-- Serializador ( Bit mais significativo primeiro).
----------------------------------------------------------------------------------------------
	U1 : process (i_CLK, i_RST)
	begin

		if(i_RST = '1') then
			r_ND <= '0';
			o_TX <= rst_val;
		elsif falling_edge(i_CLK) then
			if(i_ND = '1') then
				o_TX <= r_DATA(0);
				r_ND <= '1';
			else
				r_ND <= '0';
			end if;
		end if;

	end process U1;
	
	-- Carregando/deslocando o dado no serializador

	U2 : process (i_RST, i_CLK)
	begin
		if(i_RST = '1') then
			r_DATA <= (OTHERS => rst_val);
		elsif rising_edge(i_CLK) then
			if(i_LOAD = '1') then
				r_DATA <= i_DATA;

			elsif(r_ND = '1') then
				r_DATA <= rst_val & r_DATA(word_size-1 downto 1);
			end if;
		end if;

	end process U2;

----------------------------------------------------------------------------------------------
end Behavioral;