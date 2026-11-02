"""Record dependency file identities without embedding workstation paths."""
from pathlib import Path
import hashlib,json,os
root=Path(__file__).resolve().parents[1]
pdk=Path(os.environ.get('PDKPATH',str(Path.home()/'.ciel/sky130A')))
paths=[
 'libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd.tlef',
 'libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef',
 'libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib',
 'libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds',
 'libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v',
 'libs.tech/magic/sky130A.tech','libs.tech/netgen/sky130A_setup.tcl',
 'libs.tech/openlane/rcx_rules.info',
]
record={'scope':'Exact local PDK input files; tool artifact identities are in crucible.lock.',
        'pdk_files_sha256':{p:hashlib.sha256((pdk/p).read_bytes()).hexdigest() for p in paths}}
(root/'reports/dependencies.json').write_text(json.dumps(record,indent=2)+'\n')
print('SOBEL_PDK_IDENTITIES_RECORDED',len(paths))
