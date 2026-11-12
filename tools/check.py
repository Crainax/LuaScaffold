"""Offline checks only. Host Lua is not the embedded Warcraft VM."""
from pathlib import Path
import subprocess
import sys
import os
from framework_package import resolve

ROOT = Path(__file__).resolve().parents[1]
checks = [[sys.executable, 'tools/stage.py']]
checks.append([sys.executable, 'tests/build_cleanup.py'])
checks.append([sys.executable,'tools/map_fixtures.py'])
folders=[ROOT/p for p in ('src','tests','examples','research')]
framework=resolve(ROOT)
if framework!=ROOT:folders.append(framework/'src')
for folder in folders:
    for path in sorted(folder.rglob('*.lua')):
        checks.append(['luac', '-p', str(path.relative_to(ROOT))])
checks += [['lua', 'tests/run.lua'], ['lua', 'tests/extended.lua'], ['lua', 'tests/upstream_audit.lua'], ['lua', 'tests/bridge_mock.lua'], ['lua', 'tests/ui_mock.lua']]
checks.append(['lua','tests/handle_refs.lua'])
checks.append(['lua','tests/unit_lifecycle.lua'])
checks.append(['lua','tests/skill_lifecycle.lua'])
checks.append(['lua','tests/world_lifecycle.lua'])
checks.append(['lua','tests/app_lifecycle.lua'])
checks.append(['lua','tests/native_unit_bridge.lua'])
checks.append(['lua','tests/request_ui.lua'])
lines = []
failed = False
env=os.environ.copy()
relative_framework=framework.relative_to(ROOT)
env['LUASCAFFOLD_FRAMEWORK_ROOT']=str(relative_framework)
env['LUA_PATH']='src/?.lua;src/?/init.lua;'+str(relative_framework/'src/?.lua')+';'+str(relative_framework/'src/?/init.lua')+';;'
for command in checks:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, errors='replace',env=env)
    output = result.stdout + result.stderr
    lines.append(f'$ {" ".join(command)}\n{output}exit={result.returncode}\n')
    if output:
        print(output, end='')
    failed |= result.returncode != 0
(ROOT / 'build').mkdir(exist_ok=True)
(ROOT / 'build' / 'offline-validation.txt').write_text('\n'.join(lines), encoding='utf-8')
print('OFFLINE CHECKS ' + ('FAILED' if failed else 'PASSED'))
sys.exit(1 if failed else 0)
