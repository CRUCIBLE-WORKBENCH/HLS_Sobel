# Expose physical supply terminals on existing, connected met5 PDN metal.
# No signal wiring, source RTL or power-grid geometry is changed.
proc add_power_terminals {} {
    set block [ord::get_db_block]
    foreach name {VPWR VGND} {
        set net [$block findNet $name]
        if {$net eq "NULL"} {error "Missing supply net $name"}
        set terminal [$block findBTerm $name]
        if {$terminal ne "NULL"} {
            if {[$terminal getNet] ne $net || [llength [$terminal getBPins]] == 0} {
                error "Existing $name terminal is disconnected or has no pin shapes"
            }
            continue
        }
        set shape ""
        foreach wire [$net getSWires] {
            foreach box [$wire getWires] {
                if {![$box isVia] && [[$box getTechLayer] getName] eq "met5"} {
                    set shape $box
                    break
                }
            }
            if {$shape ne ""} {break}
        }
        if {$shape eq ""} {error "No connected met5 supply metal for $name"}
        set terminal [odb::dbBTerm_create $net $name]
        $terminal setIoType INOUT
        $terminal setSigType [$net getSigType]
        set pin [odb::dbBPin_create $terminal]
        $pin setPlacementStatus FIRM
        odb::dbBox_create $pin [$shape getTechLayer] \
            [$shape xMin] [$shape yMin] [$shape xMax] [$shape yMax]
        puts "SOBEL_SUPPLY_TERMINAL $name on existing met5 PDN metal"
    }
}
