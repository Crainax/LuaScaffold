from pathlib import Path
import json, shutil

root=Path(__file__).resolve().parents[1]
sessions=Path('D:/War3/tools/LanTest/sessions')
dest=root/'tests/evidence'
dest.mkdir(exist_ok=True)
index=[]
for folder in sorted(sessions.iterdir()):
    file=folder/'session.json'
    if not file.is_file(): continue
    manifest=json.loads(file.read_text(encoding='utf-8-sig'))
    source=Path(manifest.get('sourceMap',''))
    if source.parent != root/'build': continue
    out=dest/folder.name
    out.mkdir(exist_ok=True)
    for name in ('session.json','result.json','cleanup.json','host-stdout.log','host-stderr.log','resources.jsonl'):
        if (folder/name).exists(): shutil.copy2(folder/name,out/name)
    if (folder/'client-logs').exists(): shutil.copytree(folder/'client-logs',out/'client-logs',dirs_exist_ok=True)
    build=root/'build'/(source.stem+'-build.json')
    if build.exists():
        shutil.copy2(build,out/'build.json')
        metadata=json.loads(build.read_text(encoding='utf-8'))
        if metadata.get('config',{}).get('resource_probe'):
            fixture=root/'build'/source.stem/'script/app/main.lua'
            if fixture.exists():shutil.copy2(fixture,out/'fixture.lua')
    guard=root/'build'/(source.stem+'-runtime-guard.json')
    if guard.exists(): shutil.copy2(guard,out/'runtime-guard.json')
    result=json.loads((out/'result.json').read_text(encoding='utf-8-sig')) if (out/'result.json').exists() else {}
    cleanup=json.loads((out/'cleanup.json').read_text(encoding='utf-8-sig')) if (out/'cleanup.json').exists() else {}
    index.append({'session':folder.name,'map':source.name,'clients':manifest['clients'],
                  'status':result.get('status','INCOMPLETE'),'message':result.get('message'), 'cleanup':cleanup.get('success',False)})
(dest/'index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('COLLECTED',len(index),'owned sessions')
