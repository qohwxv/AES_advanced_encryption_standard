# Simulation/synthesis clock constraint for the standalone crypto core.
# Board wrapper pin and package pin constraints are intentionally not included.
create_clock -name clk -period 20.000 [get_ports clk]
