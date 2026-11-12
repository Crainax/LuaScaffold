"""Stored samples only: phase endpoints and least-squares slopes, not leak attribution."""
from pathlib import Path
from datetime import datetime,timezone,timedelta
import argparse,json,re,statistics
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--session',required=True);args=p.parse_args()
folder=root/'tests/evidence'/args.session
assert folder.parent==root/'tests/evidence' and folder.is_dir()
def date(s):return datetime.fromisoformat(s.replace('Z','+00:00'))
rows=[json.loads(s) for s in (folder/'resources.jsonl').read_text(encoding='utf-8-sig').splitlines()]
phases=[]
log=next((folder/'client-logs').glob('*-P1.log')).read_text(encoding='utf-8-sig')
for stamp,name in re.findall(r'^(\S+ \S+) \[info\]: \[RESOURCE_PROFILE\] tag=begin phase=(\S+)',log,re.M):
    phases.append((datetime.fromisoformat(stamp).replace(tzinfo=timezone(timedelta(hours=8))),name))
if not phases:phases=[(min(date(r['utc']) for r in rows),'whole_run')]
end=max(date(r['utc']) for r in rows)+timedelta(seconds=1)
results=[]
windows=[(start,phases[i+1][0] if i+1<len(phases) else end,name) for i,(start,name) in enumerate(phases)]
if len(phases)==1 and phases[0][1]=='whole_run' and (end-phases[0][0]).total_seconds()>=600:
    windows.append((phases[0][0]+timedelta(seconds=300),end,'after_first_5_minutes'))
for start,stop,name in windows:
    for player in sorted({r['player'] for r in rows}):
        values=sorted((r for r in rows if r['player']==player and start<=date(r['utc'])<stop),key=lambda r:r['utc'])
        assert len(values)>=2,(name,player,'insufficient samples')
        t=[(date(r['utc'])-date(values[0]['utc'])).total_seconds()/60 for r in values]
        item={'phase':name,'player':player,'samples':len(values),'seconds':t[-1]*60}
        for key,scale in [('privateBytes',1048576),('handles',1)]:
            y=[r[key]/scale for r in values];xm=statistics.mean(t);ym=statistics.mean(y)
            slope=sum((x-xm)*(v-ym) for x,v in zip(t,y))/sum((x-xm)**2 for x in t)
            item[key]={'first':y[0],'last':y[-1],'minimum':min(y),'maximum':max(y),'median':statistics.median(y),'slope_per_minute':slope}
        results.append(item)
report={'session':args.session,'memory_unit':'MiB','handles_unit':'Windows process handles, NOT Warcraft handles',
        'method':'all samples in each phase, OLS per minute; long runs also report a fixed window excluding the first 300 seconds; no causal leak attribution','phases':results}
(folder/'resource-summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
for item in results:
    mem=item['privateBytes'];handles=item['handles']
    print(f"{item['phase']:12} {item['player']} n={item['samples']} private={mem['first']:.2f}->{mem['last']:.2f} MiB slope={mem['slope_per_minute']:.3f}/min handles={handles['slope_per_minute']:.1f}/min")
