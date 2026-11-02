"""Independent matrix-kernel oracle compared with compiled C, then frozen vectors."""
from pathlib import Path
import ctypes,random,hashlib,json
root=Path(__file__).resolve().parents[1]
lib=ctypes.CDLL(str(root/'build/sobel.so'))
function=lib.sobel3x3;function.argtypes=[ctypes.c_uint8]*9;function.restype=ctypes.c_uint8
kx=((-1,0,1),(-2,0,2),(-1,0,1));ky=((-1,-2,-1),(0,0,0),(1,2,1))
def oracle(pixels):
    gradients=[sum(pixels[3*r+c]*kernel[r][c] for r in range(3) for c in range(3)) for kernel in (kx,ky)]
    return min(255,sum(abs(g) for g in gradients))
cases=[[v]*9 for v in (0,1,31,127,128,254,255)]
for index in range(9):
    for value in (1,31,255):
        p=[0]*9;p[index]=value;cases.append(p)
for direction in (0,1):
    for value in (1,7,31,255):
        cases.append([value if (r if direction else c)>=1 else 0 for r in range(3) for c in range(3)])
rng=random.Random(0x50BE1)
cases += [[rng.randrange(32) for _ in range(9)] for _ in range(4096)]
cases += [[rng.randrange(256) for _ in range(9)] for _ in range(1024)]
lines=[];hist={}
for i,p in enumerate(cases):
    expected=oracle(p);actual=function(*p)
    assert actual==expected,(i,p,expected,actual)
    packed=sum(v<<(8*j) for j,v in enumerate(p)) | (expected<<72)
    lines.append(f'{packed:020x}')
    hist[expected]=hist.get(expected,0)+1
path=root/'reference/vectors.mem';path.write_text('\n'.join(lines)+'\n')
(root/'reference/vector_count.vh').write_text(f'localparam integer VECTOR_COUNT={len(lines)};\n')
bad=lines.copy();bad[0]=f'{1<<72:020x}';(root/'reference/corrupt_expected.mem').write_text('\n'.join(bad)+'\n')
record=dict(vectors=len(lines),distinct_outputs=len(hist),unsaturated=sum(count for value,count in hist.items() if value<255),
            seed='0x50BE1',contract='min(255, abs(Sobel gx)+abs(Sobel gy)); uint8 input; signed int intermediates',
            source_sha256=hashlib.sha256((root/'src/sobel.c').read_bytes()).hexdigest(),
            vectors_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),histogram=hist)
(root/'reports/reference.json').write_text(json.dumps(record,indent=2)+'\n')
print('SOBEL_C_REFERENCE_VERIFIED',len(lines),'vectors;',len(hist),'distinct results')
