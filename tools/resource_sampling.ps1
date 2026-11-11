function Start-LuaResourceSampler([string]$SessionPath) {
    Start-Job -ArgumentList $SessionPath -ScriptBlock {
        param($folder)
        $ErrorActionPreference='Stop'
        $manifest=Get-Content -LiteralPath (Join-Path $folder 'session.json') -Raw | ConvertFrom-Json
        $output=Join-Path $folder 'resources.jsonl'
        while ($true) {
            foreach ($record in $manifest.clientProcesses) {
                $gamePid=[int]$record.pid
                $cim=Get-CimInstance Win32_Process -Filter "ProcessId=$gamePid"
                if (!$cim -or $cim.CreationDate.ToUniversalTime().Ticks.ToString() -ne $record.creationUtcTicks) { continue }
                $process=Get-Process -Id $gamePid -ErrorAction SilentlyContinue
                if (!$process) { continue }
                @{utc=[datetime]::UtcNow.ToString('o');pid=$gamePid;player=$record.expectedName;
                  privateBytes=$process.PrivateMemorySize64;workingSet=$process.WorkingSet64;
                  cpuSeconds=(([double]$cim.KernelModeTime+[double]$cim.UserModeTime)/10000000);handles=$process.HandleCount} |
                    ConvertTo-Json -Compress | Add-Content -LiteralPath $output -Encoding utf8
            }
            Start-Sleep -Seconds 10
        }
    }
}
