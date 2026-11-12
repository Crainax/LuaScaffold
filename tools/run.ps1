param(
    [ValidateSet('Build','BuildTest','Play','Test','OOS','Soak','Resource')][string]$Mode='Test',
    [ValidateSet('integration','ui','performance','hotreload','soak','lifecycle','gameplay','campaign_soak','business_resource','resource_matrix')][string]$Suite='integration',
    [ValidateSet('MainMap','UnitTestMap')][string]$Map,
    [ValidateSet('obj','slk')][string]$Format='obj',
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
    if ($Mode -eq 'Soak' -and $Suite -eq 'integration') { $Suite='campaign_soak' }
    if ($Mode -eq 'OOS' -and $Suite -eq 'integration') { $Suite='gameplay' }
    if ($Mode -eq 'Resource') {
        if ($Suite -eq 'integration') { $Suite='business_resource' }
        if ($Suite -notin @('business_resource','resource_matrix')) { throw 'Resource mode requires business_resource or resource_matrix' }
    }
    if (!$Map) { $Map=if ($Mode -in @('Build','Play')) { 'MainMap' } else { 'UnitTestMap' } }
    $name=('{0}-{1}-{2}-{3}' -f $Mode.ToLower(),$Map.ToLower(),$Suite,(Get-Date -Format 'yyyyMMdd-HHmmss'))
    $argsList=@('-X','utf8','tools/build.py','--name',$name,'--clients',"$Clients",'--map',$Map,'--format',$Format)
    $timeout=300
    if ($Mode -in @('BuildTest','Test','OOS','Soak','Resource')) { $argsList+='--test' }
    if ($Mode -eq 'OOS') {
        if ($Clients -lt 2) { throw 'OOS control needs at least two clients' }
        $argsList+='--oos-control'
    }
    if ($Mode -eq 'Soak') { $argsList+=@('--ticks','180000');$timeout=4200 }
    elseif ($Suite -eq 'resource_matrix') { $argsList+=@('--ticks','33000');$timeout=900 }
    elseif ($Suite -eq 'business_resource') { $argsList+=@('--ticks','30000');$timeout=900 }
    else { $argsList+=@('--ticks','6000') }
    $argsList+=@('--suite',$Suite)
    if ($Dev -or $Suite -in @('hotreload','soak')) { $argsList+='--dev' }
    & python @argsList
    if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
    if ($Mode -in @('Build','BuildTest')) { return }
    $project=Get-Content -LiteralPath (Join-Path $root 'project.json') -Raw | ConvertFrom-Json
    $logFolder=if ($project.log_folder) { $project.log_folder } else { $project.id }
    $null=New-Item -ItemType Directory -Force -Path (Join-Path $GamePath "$logFolder/logs")
    if ($Mode -eq 'Play') {
        & (Join-Path $PSScriptRoot 'lan/Start-LuaTest.ps1') -MapPath (Join-Path $root "build/$name.w3x") -Clients $Clients -GamePath $GamePath -LegacySizeCap -UseScriptSlots
    } else {
        & (Join-Path $PSScriptRoot 'test.ps1') -Name $name -Clients $Clients -GamePath $GamePath -TimeoutSeconds $timeout
    }
} finally { Pop-Location }
