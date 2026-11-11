"""Build and read back a self-contained classic Warcraft map. No game launch."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, struct
from stage import ROOT, stage, verify, write_manifest
from map_info import build_info

parser = argparse.ArgumentParser()
parser.add_argument('--name', required=True)
parser.add_argument('--test', action='store_true')
parser.add_argument('--clients', type=int, choices=range(1,7), default=1)
parser.add_argument('--ticks', type=int, default=12000)
parser.add_argument('--oos-control', action='store_true')
parser.add_argument('--suite', choices=['integration','ui','performance','hotreload','soak'], default='integration')
parser.add_argument('--dev', action='store_true')
parser.add_argument('--runtime', default='D:/WE/YDWE1.32.13正式版')
parser.add_argument('--we', default='D:/WE/KKWE_Plugin')
args = parser.parse_args()
assert args.ticks >= 3000
verify()
stage(args.name, include_tests=args.test, include_dev=args.dev)
dst = ROOT/'build'/args.name
project = json.loads((ROOT/'project.json').read_text(encoding='utf-8'))
assert not args.oos_control or (args.test and args.clients >= 2), 'OOS control requires a multiplayer test build'
config = "return {ui=true,runtime_test=%s,build_id='%s',project_id='%s',clients=%d,duration_ticks=%d,oos_control=%s}\n" % (
    str(args.test).lower(), args.name, project['id'], args.clients, args.ticks, str(args.oos_control).lower())
config=config.rstrip().removesuffix('}')+",suite='%s',dev=%s,log_folder=%s}\n" % (args.suite,str(args.dev).lower(),json.dumps(project.get('log_folder',project['id']),ensure_ascii=False))
(dst/'script/app/config.lua').write_text(config, encoding='utf-8')
write_manifest(dst)
base = ROOT/'build'/(args.name+'-map')
shutil.copytree(ROOT/'assets/map', base)
# W3I v25: version, saves, editor, then map name/author/description/player string.
w3i,bounds=build_info((base/'war3map.w3i').read_bytes(),project['title'],project['id'])
(base/'war3map.w3i').write_bytes(w3i)
loader=(ROOT/'integration/loader.j').read_text(encoding='utf-8')
slots='\n'.join(f'''call SetPlayerStartLocation(Player({i}),{i})
call ForcePlayerStartLocation(Player({i}),{i})
call SetPlayerColor(Player({i}),ConvertPlayerColor({i}))
call SetPlayerRacePreference(Player({i}),RACE_PREF_HUMAN)
call SetPlayerRaceSelectable(Player({i}),false)
call SetPlayerController(Player({i}),MAP_CONTROL_USER)''' for i in range(6))
teams='\n'.join(f'call SetPlayerTeam(Player({i}),0)' for i in range(6))
starts='\n'.join(f'call DefineStartLocation({i},{i*128}.0,0.0)' for i in range(6))
script=f'''globals
endglobals
{loader}
function InitCustomPlayerSlots takes nothing returns nothing
{slots}
endfunction
function InitCustomTeams takes nothing returns nothing
{teams}
endfunction
function config takes nothing returns nothing
call SetMapName("LuaScaffold")
call SetMapDescription("InnerJAPI Lua starter")
call SetPlayers(6)
call SetTeams(1)
call SetGamePlacement(MAP_PLACEMENT_USE_MAP_SETTINGS)
{starts}
call InitCustomPlayerSlots()
call InitCustomTeams()
endfunction
function main takes nothing returns nothing
call SetCameraBounds({','.join(f'{x:.1f}' for x in bounds)})
call InitBlizzard()
call FogEnable(false)
call FogMaskEnable(false)
call LuaScaffoldBoot()
endfunction
'''
title = project['title'].replace('\\','\\\\').replace('"','\\"').replace('\n',' ').replace('\r',' ')
script = script.replace('call SetMapName("LuaScaffold")', f'call SetMapName("{title}")')
(base/'war3map.j').write_text(script,encoding='utf-8')
we=Path(args.we)
subprocess.run([str(we/'plugin/pjass/pjass-classic.exe'),str(we/'jass/system/ht/common.j'),
                str(we/'jass/system/ht/blizzard.j'),str((base/'war3map.j').relative_to(ROOT))],cwd=ROOT,check=True)
output=ROOT/'build'/(args.name+'.w3x')
subprocess.run([str(Path(args.runtime)/'bin/lua.exe'),'tools/map_archive.lua',args.runtime,'pack',
                str(output.relative_to(ROOT)),str(base.relative_to(ROOT)),str(dst.relative_to(ROOT))],cwd=ROOT,check=True)
manifest={'map':output.name,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
          'config':vars(args),'files':[]}
for p in sorted(dst.rglob('*')):
    if p.is_file(): manifest['files'].append({'path':p.relative_to(dst).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(ROOT/'build'/(args.name+'-build.json')).write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('BUILD PASS '+output.name)
