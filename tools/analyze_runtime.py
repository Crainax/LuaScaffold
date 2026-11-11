"""Summarize recorded native measurements without converting timing noise to FPS claims."""
from pathlib import Path
from datetime import datetime,timedelta,timezone
import argparse,json,re,statistics
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--session',required=True)
parser.add_argument('--log-utc-offset',type=float,default=8);args=parser.parse_args()
folder=root/'tests/evidence'/args.session
assert folder.parent==root/'tests/evidence' and folder.is_dir()
report={'session':args.session,'peers':[],'processes':[],'resource_profile':[]}
profile_bounds={}
for file in sorted((folder/'client-logs').glob('*.log')):
 text=file.read_text(encoding='utf-8-sig');bench={}
 player_match=re.search(r'-P(\d+)\.log$',file.name)
 player='LanP'+player_match[1] if player_match else file.name
 for name,n,sample,seconds,heap in re.findall(r'\[BENCH\] name=(\S+) n=(\d+) sample=(\d+) seconds=([\d.]+) heap_delta_kib=(-?[\d.]+)',text):
  rec=bench.setdefault(name,{'iterations':int(n),'seconds':[],'heap_delta_kib':[]})
  assert rec['iterations']==int(n)
  rec['seconds'].append(float(seconds));rec['heap_delta_kib'].append(float(heap))
 for rec in bench.values():
  rec['median_ms']=statistics.median(rec['seconds'])*1000
  rec['min_ms']=min(rec['seconds'])*1000;rec['max_ms']=max(rec['seconds'])*1000
 resources=[dict(zip(['tick','lua_kib','controls','ui_tasks','events'],[int(t),float(k),int(c),int(q),int(e)]))
  for t,k,c,q,e in re.findall(r'\[RESOURCE\] tick=(\d+) lua_kib=([\d.]+) controls=(\d+) ui_tasks=(\d+) events=(\d+)',text)]
 boot=re.search(r'^(\S+ \S+) \[info\]: \[LuaScaffold\] BOOT',text,re.M)
 done=re.search(r'^(\S+ \S+) \[info\]: \[UT_DONE\]',text,re.M)
 elapsed=(datetime.fromisoformat(done[1])-datetime.fromisoformat(boot[1])).total_seconds() if boot and done else None
 for timestamp,tag,phase,tick,cycles,heap,controls in re.findall(
   r'^(\S+ \S+) \[info\]: \[RESOURCE_PROFILE\] tag=(begin|end) phase=(\S+) tick=(\d+) cycles=(\d+) lua_kib=([\d.]+) controls=(\d+)',text,re.M):
  profile_bounds.setdefault(player,{}).setdefault(phase,{})[tag]={'utc':datetime.fromisoformat(timestamp).replace(tzinfo=timezone(timedelta(hours=args.log_utc_offset))),
   'tick':int(tick),'cycles':int(cycles),'lua_kib':float(heap),'controls':int(controls)}
 report['peers'].append({'log':file.name,'wall_seconds_boot_to_done':elapsed,'benchmarks':bench,'resources':resources,
   'allocations':[{'name':n,'iterations':int(i),'kib':float(k)} for n,i,k in re.findall(r'\[ALLOC\] name=(\S+) n=(\d+) kib=([\d.]+)',text)],
   'clocks':re.findall(r'\[CLOCK_PROBE\] ([^\n\r]+)',text),
   'native_clocks':re.findall(r'\[CLOCK_NATIVE\] ([^\n\r]+)',text)})
samples=folder/'resources.jsonl'
if samples.exists():
 by_process={}
 for line in samples.read_text(encoding='utf-8-sig').splitlines():
  row=json.loads(line);by_process.setdefault(row['pid'],[]).append(row)
 for pid,rows in by_process.items():
  rows.sort(key=lambda r:r['utc'])
  start=datetime.fromisoformat(rows[0]['utc'].replace('Z','+00:00'))
  def elapsed(row):return (datetime.fromisoformat(row['utc'].replace('Z','+00:00'))-start).total_seconds()
  late=[r for r in rows if elapsed(r)>=300] or rows
  window=min(6,len(late))
  report['processes'].append({'pid':pid,'player':rows[0]['player'],'samples':len(rows),'sample_span_seconds':elapsed(rows[-1]),
   'private_mib_first':rows[0]['privateBytes']/1048576,'private_mib_last':rows[-1]['privateBytes']/1048576,
   'private_mib_max':max(r['privateBytes'] for r in rows)/1048576,
   'late_private_mib_median_first_window':statistics.median(r['privateBytes'] for r in late[:window])/1048576,
   'late_private_mib_median_last_window':statistics.median(r['privateBytes'] for r in late[-window:])/1048576,
   'working_set_mib_max':max(r['workingSet'] for r in rows)/1048576,
   'os_handles_first':rows[0]['handles'],'os_handles_last':rows[-1]['handles']})
  for phase,bounds in profile_bounds.get(rows[0]['player'],{}).items():
   if not {'begin','end'}<=bounds.keys():continue
   points=[r for r in rows if bounds['begin']['utc']<=datetime.fromisoformat(r['utc'].replace('Z','+00:00'))<=bounds['end']['utc']]
   if len(points)<2:continue
   a,b=points[0],points[-1];seconds=elapsed(b)-elapsed(a)
   report['resource_profile'].append({'phase':phase,'pid':pid,'samples':len(points),'sample_span_seconds':seconds,
    'cycles':bounds['end']['cycles'],'private_mib_first':a['privateBytes']/1048576,'private_mib_last':b['privateBytes']/1048576,
    'private_mib_delta':(b['privateBytes']-a['privateBytes'])/1048576,
    'os_handles_first':a['handles'],'os_handles_last':b['handles'],
    'os_handles_per_minute':(b['handles']-a['handles'])*60/seconds,
    'lua_kib_end':bounds['end']['lua_kib'],'controls_end':bounds['end']['controls']})
(folder/'analysis.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for peer in report['peers']:
 print(peer['log'],'wall_seconds=',peer['wall_seconds_boot_to_done'])
 print({k:round(v['median_ms'],3) for k,v in peer['benchmarks'].items()})
for process in report['processes']: print(process)
for phase in report['resource_profile']: print(phase)
