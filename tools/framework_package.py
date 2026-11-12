"""Content-locked public runtime snapshots; no implicit branch following."""
from pathlib import Path
import argparse, hashlib, json, subprocess, shutil

ROOT=Path(__file__).resolve().parents[1]
PUBLIC=('src/scaffold','src/ui','src/game','vendor/war3ui-1.49-9')

def digest(files):
    return hashlib.sha256(json.dumps(files,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def export(source,destination):
    assert not destination.exists(), 'dependency destination already exists'
    files={}
    for prefix in PUBLIC:
        for p in sorted((source/prefix).rglob('*')):
            if p.is_file():files[p.relative_to(source).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    assert files and 'src/scaffold/scheduler.lua' in files
    revision=None;dirty=None
    if (source/'.git').exists():
        revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip()
        dirty=bool(subprocess.check_output(['git','status','--porcelain','--',*PUBLIC],cwd=source))
    lock={'schema':1,'version':digest(files),'origin_commit':revision,'origin_public_dirty':dirty,'files':files}
    destination.mkdir(parents=True)
    for name in files:
        target=destination/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source/name,target)
    (destination/'package-lock.json').write_text(json.dumps(lock,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    verify(destination,lock['version'])
    return lock

def verify(folder,expected):
    lock=json.loads((folder/'package-lock.json').read_text(encoding='utf-8'))
    assert lock['schema']==1 and lock['version']==expected==digest(lock['files']), 'dependency identity mismatch'
    actual={p.relative_to(folder).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
            for p in folder.rglob('*') if p.is_file() and p!=folder/'package-lock.json'}
    assert actual==lock['files'], 'dependency has changed, missing or extra files'
    return lock

def resolve(root):
    lockfile=root/'framework.lock.json'
    if not lockfile.exists():return root
    lock=json.loads(lockfile.read_text(encoding='utf-8'))
    folder=(root/lock['path']).resolve()
    assert folder.is_relative_to(root.resolve()/'deps'), 'dependency must be inside project deps'
    verify(folder,lock['version'])
    return folder

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('destination',type=Path)
    args=parser.parse_args()
    result=export(ROOT,args.destination.resolve())
    print('FRAMEWORK SNAPSHOT',result['version'])
