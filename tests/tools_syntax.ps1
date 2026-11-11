$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
foreach ($folder in @('tools','tests')) {
    Get-ChildItem -LiteralPath (Join-Path $root $folder) -Filter '*.ps1' -Recurse | ForEach-Object {
        $tokens=$null;$errors=$null
        $null=[Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
        if ($errors.Count) { throw ($errors | Out-String) }
    }
}
$null=Get-Content -LiteralPath (Join-Path $root '.vscode/tasks.json') -Raw | ConvertFrom-Json
Write-Host 'POWERSHELL AND TASKS SYNTAX PASS'
