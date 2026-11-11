"""Render stored process samples with diagnostic phase boundaries; no live process access."""
from pathlib import Path
from datetime import datetime,timedelta,timezone
import argparse,json,re,sys
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'build/analysis-deps'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
parser=argparse.ArgumentParser();parser.add_argument('--session',required=True)
parser.add_argument('--log-utc-offset',type=float,default=8);args=parser.parse_args()
folder=root/'tests/evidence'/args.session
assert folder.parent==root/'tests/evidence' and folder.is_dir()
rows=[json.loads(s) for s in (folder/'resources.jsonl').read_text(encoding='utf-8-sig').splitlines()]
def date(value):return datetime.fromisoformat(value.replace('Z','+00:00'))
start=min(date(r['utc']) for r in rows)
fig,axes=plt.subplots(2,1,figsize=(10,7),sharex=True,layout='constrained')
for player in sorted({r['player'] for r in rows}):
 points=sorted((r for r in rows if r['player']==player),key=lambda r:r['utc'])
 x=[(date(r['utc'])-start).total_seconds()/60 for r in points]
 axes[0].plot(x,[r['privateBytes']/1048576 for r in points],label=player,linewidth=1.4)
 axes[1].plot(x,[r['handles'] for r in points],label=player,linewidth=1.4)
phases=[]
for log in (folder/'client-logs').glob('*.log'):
 for timestamp,phase in re.findall(r'^(\S+ \S+) \[info\]: \[RESOURCE_PROFILE\] tag=begin phase=(\S+)',log.read_text(encoding='utf-8-sig'),re.M):
  moment=datetime.fromisoformat(timestamp).replace(tzinfo=timezone(timedelta(hours=args.log_utc_offset)))
  phases.append(((moment-start).total_seconds()/60,phase))
seen_phases=set()
for minute,phase in phases:
 key=(round(minute,1),phase)
 if key in seen_phases:continue
 seen_phases.add(key)
 for ax in axes:ax.axvline(minute,color='#777777',linestyle=':',linewidth=.8)
 axes[0].text(minute+.06,.98,phase,rotation=90,ha='left',va='top',transform=axes[0].get_xaxis_transform(),fontsize=8)
axes[0].set_ylabel('Private memory (MiB)');axes[1].set_ylabel('Windows process handles')
axes[1].set_xlabel('Minutes since first process sample')
for ax in axes:ax.grid(alpha=.18);ax.legend(loc='lower right');ax.margins(x=.02)
fig.suptitle(args.session+' | recorded native process resources',fontsize=12)
fig.savefig(folder/'resource-trends.png',dpi=150)
fig.savefig(folder/'resource-trends.svg')
plt.close(fig)
print('RESOURCE CHART SAVED:',folder.name)
