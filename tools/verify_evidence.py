"""Independent acceptance: peer evidence, OOS control, cleanup, wall duration and source hashes."""
from pathlib import Path
from datetime import datetime
import hashlib,json,re
root=Path(__file__).resolve().parents[1];base=root/'tests/evidence'
index=json.loads((base/'index.json').read_text(encoding='utf-8'))
accept=json.loads((base/'acceptance.json').read_text(encoding='utf-8'))
reports=[];controls=[];failures=[];diagnostics=[]
for entry in index:
 folder=base/entry['session']
 assert entry['cleanup'], 'cleanup incomplete: '+entry['session']
 assert entry['status'] in ('PASS','FAIL'), 'unfinished session: '+entry['session']
 host=(folder/'host-stdout.log').read_text(encoding='utf-8-sig') if (folder/'host-stdout.log').exists() else ''
 if entry['status']=='FAIL':
  if entry['message']=='OOS detected by ydhost':
   assert 'desync detected' in host.lower()
   logs=list((folder/'client-logs').glob('*.log'))
   assert any('[CONTROL] deliberate RNG divergence injected' in p.read_text(encoding='utf-8-sig') for p in logs)
   controls.append(entry['map'])
  else:
   assert entry['session'] in accept['explained_failures'],'unexplained failure: '+entry['session']
   failures.append({'session':entry['session'],'reason':accept['explained_failures'][entry['session']]})
  continue
 logs=sorted((folder/'client-logs').glob('*.log'));assert len(logs)==entry['clients']
 build=json.loads((folder/'build.json').read_text(encoding='utf-8')) if (folder/'build.json').exists() else {}
 if build:
  launched=json.loads((folder/'session.json').read_text(encoding='utf-8-sig'))
  assert build['sha256'].lower()==launched['sha256'].lower(),'build/launch map hash mismatch'
 if build.get('config',{}).get('resource_probe'):
  profile=build['config']['resource_probe']
  is_idle=profile=='idle'
  is_clock=profile=='clock'
  if not is_idle and not is_clock:assert entry['clients']==1
  native_clocks=[]
  for log in logs:
   text=log.read_text(encoding='utf-8-sig')
   marker='[CLOCK_NATIVE_DONE]' if is_clock else ('[RESOURCE_IDLE_DONE] ticks=75000 clients='+str(entry['clients']) if is_idle else '[RESOURCE_PROFILE_DONE] all phases complete')
   assert marker in text and text.count('[UT_DONE]')==1 and text.count('[LuaScaffold] BOOT')==1
   assert 'PASS:' in text and 'FAIL:' not in text and '[error]' not in text and 'desync detected' not in host.lower()
   if is_clock:
    values=re.findall(r'\[CLOCK_NATIVE\] native_seconds=(\d+) shared_ticks=(\d+)',text)
    assert [v[0] for v in values]==['5','10','15'];native_clocks.append(values)
   else:
    assert re.findall(r'\[RESOURCE_PROFILE\] tag=end phase=(\S+)',text)==(['idle'] if is_idle else ['idle','units','ui_without_edit','ui_with_edit','recovery'])
  if is_clock:assert all(values==native_clocks[0] for values in native_clocks),'native clock peer counts differ'
  fixture=build['fixture'];assert hashlib.sha256((root/fixture['path']).read_bytes()).hexdigest()==fixture['sha256']
  assert next(i['sha256'] for i in build['files'] if i['path']=='script/app/main.lua')==fixture['sha256']
  assert hashlib.sha256((folder/'fixture.lua').read_bytes()).hexdigest()==fixture['sha256']
  guard=json.loads((folder/'runtime-guard.json').read_text(encoding='utf-8-sig'))
  assert guard['restored'] and guard['originalSha256'].lower()==accept['original_j2b_sha256']
  diagnostics.append({'session':entry['session'],'map':entry['map'],'fixture_hash_verified':True})
  continue
 peers=[]
 for file in logs:
  text=file.read_text(encoding='utf-8-sig')
  assert text.count('[LuaScaffold] BOOT')==1 and text.count('[UT_DONE]')==1
  assert 'FAIL:' not in text and '[UT_FAIL]' not in text and '[error]' not in text
  assert '[NATIVE_CALLBACK_GC] retained=0/8' in text
  states=re.findall(r'\[STATE_MATCH\] phase=(\d+) hash=(\d+) rng=(\d+)',text)
  metrics=re.search(r'\[METRICS\] ui_cycles=(\d+) rng_calls=(\d+) phases=(\d+) assertions=(\d+)',text)
  assert metrics and len(states)==int(metrics[3]) and len(states)>=3
  boot=re.search(r'^(\S+ \S+) \[info\]: \[LuaScaffold\] BOOT',text,re.M)
  done=re.search(r'^(\S+ \S+) \[info\]: \[UT_DONE\]',text,re.M)
  elapsed=(datetime.fromisoformat(done[1])-datetime.fromisoformat(boot[1])).total_seconds()
  peers.append({'log':file.name,'states':states,'ui_cycles':int(metrics[1]),'rng_calls':int(metrics[2]),
   'phases':int(metrics[3]),'assertions':int(metrics[4]),'wall_seconds':elapsed})
 assert all(p['states']==peers[0]['states'] for p in peers),'cross-client state mismatch'
 assert 'desync detected' not in host.lower()
 reports.append({'session':entry['session'],'map':entry['map'],'clients':entry['clients'],'peers':peers})

