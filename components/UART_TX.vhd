--*************************************************************************************
--
-- Módulo		: UART_TX
-- Descrição	: Componente para transmissão de dados via UART
-- 
-- Parâmetros Genéricos:
--
--					baud			--> Velocidade de transmissão em bits por segundo.
--					clock			--> Frequência do clock global em Hertz.
--					frame_size	--> Tamanho do enquadramento de dados do pacote.
--					stop_bits	--> Quantidade de bits de parada no fim do pacote.
--
-- Entradas:
--					i_CLK			--> Clock global. Precisa ser mais rápido que a frequência do baud.
--					i_RST			--> Sinal de reset do componente.
--					i_LS			--> Sinal de carregamento/envio. 
--										 Em valor lógico alto, carrega o dado no serializador.
--										 Na borda de descida, inicia a transmissão do dado.
--					i_DATA		--> Dado a ser transmitido pelo módulo.
--
-- Saídas:
--					o_RTS			--> Ready To Send, indica se o módulo está disponível para transmitir.
--					o_TX			--> Saída serial do módulo.
--
--*************************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_TX is

	generic
	(
		baud			:	integer	:= 9600;
		clock			:	integer	:= 50000000;
		frame_size	:	integer	:=	8;
		stop_bits	:	integer	:= 1
	);
	port
	(
		i_DATA	:	in		std_logic_vector(frame_size-1 downto 0);
		i_CLK		:	in		std_logic;
		i_RST		:	in		std_logic;
		i_LS		:	in		std_logic;
		o_TX		:	out	std_logic;
		o_RTS		:	out	std_logic
	);

end UART_TX;

architecture behavioral of UART_TX is

	type send_state is (IDLE, CLOCK_COUNT, SEND, DATA_COUNT, CHECK_END);
	attribute syn_encoding : string;
	attribute syn_encoding of send_state : type is "safe";

	constant phy_size	:	integer := frame_size + 2;

	component COUNTER
	generic
	(
		max_count : integer
	);
	port
	(
		i_CLK		:	in std_logic;
		i_RST		:	in std_logic;
		i_ENA		:	in std_logic := '1';
		o_COUNT	:	out integer range 0 to max_count;
		o_EQ		:	out std_logic
	);
	end component;

	component EDGE_DETECTOR
	port
	(
		i_RST				:	in std_logic;
		i_CLK				:	in std_logic;	
		i_SIGNAL			:	in std_logic;
		o_EDGE_DOWN		:	out std_logic
	);
	end component;

	component PAR2SER
	generic
	(
		word_size	:	integer		:= phy_size;
		rst_val		:	std_logic	:= '1'
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
	end component;

	signal w_CC1_RST	:	std_logic;
	signal w_CC1_EQ	:	std_logic;
	signal w_CC2_ENA	:	std_logic;
	signal w_CC2_RST	:	std_logic;
	signal w_CC2_EQ	:	std_logic;
	signal w_CCLK		:	std_logic;
	signal w_DATA		:	std_logic_vector(phy_size-1 downto 0);
	signal w_LOAD		:	std_logic;
	signal w_LS_DOWN	:	std_logic;
	signal w_ND			:	std_logic;
	signal w_TX			:	std_logic;
	signal t_STATE		:	send_state;

begin

	CC1	:	COUNTER
	generic map
	(
		max_count => clock / baud
	)
	port map
	(
		i_CLK	=>	i_CLK,
		i_RST	=>	w_CC1_RST,
		o_EQ	=> w_CC1_EQ
	);

	CC2	:	COUNTER
	generic map
	(
		max_count => phy_size+stop_bits
	)
	port map
	(
		i_CLK	=>	i_CLK,
		i_RST	=>	w_CC2_RST,
		i_ENA => w_CC2_ENA,
		o_EQ	=> w_CC2_EQ
	);

	P2S	:	PAR2SER
	port map
	(
		i_RST		=> i_RST,
		i_CLK		=> i_CLK,
		i_LOAD	=> w_LOAD,
		i_ND		=> w_ND,
		i_DATA	=> w_DATA,
		o_TX		=>	w_TX
	);

	ED1	:	EDGE_DETECTOR
	port map
	(
		i_RST				=> i_RST,
		i_CLK				=> i_CLK,
		i_SIGNAL			=> i_LS,
		o_EDGE_DOWN 	=> w_LS_DOWN
	);

	-- Transição de Estados
	process(i_RST, i_CLK)
	begin
		if(i_RST = '1') then
			t_STATE <= IDLE;
		elsif(falling_edge(i_CLK)) then
			case t_STATE is
				when IDLE =>
					if(w_LS_DOWN = '1') then
						t_STATE <= SEND;
					else
						t_STATE <= IDLE;
					end if;
				when CLOCK_COUNT =>
					if(w_CC1_EQ = '1') then
						t_STATE <= SEND;
					else
						t_STATE <= CLOCK_COUNT;
					end if;
				when SEND =>
					t_STATE <= DATA_COUNT;
				when DATA_COUNT =>
					t_STATE <= CHECK_END;
				when CHECK_END =>
					if(w_CC2_EQ = '1') then
						t_STATE <= IDLE;
					else
						t_STATE <= CLOCK_COUNT;
					end if;
			end case;
		end if;
	end process;

	-- Atribuições de saída
	o_RTS <= w_LOAD;
	o_TX <= w_TX;

	-- Fios Dependentes dos Estados
	w_CC1_RST <= '0' when t_STATE = CLOCK_COUNT else '1';
	w_CC2_ENA <= '1' when t_STATE = DATA_COUNT else '0';
	w_CC2_RST <= '1' when t_STATE = IDLE else '0';
	w_DATA <= '1' & i_DATA & '0';
	w_LOAD <= '1' when t_STATE = IDLE else '0';
	w_ND <= '1' when t_STATE = SEND else '0';

end behavioral;