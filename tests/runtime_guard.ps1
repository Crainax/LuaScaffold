$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'tools/runtime_guard.ps1')
$target=Join-Path $root ('build/guard-test-'+[Guid]::NewGuid().ToString('N'))
$game=Join-Path $target 'game'
$project=Join-Path $target 'project'
$null=New-Item -ItemType Directory -Force -Path $game,(Join-Path $project 'build')
try {
    $file=Join-Path $game 'jass2binary.lua'
    $original=[byte[]](0,1,255,13,10,65)
    [IO.File]::WriteAllBytes($file,$original)
    $state=Enter-LuaRuntimeGuard $game $project 'guard-test'
    if ((Get-LuaBytesHash ([IO.File]::ReadAllBytes($file))) -eq (Get-LuaBytesHash $original)) {throw 'Guard not installed'}
    Exit-LuaRuntimeGuard $state
    if ((Get-LuaBytesHash ([IO.File]::ReadAllBytes($file))) -ne (Get-LuaBytesHash $original)) {throw 'Restore changed original bytes'}
    Remove-Item -LiteralPath $file
    $state=Enter-LuaRuntimeGuard $game $project 'guard-test-absent'
    Exit-LuaRuntimeGuard $state
    if (Test-Path -LiteralPath $file) {throw 'Absent source was not restored to absent'}
    $state=Enter-LuaRuntimeGuard $game $project 'guard-conflict'
    $replacement=[IO.File]::ReadAllBytes($file)
    [IO.File]::WriteAllText($file,'external change')
    $rejected=$false
    try { Exit-LuaRuntimeGuard $state } catch { $rejected=$true }
    if (!$rejected -or [IO.File]::ReadAllText($file) -ne 'external change') {throw 'Guard overwrote external change'}
    if (!(Test-Path -LiteralPath $state.journal)) {throw 'Recovery journal lost'}
    [IO.File]::WriteAllBytes($file,$replacement);Exit-LuaRuntimeGuard $state
    Write-Host 'RUNTIME GUARD PASS existing/absent round trips and external-change refusal'
} finally {
    $resolved=[IO.Path]::GetFullPath($target)
    $expected=[IO.Path]::GetFullPath((Join-Path $root 'build'))+[IO.Path]::DirectorySeparatorChar
    if (!$resolved.StartsWith($expected,[StringComparison]::OrdinalIgnoreCase)) {throw 'Unsafe cleanup target'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
