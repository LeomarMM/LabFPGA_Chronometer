--*************************************************************************************
--
--	Módulo		:	MONITOR
-- Descrição	:	Componente de atuação e leitura sobre os pinos do FPGA
--	Entradas:
--					i_RX				--> Sinal de recepção da UART.
--					i_CLK				--> Clock global.
--					i_RST				--> Reset assíncrono.
--	Saídas:
--					o_TX				--> Sinal de transmissão da UART.
--					o_PINS			--> Sinal de saída para os pinos à serem controlados.
--
--*************************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MONITOR is
generic
(
	baud		:	integer;
	clock		:	integer;
	bytes		:	integer
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
end MONITOR;

architecture behavioral of MONITOR is

	type top_state is (IDLE, RECV, FILL_BUFFER, 
	PRE_CRC, CRC_FEED, CRC_COUNT, LOAD_ACK, 
	START_RESPONSE, SEND_RESPONSE, CHANGE_MODE,
	FILL_OUTPUT, LOAD_PINS, LOAD_CRC, COUNT_CLEAR, 
	COUNT_SENT,	WAIT_RESPONSE, RECV_RESPONSE, 
	CHECK_RESPONSE, RESET_MACH);
	attribute syn_encoding : string;
	attribute syn_encoding of top_state :  type is "safe";
	
	constant buffer_size : integer := 8*(bytes+1);
	constant output_size : integer := 8*bytes;

	component COUNTER
	generic
	(
		max_count	:	integer;
		reverse		:	std_logic
	);
	port
	(
		i_CLK		:	in std_logic;
		i_RST		:	in std_logic;
		i_ENA		:	in std_logic;
		o_COUNT	:	out integer range 0 to max_count;
		o_EQ		:	out std_logic
	);
	end component;

	component CRC8
	generic
	(
		polynomial		:	std_logic_vector(7 downto 0) := x"2F"
	);
	port
	(
		i_DATA	:	in std_logic;
		i_CLK		:	in std_logic;
		i_RST		:	in std_logic;
		i_ENA		:	in	std_logic;
		o_CRC		:	out std_logic_vector(7 downto 0)
	);
	end component;

	component UART_RX
	generic
	(
		baud	:	integer	:= baud;
		clock	:	integer	:=	clock
	);
	port
	(
		i_CLK		:	in		std_logic;
		i_RST		:	in		std_logic;
		i_RX		:	in		std_logic;
		o_DATA	:	out	std_logic_vector(7 downto 0);
		o_RECV	:	out	std_logic
	);
	end component;

	component UART_TX
	generic
	(
		baud			:	integer	:= baud;
		clock			:	integer	:= clock
	);
	port
	(
		i_DATA	:	in		std_logic_vector(7 downto 0);
		i_CLK		:	in		std_logic;
		i_RST		:	in		std_logic;
		i_LS		:	in		std_logic;
		o_TX		:	out	std_logic;
		o_RTS		:	out	std_logic
	);
	end component;

	constant ACK			:	std_logic_vector(7 downto 0) := x"06";
	constant NAK			:	std_logic_vector(7 downto 0) := x"15";
	signal w_BUF_RST		:	std_logic;
	signal w_BUF_CRC		:	std_logic_vector(buffer_size-1 downto 0);
	signal w_CNT1_ENA		:	std_logic;
	signal w_CNT1_EQ		:	std_logic;
	signal w_CNT1_RST		:	std_logic;
	signal w_CNT1_VAL		:	integer range 0 to buffer_size - 1;
	signal w_CNT2_ENA		:	std_logic;
	signal w_CNT2_EQ		:	std_logic;
	signal w_CNT2_RST		:	std_logic;
	signal w_CRC_DATA		:	std_logic;
	signal w_CRC_ENA		:	std_logic;
	signal w_CRC_OUT		:	std_logic_vector(7 downto 0);
	signal w_CRC_RST		:	std_logic;
	signal w_DATA_RX 		:	std_logic_vector(7 downto 0);
	signal w_EQ				:	std_logic;
	signal w_LS				:	std_logic;
	signal w_OUTPUT_ENA	:	std_logic;
	signal w_RECV			:	std_logic;
	signal w_RTS			:	std_logic;
	signal w_WDT_ENA		:	std_logic;
	signal w_WDT_EQ		:	std_logic;
	signal w_WDT_RST		:	std_logic;
	signal r_BUFFER		:	std_logic_vector(buffer_size-1 downto 0) := (OTHERS => '0');
	signal r_MODE			:	std_logic := '0';
	signal r_OUTPUT		:	std_logic_vector(output_size-1 downto 0) := (OTHERS => '0');
	signal t_STATE			:	top_state := RESET_MACH;

begin

	CC1	:	COUNTER
	generic map
	(
		max_count	=> buffer_size-1,
		reverse		=> '1'
	)
	port map
	(
		i_CLK	=>	"not"(i_CLK),
		i_RST	=>	w_CNT1_RST,
		i_ENA => w_CNT1_ENA,
		o_EQ	=> w_CNT1_EQ,
		o_COUNT => w_CNT1_VAL
	);

	CC2	:	COUNTER
	generic map
	(
		max_count	=> bytes+1,
		reverse		=> '0'
	)
	port map
	(
		i_CLK	=>	"not"(i_CLK),
		i_RST	=>	w_CNT2_RST,
		i_ENA => w_CNT2_ENA,
		o_EQ	=> w_CNT2_EQ
	);
	
	WDT	:	COUNTER
	generic map
	(
		max_count	=> clock,
		reverse		=> '0'
	)
	port map
	(
		i_CLK	=>	"not"(i_CLK),
		i_RST	=>	w_WDT_RST,
		i_ENA => w_WDT_ENA,
		o_EQ	=> w_WDT_EQ
	);

	U1	: CRC8
	port map
	(
		i_DATA	=> w_CRC_DATA,
		i_CLK		=> "not"(i_CLK),
		i_RST		=> w_CRC_RST,
		i_ENA		=>	w_CRC_ENA,
		o_CRC		=> w_CRC_OUT
	);

	U2 : UART_RX
	port map
	(
		i_CLK		=> i_CLK,
		i_RST		=> i_RST,
		i_RX		=> i_RX,
		o_DATA	=>	w_DATA_RX,
		o_RECV	=>	w_RECV
	);
	
	U3 : UART_TX
	port map
	(
		i_DATA	=> r_BUFFER(buffer_size-1 downto output_size),
		i_CLK		=> i_CLK,
		i_RST		=> i_RST,
		i_LS		=> w_LS,
		o_TX		=>	o_TX,
		o_RTS		=>	w_RTS
	);

	-- Registradores de bufferização
	process(i_CLK, w_BUF_RST)
	begin
		if(w_BUF_RST = '1') then
			r_BUFFER <= (OTHERS => '0');
		elsif(falling_edge(i_CLK)) then
			if(t_STATE = FILL_BUFFER) then
				r_BUFFER <= r_BUFFER(output_size-1 downto 0) & w_DATA_RX;
			elsif(t_STATE = LOAD_ACK) then
				if(w_EQ = '1') then
					r_BUFFER(buffer_size-1 downto output_size) <= ACK;
				else
					r_BUFFER(buffer_size-1 downto output_size) <= NAK;
				end if;
			elsif(t_STATE = LOAD_PINS) then
				r_BUFFER <= i_PINS & x"00";
			elsif(t_STATE = LOAD_CRC) then
				r_BUFFER(7 downto 0) <= w_CRC_OUT;
			end if;
		end if;
	end process;
	
	
	-- Registradores de saída
	process(i_CLK, i_RST)
	begin
		if(i_RST = '1') then
			r_OUTPUT <= (OTHERS => '0');
		elsif(falling_edge(i_CLK)) then
			if(w_OUTPUT_ENA = '1') then
				r_OUTPUT <= r_BUFFER(buffer_size-1 downto 8);
			end if;
		end if;
	end process;

	-- Registradores de modo
	process(i_CLK, t_STATE)
	begin
		if(t_STATE = RESET_MACH) then
			r_MODE <= '0';
		elsif(falling_edge(i_CLK)) then
			if(t_STATE = CHANGE_MODE) then
				r_MODE <= '1';
			end if;
		end if;
	end process;

	-- Transição de estados
	process(i_CLK, i_RST)
	begin
		if(i_RST = '1') then
			t_STATE <= RESET_MACH;
		elsif(rising_edge(i_CLK)) then
			case t_STATE is
				when IDLE =>
					if(w_WDT_EQ = '1') then
						t_STATE <= RESET_MACH;
					else
						if(w_RECV = '1') then
							t_STATE <= RECV;
						else
							t_STATE <= IDLE;
						end if;
					end if;
				when RECV =>
					if(w_RECV = '0') then
						t_STATE <= FILL_BUFFER;
					else
						t_STATE <= RECV;
					end if;
				when FILL_BUFFER =>
					if(r_MODE = '0') then
						t_STATE <= COUNT_SENT;
					else
						if(w_CNT2_EQ = '1') then
							t_STATE <= WAIT_RESPONSE;
						else
							t_STATE <= START_RESPONSE;
						end if;
					end if;
				when PRE_CRC =>
					if(r_MODE = '0') then
						if(w_CNT2_EQ = '1') then
							t_STATE <= CRC_FEED;
						else
							t_STATE <= IDLE;
						end if;
					else
						t_STATE <= CRC_FEED;
					end if;
				when CRC_FEED =>
					if(w_CNT1_EQ = '1') then
						if(r_MODE = '0') then
							t_STATE <= FILL_OUTPUT;
						else 
							t_STATE <= LOAD_CRC;
						end if;
					else
						t_STATE <= CRC_COUNT;
					end if;
				when CRC_COUNT =>
					t_STATE <= CRC_FEED;
				when FILL_OUTPUT =>
					t_STATE <= LOAD_ACK;
				when LOAD_ACK =>
					t_STATE <= START_RESPONSE;
				when START_RESPONSE =>
					if(w_RTS = '0') then
						t_STATE <= SEND_RESPONSE;
					else
						t_STATE <= START_RESPONSE;
					end if;
				when SEND_RESPONSE =>
					if(w_RTS = '1') then
						if(r_MODE = '0') then
							t_STATE <= CHANGE_MODE;
						else
							t_STATE <= COUNT_SENT;
						end if;
					else
						t_STATE <= SEND_RESPONSE;
					end if;
				when CHANGE_MODE =>
					if(w_EQ = '1') then
						t_STATE <= LOAD_PINS;
					else
						t_STATE <= RESET_MACH;
					end if;
				when LOAD_PINS	=>
					t_STATE <= PRE_CRC;
				when LOAD_CRC =>
					t_STATE <= COUNT_CLEAR;
				when COUNT_CLEAR =>
					t_STATE <= START_RESPONSE;
				when COUNT_SENT =>
					if(r_MODE = '1') then
						t_STATE <= FILL_BUFFER;
					else
						t_STATE <= PRE_CRC;
					end if;
				when WAIT_RESPONSE =>
					if(w_WDT_EQ = '1') then
						t_STATE <= RESET_MACH;
					else
						if(w_RECV = '1') then
							t_STATE <= RECV_RESPONSE;
						else
							t_STATE <= WAIT_RESPONSE;
						end if;
					end if;
				when RECV_RESPONSE =>
					if(w_RECV = '0') then
						t_STATE <= CHECK_RESPONSE;
					else
						t_STATE <= RECV_RESPONSE;
					end if;
				when CHECK_RESPONSE =>
					if(w_DATA_RX = ACK) then
						t_STATE <= RESET_MACH;
					else
						t_STATE <= LOAD_PINS;
					end if;
				when RESET_MACH =>
					t_STATE <= IDLE;
			end case;
		end if;
	end process;
	
	-- Atribuições de saída
	o_PINS <= r_OUTPUT;
	
	-- Fios Independentes de Estados
	w_BUF_CRC <= r_BUFFER(buffer_size-1 downto 8) & x"00";
	w_CRC_DATA <= w_BUF_CRC(w_CNT1_VAL);
	w_EQ <= '1' when r_BUFFER(7 downto 0) = w_CRC_OUT else '0';

	-- Fios Dependentes de Estados
	w_BUF_RST <=	'1'	when t_STATE = RESET_MACH else '0';
	w_CRC_ENA <=	'1'	when t_STATE = CRC_FEED else '0';
	w_CRC_RST <=	'1'	when t_STATE = PRE_CRC or
							t_STATE = RESET_MACH else '0';
	w_CNT1_ENA <=	'1' when t_STATE = CRC_COUNT else '0';
	w_CNT1_RST <=	'1' when t_STATE = PRE_CRC or
							t_STATE = RESET_MACH else '0';
	w_CNT2_ENA <=	'1' when t_STATE = COUNT_SENT else '0';
	w_CNT2_RST <=	'1' when t_STATE = COUNT_CLEAR or
							t_STATE = RESET_MACH else '0';
	w_WDT_ENA <=	'1' when (t_STATE = IDLE and w_CNT1_VAL /= buffer_size-1) or t_STATE = WAIT_RESPONSE else '0';
	w_WDT_RST <=	'1' when t_STATE = RECV or t_STATE = RECV_RESPONSE or t_STATE = RESET_MACH else '0';
	w_LS	<= '0' when t_STATE = START_RESPONSE else '1';
	w_OUTPUT_ENA <= '1' when t_STATE = FILL_OUTPUT and w_EQ = '1' else '0';

end behavioral;