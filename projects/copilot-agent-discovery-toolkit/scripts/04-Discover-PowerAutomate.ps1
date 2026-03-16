Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$config = Get-ToolkitConfig
Initialize-Toolkit -Config $config

$powerPlatformOptions = @(
    [pscustomobject]@{ Area = 'Power Platform environments'; WhyItMatters = 'Copilot Studio agents and flows are scoped to environments'; Commands = @('Get-AdminPowerAppEnvironment') },
    [pscustomobject]@{ Area = 'Cloud flows'; WhyItMatters = 'Agent actions are often implemented as cloud flows'; Commands = @('Get-AdminFlow') },
    [pscustomobject]@{ Area = 'Power Apps and custom connectors'; WhyItMatters = 'Agents may rely on custom connectors or app-hosted integrations'; Commands = @('Get-AdminPowerApp', 'Get-AdminConnector') }
)

$liveResults = @()
if ($config.RunLiveQueries) {
    $liveResults += Invoke-SafeStep -Name 'Power Platform environments' -ScriptBlock {
        if (-not (Get-Command -Name Get-AdminPowerAppEnvironment -ErrorAction SilentlyContinue)) {
            throw 'Get-AdminPowerAppEnvironment is not available.'
        }

        Get-AdminPowerAppEnvironment | Select-Object -First 25 DisplayName, EnvironmentName, Location
    }

    $liveResults += Invoke-SafeStep -Name 'Admin flows' -ScriptBlock {
        if (-not (Get-Command -Name Get-AdminFlow -ErrorAction SilentlyContinue)) {
            throw 'Get-AdminFlow is not available.'
        }

        $environmentName = if ($config.PowerPlatformEnv) { $config.PowerPlatformEnv } else { '*' }
        Get-AdminFlow -EnvironmentName $environmentName | Select-Object -First 25 DisplayName, FlowName, EnvironmentName, State
    }

    $liveResults += Invoke-SafeStep -Name 'Power Apps' -ScriptBlock {
        if (-not (Get-Command -Name Get-AdminPowerApp -ErrorAction SilentlyContinue)) {
            throw 'Get-AdminPowerApp is not available.'
        }

        Get-AdminPowerApp | Select-Object -First 25 DisplayName, AppName, EnvironmentName
    }
}

$data = [pscustomobject]@{
    GeneratedAt       = (Get-Date).ToString('s')
    Scope             = 'Power Automate and Power Platform discovery for Copilot deployment paths'
    EnvSummary        = Get-PlainTextEnvSummary -Config $config
    DiscoveryOptions  = $powerPlatformOptions
    AvailableCommands = Get-CommandPresence -Names @(
        'Add-PowerAppsAccount',
        'Get-AdminPowerAppEnvironment',
        'Get-AdminFlow',
        'Get-AdminPowerApp',
        'Get-AdminConnector'
    )
    LiveResults       = $liveResults
    ManualQuestions   = @(
        'Which environments host Copilot Studio bots, flows, or custom connectors?',
        'Which flows invoke SharePoint, Teams, or Graph in support of those bots?',
        'Which custom connectors expose external systems to Copilot or agent actions?'
    )
}

$reportPath = Write-ToolkitReport -Config $config -Name '04-power-automate-discovery' -Data $data
Write-Host "Wrote report: $reportPath"
