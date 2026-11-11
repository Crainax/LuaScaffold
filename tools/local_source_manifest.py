"""Fingerprint only the local reference files reviewed by this research; never modify them."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
groups={
 'MoeHero':(Path('D:/War3/Maps/MoeHero'),['README.md','scripts/main.lua','scripts/ac/init.lua','scripts/ac/timer.lua','scripts/ac/event.lua','scripts/ac/trigger.lua','scripts/types/unit.lua','scripts/test/helper.lua','scripts/types/hot_fix.lua']),
 'Moling':(Path('D:/War3/LearnLua/魔灵降世LUA'),['main.lua','war3map.j','script/init.lua','script/ac/init.lua','script/ac/timer.lua','script/ac/event.lua','script/types/unit.lua','script/ui/base/controls/panel.lua']),
 'j2b':(Path('D:/War3/内置JAPI/2021年'),['jass2binary.lua'])}
report={}
for name,(base,files) in groups.items():
 report[name]={'root':str(base),'files':[]}
 for relative in files:
  p=base/relative
  if p.is_file():report[name]['files'].append({'path':relative,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(root/'research/local-sources.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('LOCAL SOURCE FINGERPRINTS',sum(len(x['files']) for x in report.values()))
