# Local 50 MHz implementation target; no supported-frequency guarantee.
create_clock -name apb_clock -period 20 [get_ports pclk]
set_clock_uncertainty 0.1 [get_clocks apb_clock]
set_clock_transition 0.1 [get_clocks apb_clock]
set data_inputs [get_ports {psel penable pwrite paddr* pwdata*}]
set_input_transition 0.1 $data_inputs
set_max_fanout 32 [current_design]
set_input_delay -clock apb_clock -max 2.0 $data_inputs
set_input_delay -clock apb_clock -min 0.2 $data_inputs
set_output_delay -clock apb_clock -max 2.0 [all_outputs]
set_output_delay -clock apb_clock -min 0.2 [all_outputs]
set_load 0.005 [all_outputs]
# Reset assertion/deassertion recovery/removal and system reset distribution
# are excluded from this educational target and must be checked separately.
set_false_path -from [get_ports preset_n]
