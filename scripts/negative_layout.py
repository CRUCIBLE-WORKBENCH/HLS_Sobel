"""Disconnect one result flip-flop output in a scratch LVS reference."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'build/routed_power.v').read_text()
needle='.Q(result[0])'
assert source.count(needle)==1
(root/'build/disconnected_result.v').write_text(source.replace(needle,'.Q(deliberately_disconnected_result)',1))
print('SOBEL_RESULT_CONNECTION_MUTATED')
