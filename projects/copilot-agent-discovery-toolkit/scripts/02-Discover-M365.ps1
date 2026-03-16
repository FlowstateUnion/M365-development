Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$config = Get-ToolkitConfig
Initialize-Toolkit -Config $config

$m365Options = @(
    [pscustomobject]@{ Area = 'Teams app catalog'; WhyItMatters = 'Copilot agents often surface as Teams apps or app packages'; Commands = @('Get-TeamsApp', 'Get-CsTeamsAppPermissionPolicy', 'Get-CsTeamsAppSetupPolicy') },
    [pscustomobject]@{ Area = 'Teams app policies'; WhyItMatters = 'Shows which apps users are allowed to install or see by default'; Commands = @('Get-CsTeamsAppPermissionPolicy', 'Get-CsTeamsAppSetupPolicy') },
    [pscustomobject]@{ Area = 'SharePoint site and app surfaces'; WhyItMatters = 'Agent content may store data in SharePoint sites and app-connected lists'; Commands = @('Connect-SPOService') },
    [pscustomobject]@{ Area = 'Exchange and mailbox integrations'; WhyItMatters = 'Some agent workflows use mail-enabled triggers or notification paths'; Commands = @('Connect-ExchangeOnline') }
)

$liveResults = @()
if ($config.RunLiveQueries) {
    $liveResults += Invoke-SafeStep -Name 'Teams apps' -ScriptBlock {
        if (-not (Get-Command -Name Get-TeamsApp -ErrorAction SilentlyContinue)) {
            throw 'Get-TeamsApp is not available.'
        }

        Get-TeamsApp | Select-Object -First 25 Id, DisplayName, DistributionMethod
    }

    $liveResults += Invoke-SafeStep -Name 'Teams app permission policies' -ScriptBlock {
        if (-not (Get-Command -Name Get-CsTeamsAppPermissionPolicy -ErrorAction SilentlyContinue)) {
            throw 'Get-CsTeamsAppPermissionPolicy is not available.'
        }

        Get-CsTeamsAppPermissionPolicy | Select-Object Identity, Description
    }

    $liveResults += Invoke-SafeStep -Name 'Teams app setup policies' -ScriptBlock {
        if (-not (Get-Command -Name Get-CsTeamsAppSetupPolicy -ErrorAction SilentlyContinue)) {
            throw 'Get-CsTeamsAppSetupPolicy is not available.'
        }

        Get-CsTeamsAppSetupPolicy | Select-Object Identity, Description
    }
}

$data = [pscustomobject]@{
    GeneratedAt       = (Get-Date).ToString('s')
    Scope             = 'Microsoft 365 discovery for Copilot-adjacent deployments'
    EnvSummary        = Get-PlainTextEnvSummary -Config $config
    DiscoveryOptions  = $m365Options
    AvailableCommands = Get-CommandPresence -Names @(
        'Get-TeamsApp',
        'Get-CsTeamsAppPermissionPolicy',
        'Get-CsTeamsAppSetupPolicy',
        'Connect-SPOService',
        'Connect-ExchangeOnline'
    )
    LiveResults       = $liveResults
    ManualQuestions   = @(
        'Which Teams apps or custom apps include bot, agent, or Copilot branding?',
        'Which Teams app permission policies allow custom or third-party agent apps?',
        'Which Teams app setup policies pin Copilot-related apps for users?',
        'Which SharePoint sites or lists back Copilot Studio topics, prompts, or flow outputs?'
    )
}

$reportPath = Write-ToolkitReport -Config $config -Name '02-m365-discovery' -Data $data
Write-Host "Wrote report: $reportPath"
