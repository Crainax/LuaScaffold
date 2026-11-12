"""Generate only the template's declared map initialization fixtures.

Classic unit-doo 8/11 and region v5 layouts cross-checked against
flowtsohg/mdx-m3-viewer src/parsers/w3x/{unitsdoo/unit,w3r/region}.ts.
This deliberately is not a general Warcraft editor or binary roundtrip parser.
"""
from pathlib import Path
import argparse, json, struct, math, re

ROOT=Path(__file__).resolve().parents[1]
def fixtures(manifest):
    units=manifest['units'];regions=manifest['regions']
    assert len({u['key'] for u in units})==len(units)
    assert len({u['global'] for u in units})==len(units)
    doo=struct.pack('<4siii',b'W3do',8,11,len(units))
    globals_,body=[],[]
    for n,u in enumerate(units):
        assert re.fullmatch(r'gg_unit_[A-Za-z0-9_]+',u['global'])
        assert re.fullmatch(r'[A-Za-z0-9]{4}',u['rawcode'])
        assert 0<=u['owner']<=15
        x,y,angle=u['x'],u['y'],u['facing']
        record=struct.pack('<4si7fBiH',u['rawcode'].encode(),0,x,y,0,math.radians(angle),1,1,1,2,u['owner'],0)
        record+=struct.pack('<iiiiifiiiiiii',-1,-1,-1,0,125,-1.0,1,0,0,0,0,0,0)
        record+=bytes(4)+struct.pack('<iii',-1,-1,n)
        assert len(record)==111
        doo+=record
        globals_.append('unit '+u['global']+' = null')
        body.append(f"set {u['global']} = CreateUnit(Player({u['owner']}),'{u['rawcode']}',{x:.1f},{y:.1f},{angle:.1f})")
    w3r=struct.pack('<ii',5,len(regions))
    for n,r in enumerate(regions):
        assert re.fullmatch(r'gg_rct_[A-Za-z0-9_]+',r['global'])
        left,bottom,right,top=r['bounds']
        assert left<right and bottom<top
        w3r+=struct.pack('<4f',left,right,bottom,top)+r['key'].encode()+b'\0'
        w3r+=struct.pack('<i4s',n,bytes(4))+b'\0'+bytes([255,255,255,255])
        globals_.append('rect '+r['global']+' = null')
        body.append(f"set {r['global']} = Rect({left:.1f},{bottom:.1f},{right:.1f},{top:.1f})")
    return doo,w3r,'\n'.join(globals_),('function CreateMapPlacements takes nothing returns nothing\n'+'\n'.join(body)+'\nendfunction')

def process(folder,write=False):
    manifest=json.loads((folder/'placements.json').read_text(encoding='utf8'))
    doo,w3r,globals_,body=fixtures(manifest)
    scriptfile=folder/'map/war3map.j'
    script=scriptfile.read_text(encoding='utf8')
    blocks={'globals':globals_,'init':body}
    for name,content in blocks.items():
        pattern=r'// @placements:'+name+r':begin\n.*?// @placements:'+name+r':end'
        replacement='// @placements:'+name+':begin\n'+content+'\n// @placements:'+name+':end'
        updated,n=re.subn(pattern,lambda _:replacement,script,flags=re.S)
        assert n==1,'missing/duplicate placement marker: '+name
        if not write:assert updated==script,'placement JASS differs from manifest'
        script=updated
    assert script.count('call CreateMapPlacements()')==1
    assert script.index('call CreateMapPlacements()')<script.index('call LuaScaffoldBoot()')
    if write:scriptfile.write_text(script,encoding='utf8')
    for filename,data in [('war3mapUnits.doo',doo),('war3map.w3r',w3r)]:
        p=folder/'map'/filename
        if write:p.write_bytes(data)
        assert p.read_bytes()==data,'placement binary differs from manifest: '+filename
    return manifest

def lua_module(manifest):
    # Engine globals are resolved only when the map has finished its JASS init.
    quote=lambda value:json.dumps(value,ensure_ascii=True)
    lines=["local M={}","function M.resolve(j)","    local list={}"]
    for u in manifest['units']:
        lines.append("    list[#list+1]={key="+quote(u['key'])+",handle=assert(j["+quote(u['global'])+"],'missing placed unit'),owned=false}")
    lines.extend(["    return list","end","M.expected={"])
    for u in manifest['units']:
        lines.append("    {key="+quote(u['key'])+",rawcode="+quote(u['rawcode'])+",owner="+str(u['owner'])+",x="+str(u['x'])+",y="+str(u['y'])+"},")
    lines.extend(["}","function M.regions(j)","    return {"])
    for r in manifest['regions']:
        lines.append("        {key="+quote(r['key'])+",handle=assert(j["+quote(r['global'])+"],'missing map region'),bounds={"+','.join(map(str,r['bounds']))+"}},")
    lines.extend(["    }","end","return M",""])
    return '\n'.join(lines)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--write',action='store_true',help='update only declared fixture blocks/binaries')
    args=parser.parse_args()
    for name in ('MainMap','UnitTestMap'):process(ROOT/'maps'/name,args.write)
    print('MAP FIXTURE PASS explicit order, initialization hook, classic placements/regions')
