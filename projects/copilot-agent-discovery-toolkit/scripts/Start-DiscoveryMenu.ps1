Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot
$items = @(
    [pscustomobject]@{ Key = '1'; Name = 'Check prerequisites'; Path = '01-Check-Prereqs.ps1' },
    [pscustomobject]@{ Key = '2'; Name = 'Discover M365'; Path = '02-Discover-M365.ps1' },
    [pscustomobject]@{ Key = '3'; Name = 'Discover Azure'; Path = '03-Discover-Azure.ps1' },
    [pscustomobject]@{ Key = '4'; Name = 'Discover Power Automate'; Path = '04-Discover-PowerAutomate.ps1' },
    [pscustomobject]@{ Key = '5'; Name = 'Discover Graph'; Path = '05-Discover-Graph.ps1' },
    [pscustomobject]@{ Key = 'A'; Name = 'Run all'; Path = $null },
    [pscustomobject]@{ Key = 'Q'; Name = 'Quit'; Path = $null }
)

function Invoke-MenuScript {
    param(
        [string]$RelativePath
    )

    & (Join-Path $scriptRoot $RelativePath)
}

do {
    Write-Host ''
    Write-Host 'Copilot Agent Discovery Toolkit'
    Write-Host '-------------------------------'
    foreach ($item in $items) {
        Write-Host ("[{0}] {1}" -f $item.Key, $item.Name)
    }

    $choice = (Read-Host 'Choose an option').Trim().ToUpperInvariant()

    switch ($choice) {
        '1' { Invoke-MenuScript -RelativePath '01-Check-Prereqs.ps1' }
        '2' { Invoke-MenuScript -RelativePath '02-Discover-M365.ps1' }
        '3' { Invoke-MenuScript -RelativePath '03-Discover-Azure.ps1' }
        '4' { Invoke-MenuScript -RelativePath '04-Discover-PowerAutomate.ps1' }
        '5' { Invoke-MenuScript -RelativePath '05-Discover-Graph.ps1' }
        'A' {
            Invoke-MenuScript -RelativePath '01-Check-Prereqs.ps1'
            Invoke-MenuScript -RelativePath '02-Discover-M365.ps1'
            Invoke-MenuScript -RelativePath '03-Discover-Azure.ps1'
            Invoke-MenuScript -RelativePath '04-Discover-PowerAutomate.ps1'
            Invoke-MenuScript -RelativePath '05-Discover-Graph.ps1'
        }
        'Q' { break }
        default { Write-Warning 'Unknown selection.' }
    }
} while ($true)
