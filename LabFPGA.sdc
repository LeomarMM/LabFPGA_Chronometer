set_time_format -unit ns -decimal_places 3
create_clock -name {i_CLK} -period 20.000 [get_ports { i_CLK }]
derive_clock_uncertainty
derive_pll_clocks