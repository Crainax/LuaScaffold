"""Build and read back a self-contained classic Warcraft map. No game launch."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, struct
from stage import ROOT, stage, verify, write_manifest
from lni_map import prepare, pack
from map_fixtures import process, lua_module
from w2l_runtime import verify_objects

parser = argparse.ArgumentParser()
parser.add_argument('--name', required=True)
parser.add_argument('--test', action='store_true')
parser.add_argument('--clients', type=int, choices=range(1,7), default=1)
parser.add_argument('--ticks', type=int, default=12000)
parser.add_argument('--oos-control', action='store_true')
parser.add_argument('--suite', choices=['integration','ui','performance','hotreload','soak','lifecycle','gameplay','campaign_soak','business_resource','resource_matrix'], default='integration')
parser.add_argument('--diagnostic',choices=['stages','idle','clock'])
parser.add_argument('--dev', action='store_true')
parser.add_argument('--map', choices=['MainMap','UnitTestMap'])
parser.add_argument('--format', choices=['obj','slk'], default='obj')
parser.add_argument('--runtime', default='D:/WE/YDWE1.32.13正式版')
parser.add_argument('--we', default='D:/WE/KKWE_Plugin')
args = parser.parse_args()
assert args.ticks >= 3000
assert args.suite not in ('gameplay','campaign_soak') or args.ticks>=4000,'gameplay suite needs at least 4000 ticks'
assert args.suite!='business_resource' or (args.ticks>=5000 and args.ticks%2500==0),'resource profile needs five equal phases'
assert args.suite!='resource_matrix' or (args.ticks>=11000 and args.ticks%5500==0),'resource matrix needs eleven equal phases'
assert not args.diagnostic or args.test,'diagnostics require a test build'
assert args.diagnostic!='stages' or args.clients==1,'staged diagnostic is single-client'
verify()
stage(args.name, include_tests=args.test, include_dev=args.dev)
dst = ROOT/'build'/args.name
project = json.loads((ROOT/'project.json').read_text(encoding='utf-8'))
assert not args.oos_control or (args.test and args.clients >= 2), 'OOS control requires a multiplayer test build'
config = "return {ui=true,runtime_test=%s,build_id='%s',project_id='%s',clients=%d,duration_ticks=%d,oos_control=%s}\n" % (
    str(args.test).lower(), args.name, project['id'], args.clients, args.ticks, str(args.oos_control).lower())
config=config.rstrip().removesuffix('}')+",suite='%s',dev=%s,log_folder=%s}\n" % (args.suite,str(args.dev).lower(),json.dumps(project.get('log_folder',project['id']),ensure_ascii=False))
(dst/'script/app/config.lua').write_text(config, encoding='utf-8')
fixture=None
if args.diagnostic:
    fixture=ROOT/'research'/({'stages':'resource_probe.lua','idle':'resource_idle.lua','clock':'clock_probe.lua'}[args.diagnostic])
    (dst/'script/app/main.lua').write_bytes(fixture.read_bytes())
selected_map=args.map or ('UnitTestMap' if args.test else 'MainMap')
placement_manifest=process(ROOT/'maps'/selected_map)
generated=dst/'script/world/generated_placements.lua'
assert not generated.exists(),'generated map module cannot be overridden by project source'
generated.parent.mkdir(parents=True,exist_ok=True)
generated.write_text(lua_module(placement_manifest),encoding='utf8')
write_manifest(dst)
work=prepare(selected_map,args.name,dst,project)
output=ROOT/'build'/(args.name+'.w3x')
pack(work,output,args.name,args.format)
verify_objects(work,output,ROOT/'build'/(args.name+'-objects.log'))
packed_script=ROOT/'build'/(args.name+'-packed.j')
subprocess.run([str(Path(args.runtime)/'bin/lua.exe'),'tools/verify_payload.lua',args.runtime,
                str(output),str(dst),str(packed_script),str(work/'map')],cwd=ROOT,check=True)
we=Path(args.we)
subprocess.run([str(we/'plugin/pjass/pjass-classic.exe'),str(we/'jass/system/ht/common.j'),
                str(we/'jass/system/ht/blizzard.j'),str(packed_script.relative_to(ROOT))],cwd=ROOT,check=True)
manifest={'map':output.name,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
          'config':vars(args),'map_source':selected_map,'w2l_lock_sha256':hashlib.sha256((ROOT/'config/w2l-lock.json').read_bytes()).hexdigest(),
          'w2l_policy_sha256':hashlib.sha256((ROOT/'config/w2l-policy.ini').read_bytes()).hexdigest(),
          'w2l_core_policy_sha256':hashlib.sha256((ROOT/'config/w2l-core-policy.ini').read_bytes()).hexdigest(),
          'map_sources':{p.relative_to(ROOT/'maps'/selected_map).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in sorted((ROOT/'maps'/selected_map).rglob('*')) if p.is_file()},'files':[]}
for p in sorted(dst.rglob('*')):
    if p.is_file(): manifest['files'].append({'path':p.relative_to(dst).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
if fixture:
    manifest['config']['resource_probe']=args.diagnostic
    manifest['fixture']={'path':fixture.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(fixture.read_bytes()).hexdigest()}
(ROOT/'build'/(args.name+'-build.json')).write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('BUILD PASS '+output.name)
