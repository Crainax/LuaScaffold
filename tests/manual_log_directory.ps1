# Exercise the real Play branch in an isolated filesystem fixture. Never launch Warcraft.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$build=[IO.Path]::GetFullPath((Join-Path $root 'build'))
$fixture=[IO.Path]::GetFullPath((Join-Path $build ('manual-log-check-'+[guid]::NewGuid().ToString('N'))))
if (!$fixture.StartsWith($build+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path' }
$null=New-Item -ItemType Directory -Path (Join-Path $fixture 'tools/lan') -Force
try {
    Copy-Item -LiteralPath (Join-Path $root 'tools/run.ps1') -Destination (Join-Path $fixture 'tools/run.ps1')
    '{"id":"FreshLogGame","log_folder":"Lua框架研究"}' | Set-Content -LiteralPath (Join-Path $fixture 'project.json') -Encoding utf8
    @'
param($MapPath,$Clients,$GamePath,[switch]$LegacySizeCap,[switch]$UseScriptSlots)
if (!(Test-Path -LiteralPath (Join-Path $GamePath 'Lua框架研究/logs') -PathType Container)) { throw 'Manual launch reached runner before log directory initialization' }
'fake runner invoked' | Set-Content -LiteralPath (Join-Path $GamePath 'runner-marker.txt')
'@ | Set-Content -LiteralPath (Join-Path $fixture 'tools/lan/Start-LuaTest.ps1') -Encoding utf8
    function python { $global:LASTEXITCODE=0 } # Skip compiler work; only test startup routing and paths.
    $game=Join-Path $fixture 'game'
    & (Join-Path $fixture 'tools/run.ps1') -Mode Play -Dev -GamePath $game
    if (!(Test-Path -LiteralPath (Join-Path $game 'runner-marker.txt'))) { throw 'Play branch did not invoke runner' }
    Write-Output 'MANUAL LOG DIRECTORY PASS; isolated fixture, no game launched'
} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
