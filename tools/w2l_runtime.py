"""Pinned, private w3x2lni CLI. Shared installation is read-only."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / 'config/w2l-lock.json'
DEFAULT = Path('D:/War3/tools/w3x2lni')

def inventory(folder):
    return {p.relative_to(folder).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(folder.rglob('*')) if p.is_file()
            and p.relative_to(folder).parts[0] != 'log'}

def runtime(source=DEFAULT):
    lock = json.loads(LOCK.read_text(encoding='utf-8'))
    assert inventory(source) == lock['files'], 'w3x2lni installation differs from pinned lock'
    overlays={'config.ini':ROOT/'config/w2l-policy.ini',
              'script/core/config.ini':ROOT/'config/w2l-core-policy.ini'}
    expected=dict(lock['files'])
    for name,policy in overlays.items():expected[name]=hashlib.sha256(policy.read_bytes()).hexdigest()
    digest = hashlib.sha256(json.dumps(expected, sort_keys=True).encode()).hexdigest()
    target = ROOT / 'build/tool-cache' / ('w2l-' + digest[:16])
    if not target.exists():
        target.mkdir(parents=True)
        for name in lock['files']:
            dest = target / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / name, dest)
        for name,policy in overlays.items():shutil.copy2(policy,target/name)
    assert inventory(target) == expected, 'private w3x2lni runtime changed'
    return target

def invoke(arguments, source=DEFAULT):
    tool = runtime(source)
    return subprocess.run([str(tool/'bin/w3x2lni-lua.exe'), str(ROOT/'tools/w2l_cli.lua'),
                           str(tool), *map(str, arguments)], cwd=tool,
                          capture_output=True, creationflags=0x08000000)

def verify_objects(source,packed,report):
    tool=runtime()
    result=subprocess.run([str(tool/'bin/w3x2lni-lua.exe'),str(ROOT/'tools/verify_objects.lua'),
                           str(tool),str(source),str(packed)],cwd=tool,capture_output=True,creationflags=0x08000000)
    report.write_bytes(result.stdout+result.stderr)
    print(result.stdout.decode('utf8',errors='replace'),end='')
    if result.returncode:print(result.stderr.decode('utf8',errors='replace'))
    result.check_returncode()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=DEFAULT)
    parser.add_argument('--pin', action='store_true')
    args = parser.parse_args()
    if args.pin:
        assert not LOCK.exists(), 'existing tool lock must be explicitly reviewed before replacement'
        files = inventory(args.source)
        assert 'w2l.exe' in files and 'config.ini' in files
        LOCK.parent.mkdir(exist_ok=True)
        LOCK.write_text(json.dumps({'source': str(args.source), 'files': files}, indent=2)+'\n', encoding='utf-8')
    result = invoke(['version'], args.source)
    print(result.stdout.decode('utf-8', errors='replace'))
    print(result.stderr.decode('utf-8', errors='replace'))
    result.check_returncode()
    print('PINNED PRIVATE W2L READY')
