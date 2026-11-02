# Preserve the completed route; expose supply terminals on existing PDN shapes.
read_db build/route.odb
source scripts/power_terminals.tcl
add_power_terminals
global_connect
write_def build/route.def
write_db build/route.odb
write_verilog build/routed.v
write_verilog -include_pwr_gnd build/routed_power.v
puts SOBEL_SUPPLY_PORTS_EXPORTED
