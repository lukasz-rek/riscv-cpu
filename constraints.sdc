# # Clock constraints
# create_clock -name clk -period 10.000 -waveform {0 5} [get_port clk]

# # Reset constraints
# set_input_delay -clock clk -max 5.000 rst_n
# set_input_delay -clock clk -min 0.000 rst_n

# # Output delay constraints
# # Note: For multiple debug ports, you may need to specify them individually
# # or use a simpler approach for Gowin tools

# # Input/output drive strength
# set_driving_cell -lib_cell INVX1 -pin Y clk
# set_driving_cell -lib_cell INVX1 -pin Y rst_n

# # False paths
# set_false_path -from rst_n