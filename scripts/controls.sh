#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PDKPATH="${PDKPATH:-$HOME/.ciel/sky130A}"
python3 scripts/negative_layout.py
MAGIC_EXT_USE_GDS=1 igny run --env hls-sobel netgen lvs \
    'build/physical_verification/sobel_apb.layout.spice sobel_apb' \
    'build/disconnected_result.v sobel_apb' \
    "$PDKPATH/libs.tech/netgen/sky130A_setup.tcl" reports/lvs_negative.log >reports/lvs_negative_stdout.log 2>&1
igny run --env hls-sobel openroad -exit scripts/analyse_route.tcl >reports/sta.log 2>&1
echo SOBEL_PHYSICAL_CONTROLS_EXECUTED
