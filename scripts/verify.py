"""Observe actual numerical, implementation, physical and negative-control evidence."""
from pathlib import Path
import hashlib
import json
import re
import klayout.db as kdb

ROOT=Path(__file__).resolve().parents[1]
R=ROOT/'reports'
record=json.loads((R/'reference.json').read_text())
assert record['vectors']==5162 and record['unsaturated']==4382 and record['distinct_outputs']==126
assert hashlib.sha256((ROOT/'reference/vectors.mem').read_bytes()).hexdigest()==record['vectors_sha256']=='5a2b5675bbe5d96b01e9e1eda3abe630ccec4fb5d201daeaf368f03e34303a04'
assert hashlib.sha256((ROOT/'src/sobel.c').read_bytes()).hexdigest()==record['source_sha256']
generated=(ROOT/'build/hls/sobel3x3.v').read_text()
assert 'Version: PandA 2024.10' in generated
for index in range(9): assert re.search(r'input \[7:0\] p'+str(index)+r';',generated)
assert re.search(r'output \[7:0\] return_port;',generated)
for mode in ('core','apb','mapped','routed'):
    text=(R/f'{mode}_positive.log').read_text()
    expected='SOBEL_GENERATED_CORE_PASS vectors=5162 max_cycles=1' if mode=='core' else 'SOBEL_APB_PASS vectors=5162 checks=67124 max_polls=1'
    assert expected in text and not re.search(r'(?i)fatal|error|mismatch',text),mode
for mode in ('core','apb'):
    text=(R/f'{mode}_negative.log').read_text()
    assert 'MISMATCH vector=0 expected=1 got=0' in text and 'PASS vectors' not in text
    assert 'non-zero status (1)' in text
magic=(R/'magic_drc_extract.log').read_text()
assert re.findall(r'Total DRC errors found: (\d+)',magic)==['0']
lvs=(R/'lvs.log').read_text()
assert 'Final result: Circuits match uniquely.' in lvs
assert 'Cell pin lists are equivalent.' in lvs and re.search(r'^VPWR\s+\|VPWR',lvs,re.M) and re.search(r'^VGND\s+\|VGND',lvs,re.M)
devices=re.findall(r'Number of devices: (\d+)\s*\|Number of devices: (\d+)',lvs)
nets=re.findall(r'Number of nets: (\d+)\s*\|Number of nets: (\d+)',lvs)
assert devices and nets and devices[-1][0]==devices[-1][1] and nets[-1][0]==nets[-1][1]
bad=(R/'lvs_negative.log').read_text()
assert 'Final result: Netlists do not match.' in bad
assert (ROOT/'build/disconnected_result.v').read_text().count('.Q(deliberately_disconnected_result)')==1
assert (R/'route_drc.rpt').is_file() and (R/'route_drc.rpt').stat().st_size==0
sta=(R/'sta.log').read_text()
assert 'SOBEL_EXTRACTED_STA_AND_NEGATIVE_CONTROL_FINISHED' in sta and '[ERROR' not in sta
setup=float(re.search(r'worst slack max\s+([-\d.]+)',sta)[1])
hold=float(re.search(r'worst slack min\s+([-\d.]+)',sta)[1])
assert setup>=0 and hold>=0
assert 'VIOLATED' not in (R/'electrical.rpt').read_text(), 'Electrical constraints still violated'
negative=re.search(r'([-\d.]+)\s+slack \(VIOLATED\)',(R/'timing_negative.rpt').read_text())
assert negative and float(negative[1])<0
check=(R/'check_setup.rpt').read_text()
assert 'preset_n' in check and 'There is 1 input port missing set_input_delay.' in check
assert 'unconstrained' not in check.lower()
spef=(ROOT/'build/route.spef').read_text()
assert '*DESIGN "sobel_apb"' in spef and spef.count('*D_NET')>700 and '*RES' in spef and '*CAP' in spef
layout=kdb.Layout();layout.read(str(ROOT/'build/sobel_apb.gds'))
tops=layout.top_cells();assert len(tops)==1 and tops[0].name=='sobel_apb'
assert layout.cells()>40 and tops[0].child_instances()>700
bbox=tops[0].bbox()
summary={
    'measurement_date':'2026-10-29','vectors':record['vectors'],'unsaturated_vectors':record['unsaturated'],
    'distinct_results':record['distinct_outputs'],'apb_checks':67124,'core_sampled_cycles':1,
    'functional_scope':'Directed/deterministic vector agreement; zero-delay mapped/routed simulation; not exhaustive equivalence proof or SDF simulation.',
    'clock_period_ns':20,'corner':'SKY130 HD TT 25 C 1.80 V; nominal OpenRCX rules',
    'setup_worst_slack_ns_rounded':setup,'hold_worst_slack_ns_rounded':hold,
    'electrical_violations':0,'magic_drc_errors':0,'route_drc_entries':0,
    'lvs_devices':int(devices[-1][0]),'lvs_nets':int(nets[-1][0]),
    'lvs_scope':'Hierarchical standard-cell comparison; supply/body pins retained; physical filler/tap classes exempted by PDK setup. No rail stripping.',
    'gds_cells':layout.cells(),'top_instances':tops[0].child_instances(),
    'bbox_um':[v*layout.dbu for v in (bbox.left,bbox.bottom,bbox.right,bbox.top)],
    'spef_nets':spef.count('*D_NET'),'negative_clock_slack_ns':float(negative[1]),
    'negative_controls':['Corrupt expected result rejected by core/APB observers','One disconnected result-Q reference rejected by LVS','1 ns clock violates extracted setup'],
    'exclusions':['Reset recovery/removal and distribution','Other PVT/RC corners','Antenna/density/IR/EM/signoff','Pad/ESD design','FPGA board or fabricated silicon'],
}
files=['src/sobel.c','reference/vectors.mem','build/hls/sobel3x3.v','build/mapped.v','build/routed.v','build/routed_power.v','build/sobel_apb.gds','build/route.def','build/route.spef','scripts/constraints.sdc']
summary['files_sha256']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in files}
(R/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='files_sha256'},indent=2))
print('SOBEL_NUMERICAL_APB_PHYSICAL_AND_NEGATIVE_CONTROLS_VERIFIED')
