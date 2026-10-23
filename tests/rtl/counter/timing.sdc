create_clock -name counter_clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks counter_clk]
# The demo treats asynchronous reset as out-of-band. This excludes reset
# recovery/removal checks; constrain reset release for a real design/signoff.
set_false_path -from [get_ports reset_n]
set_output_delay -clock counter_clk 0.0 [get_ports {count[*]}]
