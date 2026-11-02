"""Extract unchanged used cell modules from the installed official PDK models."""
from pathlib import Path
import os,re,json,hashlib
root=Path.cwd()
hd=Path(os.environ['PDKPATH'])/'libs.ref/sky130_fd_sc_hd'
source=hd/'verilog/sky130_fd_sc_hd.v'
text=(root/'build/preprocessed_cells.v').read_text()
netlist='\n'.join(p.read_text() for p in (root/'build/mapped.v',root/'build/routed.v') if p.is_file())
used=set(re.findall(r'\b(sky130_fd_sc_hd__\w+)\s+\S+\s*\(',netlist))
modules={}
for name,body in re.findall(r'(?m)^(module\s+(sky130_fd_sc_hd__\w+)\s*\(.*?^endmodule\b[^\n]*)',text,re.S|re.M):
    assert body not in modules,body
    modules[body]=name
pending=list(used);chosen={}
while pending:
    name=pending.pop()
    if name in chosen: continue
    assert name in modules,name
    body=modules[name];chosen[name]=body
    pending.extend(n for n in re.findall(r'\bsky130_fd_sc_hd__\w+',body) if n!=name and n in modules)
chunks=[chosen[n] for n in sorted(chosen)]
out='`timescale 1ns/1ps\n`define UNIT_DELAY #0\n'+'\n\n'.join(chunks)+'\n'
(root/'build/simulation_cells.v').write_text(out)
record={'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'cell_modules':sorted(used),'dependency_modules':sorted(chosen),'extracted_sha256':hashlib.sha256(out.encode()).hexdigest(),
        'scope':'Unchanged used module bodies; FUNCTIONAL simulation and UNIT_DELAY #0. Unrelated malformed module excluded.'}
(root/'reports/simulation_models.json').write_text(json.dumps(record,indent=2)+'\n')
print('SOBEL_USED_MODELS_EXTRACTED',len(used))
