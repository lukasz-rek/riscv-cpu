# Create your main clock
# Adjust period based on your target frequency (10ns = 100MHz, 20ns = 50MHz)
create_clock -period 10.000 -name sys_clk [get_ports clk]

# Input/output delays (adjust based on your needs)
set_input_delay -clock sys_clk 2.0 [get_ports {rst_n}]
# set_input_delay -clock sys_clk 2.0 [get_ports {uart_rx}]
# set_output_delay -clock sys_clk 2.0 [get_ports {uart_tx}]

# False paths for asynchronous reset
set_false_path -from [get_ports rst_n]