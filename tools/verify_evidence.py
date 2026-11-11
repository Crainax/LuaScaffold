"""Check saved native-test evidence independently of the in-game assertions."""
from pathlib import Path
import hashlib, json, re

root = Path(__file__).resolve().parents[1]
base = root/'tests/evidence'
index = json.loads((base/'index.json').read_text(encoding='utf-8'))
reports = []
for entry in index:
    folder = base/entry['session']
    assert entry['cleanup'], 'test process cleanup failed'
    if entry['status'] != 'PASS': continue
    logs = sorted((folder/'client-logs').glob('*.log'))
    assert len(logs) == entry['clients']
    peers = []
    for file in logs:
        text = file.read_text(encoding='utf-8-sig')
        assert text.count('[LuaScaffold] BOOT') == 1
        assert text.count('[UT_DONE]') == 1 and 'FAIL:' not in text and '[UT_FAIL]' not in text
        assert '[NATIVE_CALLBACK_GC] retained=0/8' in text
        states = re.findall(r'\[STATE_MATCH\] phase=(\d+) hash=(\d+) rng=(\d+)', text)
        metrics = re.search(r'\[METRICS\] ui_cycles=(\d+) rng_calls=(\d+) phases=(\d+) assertions=(\d+)', text)
        assert metrics and len(states) == int(metrics[3]) and len(states) >= 3
        peers.append({'log':file.name,'states':states,'ui_cycles':int(metrics[1]),
                      'rng_calls':int(metrics[2]),'phases':int(metrics[3]),'assertions':int(metrics[4])})
    assert all(p['states'] == peers[0]['states'] for p in peers), 'cross-client state or RNG mismatch'
    host = (folder/'host-stdout.log').read_text(encoding='utf-8-sig')
    assert 'desync detected' not in host.lower()
    reports.append({'session':entry['session'],'clients':entry['clients'],'status':'PASS','peers':peers})

control = next(e for e in index if e['map'] == 'oos-control-01.w3x')
folder = base/control['session']
assert control['status'] == 'FAIL' and control['message'] == 'OOS detected by ydhost'
assert 'desync detected' in (folder/'host-stdout.log').read_text(encoding='utf-8-sig').lower()
assert '[CONTROL] deliberate RNG divergence injected' in (folder/'client-logs/oos-control-01-P1.log').read_text(encoding='utf-8-sig')

final = base/'20261112-043013-b15c83'
build = json.loads((final/'build.json').read_text(encoding='utf-8'))
for entry in build['files']:
    path = entry['path']
    if path == 'script/app/config.lua': continue # generated build configuration
    relative = path.removeprefix('script/')
    source = root/'src'/relative
    if source.is_file():
        assert hashlib.sha256(source.read_bytes()).hexdigest() == entry['sha256'], 'source changed since final native test: '+relative

output = {'normal_sessions':reports,'oos_control':'EXPECTED_OOS_DETECTED',
          'all_recorded_sessions_cleaned':True,'final_lua_matches_six_client_build':True}
(base/'verified-summary.json').write_text(json.dumps(output,indent=2)+'\n',encoding='utf-8')
print('EVIDENCE PASS: normal peers agree, deliberate OOS detected, cleanup verified, final Lua matches tested build')
