#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
out="$root/build/physical_verification"
mkdir -p "$out"
pdk="${PDKPATH:-$HOME/.ciel/sky130A}"
export CAD_ROOT="${CAD_ROOT:-${CRUCIBLE_ROOT:-$HOME/Crucible}/tools/magic/8.3.682/magic/lib}"
export MAGIC_EXT_USE_GDS=1
cat >"$out/magic.commands" <<EOF
:tech load $pdk/libs.tech/magic/sky130A.tech
:gds read $root/build/sobel_apb.gds
:load sobel_apb
:select top cell
:expand
:drc check
:drc count total
:extract do local
:extract no capacitance
:extract no coupling
:extract no adjust
:extract all
:ext2spice lvs
:ext2spice short resistor
:ext2spice extresist off
:ext2spice -o $out/sobel_apb.layout.spice sobel_apb
:quit -noprompt
EOF
cd "$out"
igny run --env hls-sobel magic -dnull -noconsole <magic.commands >"$root/reports/magic_drc_extract.log" 2>&1
test -s sobel_apb.layout.spice
igny run --env hls-sobel netgen lvs \
    "$out/sobel_apb.layout.spice sobel_apb" "$root/build/routed_power.v sobel_apb" \
    "$pdk/libs.tech/netgen/sky130A_setup.tcl" "$root/reports/lvs.log" >"$root/reports/lvs_stdout.log" 2>&1
echo SOBEL_INDEPENDENT_PHYSICAL_CHECKS_EXECUTED
