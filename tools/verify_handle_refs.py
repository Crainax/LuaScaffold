"""Verify this incremental native reference regression; old acceptance stays historical."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1];base=root/'tests/evidence'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
index=read(base/'index.json');reports=[]
for name,clients,ticks in [('refs-one-01',1,6000),('refs-three-01',3,12000),('refs-six-01',6,6000)]:
    matches=[e for e in index if e['map']==name+'.w3x'];assert len(matches)==1,name
    entry=matches[0];folder=base/entry['session']
    assert entry['status']=='PASS' and entry['cleanup'] and entry['clients']==clients
    assert read(folder/'cleanup.json')['success']
    build=read(folder/'build.json');launch=read(folder/'session.json')
    assert build['sha256'].lower()==launch['sha256'].lower()
    assert build['config']['clients']==clients and build['config']['ticks']==ticks
    payload={f['path']:f['sha256'] for f in build['files']}
    assert payload=={f['archive']:f['sha256'] for f in read(folder/'payload-manifest.json')}
    for p in (root/'src').rglob('*.lua'):
        rel=p.relative_to(root/'src').as_posix()
        if rel=='app/config.lua' or rel.startswith('dev/'):continue
        archive=rel if rel in ('plugin_main.lua','jass2binary.lua') else 'script/'+rel
        assert payload.get(archive)==sha(p),'untested source '+rel
    maproot=root/'maps'/build['map_source']
    assert build['map_sources']=={p.relative_to(maproot).as_posix():sha(p) for p in maproot.rglob('*') if p.is_file()}
    for file,key in [('w2l-lock.json','w2l_lock_sha256'),('w2l-policy.ini','w2l_policy_sha256'),('w2l-core-policy.ini','w2l_core_policy_sha256')]:
        assert sha(root/'config'/file)==build[key]
    guard=read(folder/'runtime-guard.json')
    assert guard['restored'] and guard['originalSha256'].lower()==read(base/'acceptance.json')['original_j2b_sha256']
    assert 'desync detected' not in (folder/'host-stdout.log').read_text(encoding='utf-8-sig').lower()
    peers=[];cycles=(ticks-3500)//500+1
    logs=sorted((folder/'client-logs').glob('*-P*.log'));assert len(logs)==clients
    for p in logs:
        text=p.read_text(encoding='utf-8-sig')
        assert text.count('[UT_DONE]')==1 and not re.search(r'FAIL:|\[UT_FAIL\]|\[error\]',text)
        assert text.count('PASS: unit batch references return to baseline')==100
        reuse=re.search(r'\[HANDLE_REUSE\] creates=2000 repeated_native_ids=(\d+)',text)
        assert reuse and int(reuse[1])>0,'native handle reuse not observed in this fixed run'
        assert text.count('PASS: repeat cycle handle references return to baseline')==cycles
        assert 'PASS: application handle references return to zero' in text
        rows=[tuple(map(int,m)) for m in re.findall(r'\[HANDLE_REFS\] phase=cycle active=(\d+) refs=(\d+) unrefs=(\d+) unit=(\d+) effect=(\d+) trigger=(\d+) timer=(\d+) errors=(\d+)',text)]
        assert len(rows)==cycles
        for active,refs,unrefs,unit,effect,trigger,timer,errors in rows:
            assert active==refs-unrefs==3*clients+4
            assert (unit,effect,trigger,timer,errors)==(3*clients+1,0,2,1,0)
        stopped=re.findall(r'\[HANDLE_REFS\] phase=stopped active=(\d+) refs=(\d+) unrefs=(\d+) errors=(\d+)',text)
        assert len(stopped)==1
        active,refs,unrefs,errors=map(int,stopped[0]);assert active==errors==0 and refs==unrefs and refs>2000
        states=re.findall(r'\[STATE_MATCH\] phase=(\d+) hash=(\d+)',text);assert len(states)>=10
        peers.append({'log':p.name,'assertions':text.count('PASS:'),'refs':refs,'unrefs':unrefs,'active':active,'errors':errors,'cycles':cycles,'native_ids_reused':int(reuse[1]),'states':states,'cycle_reference_rows':rows})
    assert all((p['states'],p['cycle_reference_rows'],p['refs'])==(peers[0]['states'],peers[0]['cycle_reference_rows'],peers[0]['refs']) for p in peers)
    reports.append({'map':name,'session':entry['session'],'clients':clients,'peers':peers})
report={'status':'PASS','scope':'framework explicit references, not total engine refs; fixed workload, no memory investigation','builds':reports}
(base/'verified-handle-refs.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('HANDLE REFS EVIDENCE PASS current source/payload, per-batch/per-cycle baseline, zero shutdown, peer states and cleanup')
