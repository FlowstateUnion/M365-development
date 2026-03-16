Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$config = Get-ToolkitConfig
Initialize-Toolkit -Config $config

$graphQueries = @(
    'copilot',
    'teams app installation',
    'bot framework',
    'power automate flow',
    'sharepoint list',
    'service principal'
)

$skillSearchResults = @()
if (Test-Path $config.MsgGraphSkillPath) {
    $runner = Join-Path $config.MsgGraphSkillPath 'scripts\run.ps1'
    if (Test-Path $runner) {
        foreach ($query in $graphQueries) {
            $skillSearchResults += Invoke-SafeStep -Name ("msgraph openapi-search: {0}" -f $query) -ScriptBlock {
                & powershell -ExecutionPolicy Bypass -File $runner openapi-search --query $query --limit 5
            }
        }
    }
}

$liveResults = @()
if ($config.RunLiveQueries) {
    $liveResults += Invoke-SafeStep -Name 'Graph context' -ScriptBlock {
        if (-not (Get-Command -Name Get-MgContext -ErrorAction SilentlyContinue)) {
            throw 'Get-MgContext is not available.'
        }

        Get-MgContext | Select-Object TenantId, ClientId, Scopes
    }

    $liveResults += Invoke-SafeStep -Name 'Graph organization' -ScriptBlock {
        if (-not (Get-Command -Name Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
            throw 'Invoke-MgGraphRequest is not available.'
        }

        Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/organization' |
            Select-Object -ExpandProperty value |
            Select-Object -First 5 id, displayName, verifiedDomains
    }
}

$data = [pscustomobject]@{
    GeneratedAt       = (Get-Date).ToString('s')
    Scope             = 'Graph discovery options for Copilot-adjacent entities'
    EnvSummary        = Get-PlainTextEnvSummary -Config $config
    DiscoveryOptions  = @(
        [pscustomobject]@{ Area = 'Local Graph skill search'; WhyItMatters = 'Lets you explore Graph endpoints without live tenant access'; Tools = @('msgraph openapi-search', 'msgraph api-docs-search', 'msgraph sample-search') },
        [pscustomobject]@{ Area = 'Microsoft Graph PowerShell'; WhyItMatters = 'Lets you query Entra, Teams, SharePoint, and app objects directly'; Tools = @('Connect-MgGraph', 'Invoke-MgGraphRequest') }
    )
    AvailableCommands = Get-CommandPresence -Names @(
        'Connect-MgGraph',
        'Get-MgContext',
        'Invoke-MgGraphRequest'
    )
    SkillSearchResults = $skillSearchResults
    LiveResults        = $liveResults
    SuggestedGraphStartingPoints = @(
        '/organization',
        '/applications',
        '/servicePrincipals',
        '/teams',
        '/appCatalogs/teamsApps',
        '/sites',
        '/groups'
    )
}

$reportPath = Write-ToolkitReport -Config $config -Name '05-graph-discovery' -Data $data
Write-Host "Wrote report: $reportPath"
