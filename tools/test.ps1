param(
    [Parameter(Mandatory=$true)][string]$Name,
    [ValidateRange(1,6)][int]$Clients=1,
    [ValidateRange(10,1800)][int]$TimeoutSeconds=240,
    [string]$Runner='D:/War3/tools/LanTest/Start-LanTest.ps1',
    [string]$GamePath='D:/Program Files (x86)/Warcraft III Frozen Throne'
)
$ErrorActionPreference='Stop'
if ($Name -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid build name' }
$root=Split-Path $PSScriptRoot -Parent
$map=Join-Path $root "build/$Name.w3x"
$project=Get-Content -LiteralPath (Join-Path $root 'project.json') -Raw | ConvertFrom-Json
$logs=Join-Path $GamePath "$($project.id)/logs"
$null=New-Item -ItemType Directory -Force -Path $logs
& $Runner -MapPath $map -Clients $Clients -GamePath $GamePath -LegacySizeCap -UseScriptSlots -Automated -ClientLogDirectory $logs -CompletionPattern "\[UT_DONE\] LuaScaffold $([regex]::Escape($Name)) " -TimeoutSeconds $TimeoutSeconds
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
