--*************************************************************************************
--
-- Módulo		: UART_RX
-- Descrição	: Componente para recepção de dados via UART
-- 
-- Parâmetros Genéricos:
--
--					baud			--> Velocidade de recepção em bits por segundo.
--					clock			--> Frequência do clock global em Hertz.
--					frame_size	--> Tamanho do enquadramento de dados do pacote.
--
-- Entradas:
--					i_CLK			--> Clock global. Precisa ser mais rápido que a frequência do baud.
--					i_RST			--> Sinal de reset do componente.
--					i_RX			--> Entrada do sinal do transmissor, recepção é iniciada na borda de descida
--
-- Saídas:
--					o_DATA		--> Dado recebido na última transmissão.
--					o_RECV		--> Utilizado para indicar se o componente está recebendo dados.
--
--*************************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_RX is
	generic
	(
		baud			:	integer				:= 9600;
		clock			:	integer				:= 50000000;
		frame_size	:	integer				:=	8
	);
	port
	(
		i_CLK		:	in		std_logic;
		i_RST		:	in		std_logic;
		i_RX		:	in		std_logic;
		o_DATA	:	out	std_logic_vector(frame_size-1 downto 0);
		o_RECV	:	out	std_logic
	);
end UART_RX;

architecture behavioral of UART_RX is

	type recv_state is (IDLE, COUNT, ACQUIRE, IDLE_COUNT, CHECK_END);
	attribute syn_encoding : string;
	attribute syn_encoding of recv_state : type is "safe";

	signal w_CNT_EQ		:	std_logic;
	signal w_CNT_RESET	:	std_logic;
	signal w_DATA			:	std_logic_vector(frame_size downto 0);
	signal w_ND				:	std_logic;
	signal w_RECV			:	std_logic;
	signal w_RX_DOWN		:	std_logic;
	signal w_S2P_RESET	:	std_logic;
	signal r_DATA			:	std_logic_vector(frame_size-1 downto 0);
	signal t_STATE			:	recv_state;

	component EDGE_DETECTOR
	port
	(
		i_RST				:	in std_logic;
		i_CLK				:	in std_logic;	
		i_SIGNAL			:	in std_logic;
		o_EDGE_DOWN		:	out std_logic
	);
	end component;

	component SER2PAR
	generic
	(
		word_size	:	integer := frame_size+1
	);
	port
	(
		i_RST		:	in std_logic;
		i_CLK		:	in std_logic;
		i_ND		:	in std_logic;
		o_DATA	:	out std_logic_vector(word_size-1 downto 0);
		i_RX		:	in std_logic
	);
	end component;

	component COUNTER
	generic
	(
		max_count	:	integer := clock / (2*baud)
	);
	port
	(
		i_CLK		:	in std_logic;
		i_RST		:	in std_logic;
		o_COUNT	:	out integer range 0 to max_count;
		o_EQ		:	out std_logic
	);
	end component;

begin

	CC1	:	COUNTER
	port map
	(
		i_CLK	=>	i_CLK,
		i_RST	=>	w_CNT_RESET,
		o_EQ	=> w_CNT_EQ
	);

	ED1	:	EDGE_DETECTOR
	port map
	(
		i_RST			=> i_RST,
		i_CLK			=> i_CLK,
		i_SIGNAL		=> i_RX,
		o_EDGE_DOWN => w_RX_DOWN
	);
	
	S2P	:	SER2PAR
	port map
	(
		i_RST		=>	w_S2P_RESET,
		i_CLK		=>	i_CLK,
		i_ND		=>	w_ND,
		o_DATA	=>	w_DATA,
		i_RX		=>	i_RX
	);

	-- Registradores de saída
	process(i_CLK, i_RST, w_DATA, t_STATE)
	begin
		if(i_RST = '1') then
			r_DATA <= (OTHERS => '1');
		elsif(falling_edge(i_CLK) and w_DATA(0) = '0') then
			r_DATA <= w_DATA(frame_size downto 1);
		end if;
	end process;

	-- Transição de Estados
	UART_MACH : process(i_CLK, i_RX, i_RST, t_STATE, w_RX_DOWN)
	begin
		if(i_RST = '1') then
			t_STATE <= IDLE;
		elsif(falling_edge(i_CLK)) then
			case t_STATE is
				when IDLE	=>
					if(w_RX_DOWN = '1') then
						t_STATE <= COUNT;
					else
						t_STATE <= IDLE;
					end if;
				when COUNT	=>
					if(w_CNT_EQ = '1') then
						t_STATE <= ACQUIRE;
					else
						t_STATE <= COUNT;
					end if;
				when ACQUIRE =>
					t_STATE <= IDLE_COUNT;
				when IDLE_COUNT =>
					if(w_CNT_EQ = '1') then
						t_STATE <= CHECK_END;
					else
						t_STATE <= IDLE_COUNT;
					end if;
				when CHECK_END =>
					if(w_DATA(0) = '0') then
						t_STATE <= IDLE;
					else
						t_STATE <= COUNT;
					end if;
			end case;
		end if;
	end process UART_MACH;

	-- Atribuições de saída
	o_DATA <= r_DATA;
	o_RECV <= w_RECV;

	-- Fios Dependentes dos Estados
	w_CNT_RESET <= '0' when t_STATE = COUNT or t_STATE = IDLE_COUNT else '1';
	w_ND <= '1' when t_STATE = ACQUIRE else '0';
	w_RECV <= '0' when t_STATE = IDLE else '1';
	w_S2P_RESET <= '1' when t_STATE = IDLE else '0';

end behavioral;