param(
    [Parameter(Mandatory=$true)][string]$Name,
    [ValidateRange(1,6)][int]$Clients=1,
    [ValidateRange(10,7200)][int]$TimeoutSeconds=240,
    [string]$Runner,
    [string]$GamePath='D:/Program Files (x86)/Warcraft III Frozen Throne'
)
$ErrorActionPreference='Stop'
if ($Name -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid build name' }
$root=Split-Path $PSScriptRoot -Parent
if (!$Runner) { $Runner=Join-Path $PSScriptRoot 'lan/Start-LuaTest.ps1' }
$map=Join-Path $root "build/$Name.w3x"
$buildFile=Join-Path $root "build/$Name-build.json"
if (!(Test-Path -LiteralPath $buildFile)) { throw 'Build validation did not finish; missing build manifest' }
$build=Get-Content -LiteralPath $buildFile -Raw | ConvertFrom-Json
if ((Get-FileHash -LiteralPath $map -Algorithm SHA256).Hash.ToLowerInvariant() -ne $build.sha256) { throw 'Map differs from validated build manifest' }
if (!$build.config.test -or $build.config.clients -ne $Clients) { throw 'Test client count/config differs from validated build' }
$project=Get-Content -LiteralPath (Join-Path $root 'project.json') -Raw | ConvertFrom-Json
$folder=if ($project.log_folder) { $project.log_folder } else { $project.id }
$logs=Join-Path $GamePath "$folder/logs"
$null=New-Item -ItemType Directory -Force -Path $logs
& $Runner -MapPath $map -Clients $Clients -GamePath $GamePath -LegacySizeCap -UseScriptSlots -Automated -ClientLogDirectory $logs -CompletionPattern "\[UT_DONE\] LuaScaffold $([regex]::Escape($Name)) " -TimeoutSeconds $TimeoutSeconds
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
