param(
    [ValidateSet('Build','Play','Test','OOS','Soak')][string]$Mode='Test',
    [ValidateSet('integration','ui','performance','hotreload','soak')][string]$Suite='integration',
    [ValidateRange(1,6)][int]$Clients=1,
    [switch]$Dev,
    [string]$GamePath='D:/Program Files (x86)/Warcraft III Frozen Throne'
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $root
try {
    & python -X utf8 tools/check.py
    if ($LASTEXITCODE -ne 0) { throw 'Offline checks failed' }
    $name=('{0}-{1}-{2}' -f $Mode.ToLower(),$Suite,(Get-Date -Format 'yyyyMMdd-HHmmss'))
    $argsList=@('-X','utf8','tools/build.py','--name',$name,'--clients',"$Clients")
    $timeout=300
    if ($Mode -in @('Test','OOS','Soak')) { $argsList+='--test' }
    if ($Mode -eq 'OOS') {
        if ($Clients -lt 2) { throw 'OOS control needs at least two clients' }
        $argsList+='--oos-control'
    }
    if ($Mode -eq 'Soak') { $Suite='soak';$argsList+=@('--ticks','180000');$timeout=4200 }
    else { $argsList+=@('--ticks','6000') }
    $argsList+=@('--suite',$Suite)
    if ($Dev -or $Suite -eq 'hotreload') { $argsList+='--dev' }
    & python @argsList
    if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
    if ($Mode -eq 'Build') { return }
    $project=Get-Content -LiteralPath (Join-Path $root 'project.json') -Raw | ConvertFrom-Json
    $logFolder=if ($project.log_folder) { $project.log_folder } else { $project.id }
    $null=New-Item -ItemType Directory -Force -Path (Join-Path $GamePath "$logFolder/logs")
    if ($Mode -eq 'Play') {
        & (Join-Path $PSScriptRoot 'lan/Start-LuaTest.ps1') -MapPath (Join-Path $root "build/$name.w3x") -Clients $Clients -GamePath $GamePath -LegacySizeCap -UseScriptSlots
    } else {
        & (Join-Path $PSScriptRoot 'test.ps1') -Name $name -Clients $Clients -GamePath $GamePath -TimeoutSeconds $timeout
    }
} finally { Pop-Location }