required=[]
for spec in accept['required']:
 found=[e for e in index if e['map']==spec['map']]
 assert len(found)==1,'required map missing or ambiguous: '+spec['map']
 entry=found[0];folder=base/entry['session'];assert entry['clients']==spec['clients']
 if spec.get('oos_control'):
  assert entry['map'] in controls
 else:
  assert entry['status']=='PASS'
  report=next(r for r in reports if r['session']==entry['session'])
  for log in (folder/'client-logs').glob('*.log'):
   text=log.read_text(encoding='utf-8-sig')
   for marker in spec.get('markers',[]):
    assert marker in text,'required probe missing: '+log.name+' '+marker
   if spec.get('benchmark'):
    samples={}
    for name,sample in re.findall(r'\[BENCH\] name=(\S+) n=\d+ sample=(\d+)',text):
     samples.setdefault(name,[]).append(int(sample))
    assert set(samples)=={'empty_loop','closure_capture','empty_table','table_4_fields','concat_unique_short',
     'string_equal_existing','events_100_listeners','scheduler_1000_idle','native_text_update'}
    assert all(sorted(values)==[1,2,3,4,5] for values in samples.values())
    assert '[ALLOC] name=closure_capture n=10000' in text and '[ALLOC] name=empty_table n=10000' in text
  if spec.get('minimum_wall_seconds'):
   assert all(p['wall_seconds']>=spec['minimum_wall_seconds'] for p in report['peers'])
   samples=[json.loads(line) for line in (folder/'resources.jsonl').read_text(encoding='utf-8-sig').splitlines()]
   process_ids={s['pid'] for s in samples};assert len(process_ids)==spec['clients']
   for pid in process_ids:
    times=sorted(datetime.fromisoformat(s['utc'].replace('Z','+00:00')) for s in samples if s['pid']==pid)
    assert (times[-1]-times[0]).total_seconds()>=spec['minimum_wall_seconds']
   for log in (folder/'client-logs').glob('*.log'):
    text=log.read_text(encoding='utf-8-sig')
    assert len(re.findall(r'\[RESOURCE\] tick=',text))>=30
    assert text.count('PASS: reload success and failure return resources to baseline')>=30
 guard=json.loads((folder/'runtime-guard.json').read_text(encoding='utf-8-sig'))
 assert guard['restored'] and guard['originalSha256'].lower()==accept['original_j2b_sha256']
 build=json.loads((folder/'build.json').read_text(encoding='utf-8'))
 launched=json.loads((folder/'session.json').read_text(encoding='utf-8-sig'))
 assert build['sha256'].lower()==launched['sha256'].lower(),'required build/launch map hash mismatch'
 checked=set()
 for item in build['files']:
  path=item['path']
  if path=='script/app/config.lua':continue
  relative=path.removeprefix('script/');source=root/'src'/relative
  if source.is_file():
   assert hashlib.sha256(source.read_bytes()).hexdigest()==item['sha256'],'source differs from tested build: '+relative
   checked.add(relative)
 if build['config']['dev']:
  expected={p.relative_to(root/'src').as_posix() for p in (root/'src').rglob('*.lua') if p.relative_to(root/'src').as_posix()!='app/config.lua'}
  assert checked==expected,'new or missing source was not tested'
 required.append({'map':entry['map'],'session':entry['session'],'source_hashes_verified':len(checked)})
assert set(accept.get('resource_diagnostics_required',[])) <= {d['map'] for d in diagnostics}
output={'normal_sessions':reports,'oos_controls':controls,'explained_failures':failures,'required':required,
 'resource_diagnostics':diagnostics,
 'all_recorded_sessions_cleaned':True,'final_lua_matches_required_builds':True}
(base/'verified-summary.json').write_text(json.dumps(output,indent=2)+'\n',encoding='utf-8')
print('EVIDENCE PASS: all required peers, OOS detector, 30min wall duration, cleanup, guards and exact Lua hashes')
