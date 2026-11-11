"""Refresh the project LAN adapter from the installed validated runner (explicit maintenance only)."""
from pathlib import Path
import hashlib, json
root=Path(__file__).resolve().parents[1]
source=Path('D:/War3/tools/LanTest/Start-LanTest.ps1')
original=source.read_bytes()
expected='645a4361a0f369abc017cb8b50cfdbc792dba8d9cec0eb669f3ed66da64f11bc'
assert hashlib.sha256(original).hexdigest()==expected, 'Shared runner changed; review adaptation before updating the pin'
s=original.decode('utf-8-sig').replace('\r\n','\n')
for anchor in ('[ValidateRange(10,1800)]','$session = $null','if ($ProjectPath) {',
               '$launchSucceeded = $true','} finally { if ($profileLock) { $profileLock.Dispose() }; $sessionLock.Dispose() }'):
    assert s.count(anchor)==1, 'Unexpected shared runner structure: '+anchor
s=s.replace('[ValidateRange(10,1800)]','[ValidateRange(10,7200)]')
s=s.replace('$PSScriptRoot','$SharedRoot')
s=s.replace('$session = $null', """$SharedRoot = 'D:/War3/tools/LanTest'
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $ProjectRoot 'tools/runtime_guard.ps1')
. (Join-Path $ProjectRoot 'tools/resource_sampling.ps1')
$resourceJob = $null
$runtimeGuard = $null
$session = $null""",1)
s=s.replace('if ($ProjectPath) {',
    '$runtimeGuard = Enter-LuaRuntimeGuard $GamePath $ProjectRoot ([IO.Path]::GetFileNameWithoutExtension($map))\nif ($ProjectPath) {',1)
s=s.replace('$launchSucceeded = $true',
    'Wait-LuaRuntimeGuard $runtimeGuard $Clients\nExit-LuaRuntimeGuard $runtimeGuard\nif ($Automated) { $resourceJob = Start-LuaResourceSampler $session }\n$launchSucceeded = $true',1)
s=s.replace('} finally { if ($profileLock) { $profileLock.Dispose() }; $sessionLock.Dispose() }',
    '} finally { try { if ($resourceJob) { Stop-Job $resourceJob; Receive-Job $resourceJob; Remove-Job $resourceJob }; Exit-LuaRuntimeGuard $runtimeGuard } finally { if ($profileLock) { $profileLock.Dispose() }; $sessionLock.Dispose() } }')
out=root/'tools/lan';out.mkdir(exist_ok=True)
(out/'Start-LuaTest.ps1').write_text('# Adapted shared LAN runner: project j2b guard and extended deadline.\n'+s,encoding='utf-8',newline='\n')
(out/'provenance.json').write_text(json.dumps({'source':str(source),'sha256':hashlib.sha256(original).hexdigest(),
    'changes':['project j2b guard under profile lock','timeout maximum 7200 seconds','PID/creation-time-scoped resource sampler','shared runtime/helpers retained']},indent=2)+'\n',encoding='utf-8')
print('LAN adapter generated; shared source unchanged')
