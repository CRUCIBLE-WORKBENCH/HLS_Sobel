#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/hls reports
export PDKPATH="${PDKPATH:-$HOME/.ciel/sky130A}"
case "${1:-hls}" in
 hls)
    cd build/hls
    timeout 180 igny run --env hls-sobel bambu ../../src/sobel.c --top-fname=sobel3x3 --clock-period=20 >../../reports/bambu.log 2>&1
    test -s sobel3x3.v
    ;;
 core|apb)
    mode="$1"
    igny run --env hls-sobel iverilog -g2012 -Ireference -s "${mode}_tb" -o "build/${mode}.vvp" build/hls/sobel3x3.v rtl/sobel_core_adapter.v rtl/sobel_apb.v "tests/${mode}_tb.v" >"reports/${mode}_compile.log" 2>&1
    igny run --env hls-sobel vvp "build/${mode}.vvp" >"reports/${mode}_positive.log" 2>&1
    set +e
    igny run --env hls-sobel vvp "build/${mode}.vvp" +BAD_EXPECTED >"reports/${mode}_negative.log" 2>&1
    negative_status=$?
    set -e
    test "$negative_status" -ne 0
    grep -q 'MISMATCH vector=0 expected=1 got=0' "reports/${mode}_negative.log"
    cat "reports/${mode}_positive.log"
    echo "SOBEL_${mode^^}_CORRUPTED_EXPECTATION_REJECTED status=$negative_status"
    ;;
 synth)
    python3 - <<'PY'
from pathlib import Path
import os
lib=Path(os.environ['PDKPATH'])/'libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib'
assert lib.is_file(),lib
escaped=str(lib).replace('\\','\\\\').replace('"','\\"')
Path('build/synthesis.ys').write_text(Path('scripts/synthesis.ys').read_text().replace('@LIBERTY@',escaped))
PY
    igny run --env hls-sobel yosys -s build/synthesis.ys >reports/synthesis.log 2>&1
    test -s build/mapped.v
    echo SOBEL_MAPPED_NETLIST_CREATED
    ;;
 physical)
    OMP_NUM_THREADS=4 igny run --env hls-sobel openroad -exit -threads 4 scripts/physical.tcl >reports/physical.log 2>&1
    test -s build/route.def
    test -s build/route.spef
    tail -8 reports/physical.log
    ;;
 mapped|routed)
    mode="$1"
    hd="$PDKPATH/libs.ref/sky130_fd_sc_hd"
    igny run --env hls-sobel iverilog -E -DFUNCTIONAL '-DUNIT_DELAY=#0' -o build/preprocessed_cells.v "$hd/verilog/sky130_fd_sc_hd.v"
    python3 scripts/simulation_models.py
    igny run --env hls-sobel iverilog -g2012 -DFUNCTIONAL -Ireference -s apb_tb -o "build/${mode}_apb.vvp" tests/apb_tb.v "build/$mode.v" "$hd/verilog/primitives.v" build/simulation_cells.v >"reports/${mode}_compile.log" 2>&1
    igny run --env hls-sobel vvp "build/${mode}_apb.vvp" >"reports/${mode}_positive.log" 2>&1
    cat "reports/${mode}_positive.log"
    ;;
 stream)
    igny run --env hls-sobel openroad -exit scripts/finalize.tcl >reports/finalize.log 2>&1
    hd="$PDKPATH/libs.ref/sky130_fd_sc_hd"
    igny run --env hls-sobel klayout-stream strm2gds \
      --lefdef-lefs="build/physical_technology.tlef,$hd/lef/sky130_fd_sc_hd.lef" \
      --lefdef-lef-layouts="$hd/gds/sky130_fd_sc_hd.gds" \
      --lefdef-map=scripts/lefdef_layer_map.txt -d 10 build/route.def build/sobel_apb.gds >reports/stream.log 2>&1
    test -s build/sobel_apb.gds
    echo SOBEL_REAL_CELL_GDS_CREATED
    ;;
 *) exit 2 ;;
esac
