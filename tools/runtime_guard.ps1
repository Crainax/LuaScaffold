# Project-scoped reversible isolation of the optional machine-global j2b tool.
function Get-LuaBytesHash([byte[]]$Bytes) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','') }
    finally { $sha.Dispose() }
}
function Enter-LuaRuntimeGuard([string]$GamePath,[string]$ProjectRoot,[string]$BuildName) {
    if ($BuildName -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid guard build name' }
    $game=[IO.Path]::GetFullPath($GamePath)
    $target=Join-Path $game 'jass2binary.lua'
    $journal=Join-Path $ProjectRoot 'build/runtime-guard-active.json'
    if (Test-Path -LiteralPath $journal) { throw "Unfinished guard journal; restore with tools/restore-runtime.ps1 first: $journal" }
    $exists=Test-Path -LiteralPath $target
    [byte[]]$before=@()
    if($exists){$before=[IO.File]::ReadAllBytes($target)}
    $marker=Join-Path $game 'LuaScaffold-runtime'
    $null=New-Item -ItemType Directory -Force -Path $marker
    foreach ($i in 1..6) {
        $stale=Join-Path $marker "$BuildName-P$i.guard"
        if(Test-Path -LiteralPath $stale){Remove-Item -LiteralPath $stale}
    }
    $code=@'
-- Temporary LuaScaffold launch guard. Original restored after all peers bootstrap.
require('jass.console').enable = false
package.console_enable = false
local j = require 'jass.common'
local player = j.GetPlayerId(j.GetLocalPlayer()) + 1
require('jass.storm').save('LuaScaffold-runtime\\@@BUILD@@-P' .. player .. '.guard', 'J2B_SKIPPED')
return true
'@
    $replacement=[Text.Encoding]::UTF8.GetBytes($code.Replace('@@BUILD@@',$BuildName))
    $state=@{target=$target;existed=$exists;before=[Convert]::ToBase64String($before);beforeHash=(Get-LuaBytesHash $before);replacementHash=(Get-LuaBytesHash $replacement);marker=$marker;build=$BuildName;journal=$journal;project=$ProjectRoot}
    [IO.File]::WriteAllText($journal,($state|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllBytes($target,$replacement)
    return $state
}
function Exit-LuaRuntimeGuard($State) {
    if (!$State -or !(Test-Path -LiteralPath $State.journal)) { return }
    $current=if(Test-Path -LiteralPath $State.target){Get-LuaBytesHash ([IO.File]::ReadAllBytes($State.target))}else{''}
    if ($current -ne $State.replacementHash) { throw 'j2b file changed during launch; refusing to overwrite. Guard journal retained.' }
    if ($State.existed) { [IO.File]::WriteAllBytes($State.target,[Convert]::FromBase64String($State.before)) }
    else { Remove-Item -LiteralPath $State.target }
    $record=@{build=$State.build;restored=$true;originalExisted=$State.existed;originalSha256=$State.beforeHash;utc=[datetime]::UtcNow.ToString('o')}
    [IO.File]::WriteAllText((Join-Path $State.project "build/$($State.build)-runtime-guard.json"),($record|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    Remove-Item -LiteralPath $State.journal
}
function Wait-LuaRuntimeGuard($State,[int]$Clients) {
    $deadline=[datetime]::UtcNow.AddSeconds(90)
    do {
        $ready=0
        foreach($i in 1..$Clients) {
            $file=Join-Path $State.marker "$($State.build)-P$i.guard"
            if ((Test-Path -LiteralPath $file) -and ([IO.File]::ReadAllText($file) -eq 'J2B_SKIPPED')) { $ready++ }
        }
        if ($ready -eq $Clients) { return }
        Start-Sleep -Milliseconds 250
    } while ([datetime]::UtcNow -lt $deadline)
    throw 'Not all clients acknowledged j2b isolation; inspect boot logs'
}
