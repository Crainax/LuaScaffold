"""Second-round acceptance. Original baseline reports remain historical, not rewritten."""
from pathlib import Path
from datetime import datetime
import hashlib,json,re
from framework_package import PUBLIC,digest
root=Path(__file__).resolve().parents[1];base=root/'tests/evidence'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
index=read(base/'index.json');accept=read(base/'acceptance-round2.json')
old=read(base/'acceptance.json')
explained={**old['explained_failures'],**accept['explained_failures']}
for e in index:
    assert e['cleanup'] and e['status'] in ('PASS','FAIL'),'unfinished/unclean: '+e['session']
    if e['status']=='FAIL' and e['message']!='OOS detected by ydhost':
        assert e['session'] in explained,'unexplained failure: '+e['session']
reports=[];all_checked=set()
business_markers=[
 'three Lua hero skills complete native challenge once',
 'real transport sender cannot control another actor',
 'stale target commands rejected after native handle retirement',
 'rejected repeated start cannot replenish or heal',
 'native actor death cancels active cast immediately',
 'cancelled windup produces no late damage',
 'target removal ends encounter and pending channel',
 'native ownership event cancels cast',
 'native type change cancels Lua skill and owned effect',
 'preparation rollback destroys real allocated effect',
 'failed preparation commits neither energy nor cooldown',
 'business registrations, tasks, effects and sessions return to zero',
 'application root closes shared native bridge',
 'retained cancelled tokens release removed native unit records',
 'native transport cast rejected when energy is exhausted',
 'revived target retains ID but does not revive cancelled cast',
 'target revival cannot reactivate delayed damage',
 'simulated departure releases real owned units casts and effects but preserves borrowed placement',
 'departed player requests rejected and departure cleanup is idempotent',
 'bounded native queue rejects request beyond capacity',
 'drained native queue revalidates stale targets instead of granting queued success']
for spec in accept['required']:
    found=[e for e in index if e['map']==spec['map']];assert len(found)==1,spec['map']
    e=found[0];folder=base/e['session'];build=read(folder/'build.json');launch=read(folder/'session.json')
    assert e['clients']==spec['clients']==build['config']['clients']
    assert build['sha256'].lower()==launch['sha256'].lower()
    guard=read(folder/'runtime-guard.json')
    assert guard['restored'] and guard['originalSha256'].lower()==old['original_j2b_sha256']
    for file,key in [('w2l-lock.json','w2l_lock_sha256'),('w2l-policy.ini','w2l_policy_sha256'),('w2l-core-policy.ini','w2l_core_policy_sha256')]:
        assert sha(root/'config'/file)==build[key],file
    maproot=root/'maps'/build['map_source']
    assert {p.relative_to(maproot).as_posix():sha(p) for p in maproot.rglob('*') if p.is_file()}==build['map_sources']
    payload={i['path']:i['sha256'] for i in build['files']}
    manifest={i['archive']:i['sha256'] for i in read(folder/'payload-manifest.json')}
    assert payload==manifest,'payload manifests disagree'
    checked=set()
    for source in (root/'src').rglob('*.lua'):
        relative=source.relative_to(root/'src').as_posix()
        if relative=='app/config.lua' or (relative.startswith('dev/') and not build['config']['dev']):continue
        archive=relative if relative in ('plugin_main.lua','jass2binary.lua') else 'script/'+relative
        if spec.get('diagnostic') and relative=='app/main.lua':continue
        assert payload.get(archive)==sha(source),'current source not tested: '+relative+' '+spec['map']
        checked.add(relative)
    all_checked.update(checked)
    host=(folder/'host-stdout.log').read_text(encoding='utf-8-sig')
    logs=sorted((folder/'client-logs').glob('*-P*.log'));assert len(logs)==e['clients']
    if spec.get('oos_control'):
        assert e['status']=='FAIL' and e['message']=='OOS detected by ydhost' and 'desync detected' in host.lower()
        assert any('[CONTROL] deliberate RNG divergence injected' in p.read_text(encoding='utf-8-sig') for p in logs)
        reports.append({'map':e['map'],'session':e['session'],'expected_oos_detected':True,'source_files':len(checked)});continue
    assert e['status']=='PASS' and 'desync detected' not in host.lower()
    peers=[]
    for p in logs:
        business_data=None
        text=p.read_text(encoding='utf-8-sig')
        assert text.count('[UT_DONE]')==1 and text.count('[LuaScaffold] BOOT')==1
        assert 'FAIL:' not in text and '[UT_FAIL]' not in text and '[error]' not in text
        assertions=text.count('PASS:');assert assertions>0
        states=re.findall(r'\[STATE_MATCH\] phase=(\d+) hash=(\d+)',text)
        assert len(states)>=3
        if spec.get('business'):
            for marker in business_markers:assert 'PASS: '+marker in text,(p.name,marker)
            assert '[UNIT_LIFECYCLE_DONE]' in text and '[NATIVE_CALLBACK_GC] retained=0/8' in text
            match=re.search(r'\[BUSINESS_DONE\] cycles=(\d+) commands=(\d+) rejected=(\d+) effects_created=(\d+) damage_calls=(\d+)',text);assert match
            expected=(build['config']['ticks']-3500)//500+1
            assert int(match[1])==expected
            business_data=[int(v) for v in match.groups()]
        if spec.get('resource'):
            assert '[RESOURCE_BUSINESS_DONE] cycles=24 ticks=30000' in text
            assert re.findall(r'\[RESOURCE_PROFILE\] tag=begin phase=(\S+)',text)==['idle1','work1','idle2','work2','recovery']
            for marker in ['both workload phases completed the exact same fixed cycle count','resource profile final registrations are zero','resource profile final UI count is zero','resource profile application bridge closes']:
                assert 'PASS: '+marker in text
        if spec.get('research'):
            for marker in ['file watcher loads initial view','file watcher rejects syntax and preserves view','file watcher recovers on valid edit','file watcher stop clears view','reload success and failure return resources to baseline','reloaded views release closure payloads']:
                assert 'PASS: '+marker in text
            samples={}
            for name,sample in re.findall(r'\[BENCH\] name=(\S+) n=\d+ sample=(\d+)',text):samples.setdefault(name,[]).append(int(sample))
            assert len(samples)==9 and all(sorted(v)==[1,2,3,4,5] for v in samples.values())
        if spec.get('matrix'):
            assert '[RESOURCE_MATRIX_DONE] cycles=12 ticks=33000' in text
            assert re.findall(r'\[RESOURCE_PROFILE\] tag=begin phase=(\S+)',text)==['idle','units','rest_units','events_tasks','rest_events','ui_updates','rest_ui','skills','rest_skills','combined','recovery']
            for marker in ['isolated and combined profiles execute equal bounded batch counts','isolated event and task work completes without retained registrations','resource profile final registrations are zero','resource profile final UI count is zero']:
                assert 'PASS: '+marker in text
        boot=re.search(r'^(\S+ \S+) \[info\]: \[LuaScaffold\] BOOT',text,re.M)
        done=re.search(r'^(\S+ \S+) \[info\]: \[UT_DONE\]',text,re.M)
        elapsed=(datetime.fromisoformat(done[1])-datetime.fromisoformat(boot[1])).total_seconds()
        assert elapsed>=spec.get('minimum_wall_seconds',0)
        peers.append({'log':p.name,'assertions':assertions,'wall_seconds':elapsed,'states':states,'business_totals':business_data})
    assert all(p['states']==peers[0]['states'] for p in peers),'peer snapshot mismatch'
    assert all(p['business_totals']==peers[0]['business_totals'] for p in peers),'peer final business counters differ'
    if spec.get('minimum_wall_seconds'):
        rows=[json.loads(s) for s in (folder/'resources.jsonl').read_text(encoding='utf-8-sig').splitlines()]
        identities={(r['player'],r['pid']) for r in rows};assert len(identities)==e['clients']
        for player,pid in identities:
            times=sorted(datetime.fromisoformat(r['utc'].replace('Z','+00:00')) for r in rows if r['pid']==pid)
            assert (times[-1]-times[0]).total_seconds()>=spec['minimum_wall_seconds']
            assert len(times)>=100
    reports.append({'map':e['map'],'session':e['session'],'source_files':len(checked),'peers':peers})
