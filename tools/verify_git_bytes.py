"""After staging, ensure hash-sensitive files survive Git checkout byte-for-byte."""
from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[1]
fmt=subprocess.check_output(['git','rev-parse','--show-object-format'],cwd=root,text=True).strip()
assert fmt=='sha1','update object hashing for this repository format'
entries=subprocess.check_output(['git','ls-files','--stage','-z'],cwd=root).split(b'\0')
staged={}
for item in entries:
    if not item:continue
    metadata,name=item.split(b'\t',1);mode,oid,stage=metadata.split()
    assert stage==b'0','unmerged index'
    staged[name.decode('utf8')]=oid.decode()
count=0
for prefix in ['src','vendor','maps','config','tests/evidence']:
    for p in sorted((root/prefix).rglob('*')):
        if not p.is_file():continue
        name=p.relative_to(root).as_posix();data=p.read_bytes()
        actual=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        assert staged.get(name)==actual,'index differs or file unstaged: '+name
        count+=1
print('GIT BYTE CHECK PASS',count,'hash-sensitive files match staged blobs exactly')
