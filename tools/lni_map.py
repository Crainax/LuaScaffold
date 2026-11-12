"""Build a fresh LNI working tree, preserving map-owned initialization."""
from pathlib import Path
import shutil, json, re
from w2l_runtime import invoke, runtime
from map_fixtures import process

ROOT=Path(__file__).resolve().parents[1]

def prepare(map_name, name, payload, project):
    assert map_name in ('MainMap','UnitTestMap')
    source=ROOT/'maps'/map_name
    process(source)
    work=ROOT/'build'/(name+'-lni')
    assert not work.exists(), 'LNI working tree already exists'
    shutil.copytree(source,work)
    script_path=work/'map/war3map.j'
    script=script_path.read_text(encoding='utf-8')
    marker='// @scaffold:boot-definition'
    assert script.count(marker)==1 and script.count('call LuaScaffoldBoot()')==1, 'map must have exactly one explicit boot hook'
    script=script.replace(marker,(ROOT/'integration/loader.j').read_text(encoding='utf-8'))
    title=project['title'].replace('\\','\\\\').replace('"','\\"').replace('\r',' ').replace('\n',' ')
    assert script.count('call SetMapName("LuaScaffold")')==1
    script=script.replace('call SetMapName("LuaScaffold")','call SetMapName("'+title+'")')
    info=work/'table/w3i.ini'
    data=info.read_text(encoding='utf-8')
    data,n=re.subn(r'^地图名称 = .*$',lambda _: '地图名称 = '+json.dumps(project['title'],ensure_ascii=False),data,flags=re.M)
    assert n==1
    info.write_text(data,encoding='utf-8')
    # Source map owns all other functions, regions, placements and initialization order.
    script_path.write_text(script,encoding='utf-8')
    for p in payload.rglob('*'):
        if not p.is_file():continue
        # w2l classifies by extension before stripping the LNI directory prefix.
        # A texture under map/ would otherwise be packed as map/core/foo.blp.
        category=('resource' if p.suffix.lower() in ('.mdx','.mdl','.blp','.tga','.dds','.tif')
                  else 'sound' if p.suffix.lower() in ('.mp3','.wav') else 'map')
        target=work/category/p.relative_to(payload)
        assert not target.exists(), 'map/framework archive collision: '+str(target)
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(p,target)
    return work

def pack(work, output, name, mode='obj'):
    assert mode in ('obj','slk') and not output.exists()
    result=invoke([mode,work,output])
    (ROOT/'build'/(name+'-w2l.log')).write_bytes(result.stdout+result.stderr)
    tool=runtime()
    report=tool/'log/report.log'
    if report.exists():shutil.copy2(report,ROOT/'build'/(name+'-w2l-report.log'))
    result.check_returncode()
    assert b'[W2L_EXIT] success' in result.stdout or b'[W2L_EXIT] warning' in result.stdout
    assert output.is_file() and output.stat().st_size>0, 'w3x2lni produced no map'
