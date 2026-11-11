param([string]$GamePath='D:/Program Files (x86)/Warcraft III Frozen Throne')
$ErrorActionPreference='Stop'
if (@(Get-Process -Name war3,'Warcraft III',ydhost -ErrorAction SilentlyContinue).Count) { throw 'Close owned test games before recovery' }
. (Join-Path $PSScriptRoot 'runtime_guard.ps1')
$journal=Join-Path (Split-Path $PSScriptRoot -Parent) 'build/runtime-guard-active.json'
if (!(Test-Path -LiteralPath $journal)) { Write-Host 'No pending guard'; return }
$state=Get-Content -LiteralPath $journal -Raw | ConvertFrom-Json
if ($state.target -ne (Join-Path ([IO.Path]::GetFullPath($GamePath)) 'jass2binary.lua')) { throw 'Guard target does not match GamePath' }
Exit-LuaRuntimeGuard $state
Write-Host 'Original j2b script restored'
