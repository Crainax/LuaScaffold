"""Exercise the real new-project and production-build path in a disposable copy."""
from pathlib import Path
import hashlib, json, subprocess, sys, tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='LuaScaffold-reuse-') as temp:
    parent = Path(temp).resolve()
    dest = parent / 'FreshLuaGame'
    assert dest.is_relative_to(Path(tempfile.gettempdir()).resolve())
    subprocess.run([sys.executable, 'tools/new_project.py', str(dest), '--id', 'FreshLuaGame',
                    '--title', '复用测试地图'], cwd=root, check=True)
    assert not (dest/'.git').exists() and not (dest/'build').exists()
    subprocess.run([sys.executable, 'tools/build.py', '--name', 'reuse-production'], cwd=dest, check=True)
    payload = dest/'build/reuse-production'
    config = (payload/'script/app/config.lua').read_text(encoding='utf-8')
    assert "project_id='FreshLuaGame'" in config and 'runtime_test=false' in config
    assert not (payload/'script/app/runtime_test.lua').exists()
    assert not (payload/'script/ui/client/util.lua').exists()
    assert '复用测试地图' in (dest/'build/reuse-production-map/war3map.j').read_text(encoding='utf-8')
    entries = json.loads((dest/'build/reuse-production-manifest.json').read_text(encoding='utf-8'))
    for entry in entries:
        assert hashlib.sha256((payload/entry['archive']).read_bytes()).hexdigest() == entry['sha256']
    report = {'status':'PASS', 'id':'FreshLuaGame', 'production_payload_files':len(entries),
              'map_sha256':hashlib.sha256((dest/'build/reuse-production.w3x').read_bytes()).hexdigest(),
              'checks':['copy without .git/build', 'project ID and Chinese title', 'production excludes runtime harness',
                        'JASS compilation', 'MPQ byte-for-byte readback', 'final payload manifest matches files']}
(root/'tests/evidence').mkdir(exist_ok=True)
(root/'tests/evidence/reuse-check.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('REUSE CHECK PASS; temporary copy removed')
