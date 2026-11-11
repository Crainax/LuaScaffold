"""Build a labelled, single-client diagnostic fixture without changing runtime sources."""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys
from stage import ROOT,write_manifest
parser=argparse.ArgumentParser();parser.add_argument('--name',required=True)
parser.add_argument('--profile',choices=['stages','idle','clock'],default='stages')
parser.add_argument('--clients',type=int,choices=range(1,7),default=1);args=parser.parse_args()
assert args.profile!='stages' or args.clients==1, 'Staged fixture is single-client'
subprocess.run([sys.executable,'tools/build.py','--name',args.name,'--clients',str(args.clients)],cwd=ROOT,check=True)
dst=ROOT/'build'/args.name
fixture=ROOT/'research'/({'stages':'resource_probe.lua','idle':'resource_idle.lua','clock':'clock_probe.lua'}[args.profile])
(dst/'script/app/main.lua').write_bytes(fixture.read_bytes())
write_manifest(dst)
output=ROOT/'build'/(args.name+'.w3x')
# Existing map belongs to this invocation; archive tool creates a fresh replacement.
output.unlink()
runtime='D:/WE/YDWE1.32.13正式版'
subprocess.run([str(Path(runtime)/'bin/lua.exe'),'tools/map_archive.lua',runtime,'pack',
 str(output.relative_to(ROOT)),f'build/{args.name}-map',str(dst.relative_to(ROOT))],cwd=ROOT,check=True)
manifest_path=ROOT/'build'/(args.name+'-build.json')
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['sha256']=hashlib.sha256(output.read_bytes()).hexdigest()
manifest['config']['resource_probe']=args.profile
manifest['fixture']={'path':fixture.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(fixture.read_bytes()).hexdigest()}
manifest['files']=[{'path':p.relative_to(dst).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
 for p in sorted(dst.rglob('*')) if p.is_file()]
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('DIAGNOSTIC MAP READY:',output.name)