expected={p.relative_to(root/'src').as_posix() for p in (root/'src').rglob('*.lua')}-{'app/config.lua'}
assert all_checked==expected,'source coverage incomplete'
for filename in ['reuse-check.json','dependency-upgrade.json','build-negative.json','independent-example.json']:
    assert read(base/filename)['status']=='PASS',filename
example=read(base/'independent-example.json')
assert example['runtime_source_sha256']=={p.relative_to(root/'src').as_posix():sha(p) for p in (root/'src').rglob('*.lua')},'independent example is stale'
public_files={p.relative_to(root).as_posix():sha(p) for prefix in PUBLIC for p in (root/prefix).rglob('*') if p.is_file()}
public_version=digest(public_files)
assert example['framework_lock']['version']==public_version,'independent dependency differs'
# The A/B fixture adds exactly one module. Reconstruct its content identities,
# allowing the native newline used by the recorded Python fixture writer.
upgrade_versions=read(base/'dependency-upgrade.json')['versions']
expected_upgrades=[]
for newline in ('\n','\r\n'):
    versions=[]
    for label in ('A','B','A'):
        fixture=dict(public_files)
        fixture['src/scaffold/revision_probe.lua']=hashlib.sha256(("return '"+label+"'"+newline).encode()).hexdigest()
        versions.append(digest(fixture))
    expected_upgrades.append(versions)
assert upgrade_versions in expected_upgrades,'dependency upgrade tested stale public runtime'
output={'status':'PASS','required':reports,'current_runtime_sources_verified':len(all_checked),
        'public_content_version':public_version,'dependency_fixture_versions_verified':upgrade_versions,
        'all_recorded_sessions_cleaned':True,'explained_failures':explained,
        'limits':['fixed runtime and workload only','mock failures distinguished from native probes','no physical input/pixel acceptance','no cross-machine/platform/disconnect certification']}
(base/'verified-round2.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('ROUND2 EVIDENCE PASS exact Lua/maps/tool policies, peer states, business cleanup, OOS, wall duration and owned process cleanup')
