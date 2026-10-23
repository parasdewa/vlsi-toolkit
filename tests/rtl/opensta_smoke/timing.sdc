# Synthetic constraints used only to smoke-check OpenSTA parsing and reports.
create_clock -name smoke_clk -period 10.0
set_input_delay -clock smoke_clk -max 1.0 [get_ports {a b}]
set_input_delay -clock smoke_clk -min 0.0 [get_ports {a b}]
set_output_delay -clock smoke_clk -max 1.0 [get_ports y]
set_output_delay -clock smoke_clk -min 0.0 [get_ports y]
