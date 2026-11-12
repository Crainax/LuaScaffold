"""Retention boundaries: unrelated data, evidence, pinned and active builds."""
from pathlib import Path
import json
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
from build_cleanup import cleanup, safe_target

with tempfile.TemporaryDirectory(prefix='LuaCleanup-') as temp:
    root = Path(temp)
    build = root/'build'
    build.mkdir()
    evidence = root/'tests/evidence/log.txt'
    evidence.parent.mkdir(parents=True)
    evidence.write_text('evidence')
    for name in ('analysis-deps', 'engine-pe', 'tool-cache', 'failed-build'):
        (build/name).mkdir()
        (build/name/'keep.txt').write_text('keep')
    (build/'unknown.w3x').write_text('unmanaged')
    for name in ('old', 'pinned', 'new'):
        for suffix in ('', '-lni'):
            (build/(name+suffix)).mkdir()
            (build/(name+suffix)/'data').write_text('temporary')
        (build/(name+'.w3x')).write_text('map')
        (build/(name+'-build.json')).write_text(json.dumps({
            'map':name+'.w3x', 'files':[{'path':'test'}],
            'config':{'keep_work':name=='pinned'}}))
    guard = build/'runtime-guard-active.json'
    guard.write_text('{}')
    cleanup(build, 'new', 1)
    assert (build/'old/data').exists()
    guard.unlink()
    cleanup(build, 'new', 1)
    assert not (build/'old.w3x').exists()
    assert not (build/'new').exists() and not (build/'new-lni').exists()
    assert (build/'new.w3x').exists() and (build/'old-build.json').exists()
    assert (build/'pinned/data').exists() and (build/'pinned.w3x').exists()
    assert (build/'unknown.w3x').exists() and evidence.read_text()=='evidence'
    for name in ('analysis-deps', 'engine-pe', 'tool-cache', 'failed-build'):
        assert (build/name/'keep.txt').read_text()=='keep'
    try:
        safe_target(build, evidence)
    except ValueError:
        pass
    else:
        raise AssertionError('outside path accepted')
print('BUILD CLEANUP PASS retention, pinned/active/failed builds and protected data')
