# Standalone candidate implementation. Numerical / APB equivalence is checked
# before this stage; these artifacts do not establish foundry signoff.
set pdk $::env(PDKPATH)
set hd $pdk/libs.ref/sky130_fd_sc_hd
file copy -force $hd/techlef/sky130_fd_sc_hd.tlef build/physical_technology.tlef
read_lef build/physical_technology.tlef
read_lef -library $hd/lef/sky130_fd_sc_hd.lef
read_liberty $hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog build/mapped.v
link_design sobel_apb
read_sdc scripts/constraints.sdc
# Mapped cell area is 7764.95 um2; allow placement, clock, tap and filler room.
initialize_floorplan -site unithd -die_area {0 0 180 180} -core_area {12 12 168 168}
make_tracks
place_pins -hor_layers met3 -ver_layers met2
add_global_connection -net VPWR -pin_pattern {^VPWR$} -power
add_global_connection -net VGND -pin_pattern {^VGND$} -ground
add_global_connection -net VPWR -pin_pattern {^VPB$} -power
add_global_connection -net VGND -pin_pattern {^VNB$} -ground
tapcell -tapcell_master sky130_fd_sc_hd__tapvpwrvgnd_1 -endcap_master sky130_fd_sc_hd__decap_4 -distance 14
global_connect
set_voltage_domain -name Core -power VPWR -ground VGND
define_pdn_grid -name Core -voltage_domains Core
add_pdn_stripe -grid Core -layer met1 -width 0.48 -followpins
add_pdn_ring -grid Core -layers {met4 met5} -widths {1.6 1.6} -spacings {1.6 1.6} -core_offsets 2
add_pdn_stripe -grid Core -layer met4 -width 1.6 -pitch 30 -offset 10 -extend_to_core_ring
add_pdn_stripe -grid Core -layer met5 -width 1.6 -pitch 30 -offset 10 -extend_to_core_ring
add_pdn_connect -grid Core -layers {met1 met4}
add_pdn_connect -grid Core -layers {met4 met5}
pdngen
set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met3
global_placement -density 0.55 -pad_left 1 -pad_right 1
detailed_placement
check_placement -verbose
estimate_parasitics -placement
# Repair observed high-fanout select nets before clock-tree synthesis.
set_dont_use [get_lib_cells {*/sky130_fd_sc_hd__*lpflow* */sky130_fd_sc_hd__*_0 */sky130_fd_sc_hd__clkdly* */sky130_fd_sc_hd__probe*}]
buffer_ports -inputs -outputs -buffer_cell sky130_fd_sc_hd__buf_4
repair_tie_fanout -separation 1 sky130_fd_sc_hd__conb_1/HI
repair_tie_fanout -separation 1 sky130_fd_sc_hd__conb_1/LO
# The first routed load exceeded the placement estimate on one 32-way
# address-select net. Reserve 30% when choosing its driver/buffering.
repair_design -slew_margin 30 -cap_margin 30 -max_utilization 65
detailed_placement
check_placement -verbose
clock_tree_synthesis -buf_list {sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_8} -sink_clustering_enable -sink_clustering_size 20
detailed_placement
set_propagated_clock [all_clocks]
estimate_parasitics -placement
# Reserve 0.1 ns against the observed placement-to-route hold shift.
repair_timing -hold -hold_margin 0.1
detailed_placement
filler_placement {sky130_fd_sc_hd__fill_8 sky130_fd_sc_hd__fill_4 sky130_fd_sc_hd__fill_2 sky130_fd_sc_hd__fill_1}
global_connect
check_placement -verbose
# Unused X-valued synthesis aliases can create disconnected constant helpers.
# Remove only genuinely empty nets; never alter a connected constant signal.
foreach net [[ord::get_db_block] getNets] {
    if {[$net getName] in {zero_ one_}} {
        puts "CONSTANT_HELPER [$net getName] iterms=[llength [$net getITerms]] bterms=[llength [$net getBTerms]]"
        if {[llength [$net getITerms]] == 0 && [llength [$net getBTerms]] == 0} {
            odb::dbNet_destroy $net
        }
    }
}
set_routing_layers -signal met1-met5 -clock met3-met5
global_route -guide_file build/route.guide
detailed_route -output_drc reports/route_drc.rpt -output_maze reports/route_maze.log
define_process_corner -ext_model_index 0 tt_rc
extract_parasitics -ext_model_file $pdk/libs.tech/openlane/rcx_rules.info
write_spef build/route.spef
read_spef build/route.spef
report_worst_slack -max
report_worst_slack -min
report_checks -path_delay min_max -format full_clock_expanded -digits 4 -group_path_count 5 > reports/timing.rpt
check_setup -verbose > reports/check_setup.rpt
write_def build/route.def
write_db build/route.odb
write_verilog build/routed.v
puts "SOBEL_ROUTED_CANDIDATE_FINISHED"
