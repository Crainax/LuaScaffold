"""Offline checks only. Host Lua is not the embedded Warcraft VM."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
checks = [[sys.executable, 'tools/stage.py']]
for folder in ('src', 'tests', 'examples'):
    for path in sorted((ROOT / folder).rglob('*.lua')):
        checks.append(['luac', '-p', str(path.relative_to(ROOT))])
checks += [['lua', 'tests/run.lua'], ['lua', 'tests/upstream_audit.lua'], ['lua', 'tests/bridge_mock.lua'], ['lua', 'tests/ui_mock.lua']]
lines = []
failed = False
for command in checks:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, errors='replace')
    output = result.stdout + result.stderr
    lines.append(f'$ {" ".join(command)}\n{output}exit={result.returncode}\n')
    if output:
        print(output, end='')
    failed |= result.returncode != 0
(ROOT / 'build').mkdir(exist_ok=True)
(ROOT / 'build' / 'offline-validation.txt').write_text('\n'.join(lines), encoding='utf-8')
print('OFFLINE CHECKS ' + ('FAILED' if failed else 'PASSED'))
sys.exit(1 if failed else 0)
