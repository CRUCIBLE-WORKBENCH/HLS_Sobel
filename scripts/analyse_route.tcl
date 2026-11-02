set hd $::env(PDKPATH)/libs.ref/sky130_fd_sc_hd
read_liberty $hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db build/route.odb
read_sdc scripts/constraints.sdc
set_propagated_clock [all_clocks]
read_spef build/route.spef
report_worst_slack -max
report_worst_slack -min
report_checks -path_delay min_max -format full_clock_expanded -digits 4 -group_path_count 5 > reports/timing.rpt
report_check_types -max_slew -max_capacitance -max_fanout -violators > reports/electrical.rpt
check_setup -verbose > reports/check_setup.rpt
# Deliberately infeasible clock; do not change the implemented RTL or SDC.
create_clock -name apb_clock -period 1 [get_ports pclk]
set_propagated_clock [all_clocks]
report_checks -path_delay max -digits 4 -group_path_count 1 > reports/timing_negative.rpt
puts SOBEL_EXTRACTED_STA_AND_NEGATIVE_CONTROL_FINISHED
