Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$config = Get-ToolkitConfig
Initialize-Toolkit -Config $config

$moduleNames = @(
    'MicrosoftTeams',
    'ExchangeOnlineManagement',
    'Microsoft.Online.SharePoint.PowerShell',
    'Microsoft.Graph',
    'Az.Accounts',
    'Az.Resources',
    'Microsoft.PowerApps.Administration.PowerShell',
    'Microsoft.PowerApps.PowerShell'
)

$commandNames = @(
    'Connect-MicrosoftTeams',
    'Get-TeamsApp',
    'Get-CsTeamsAppPermissionPolicy',
    'Get-CsTeamsAppSetupPolicy',
    'Connect-ExchangeOnline',
    'Connect-MgGraph',
    'Invoke-MgGraphRequest',
    'Connect-AzAccount',
    'Get-AzResource',
    'Add-PowerAppsAccount',
    'Get-AdminPowerAppEnvironment',
    'Get-AdminFlow'
)

$data = [pscustomobject]@{
    GeneratedAt   = (Get-Date).ToString('s')
    Machine       = $env:COMPUTERNAME
    PowerShell    = $PSVersionTable.PSVersion.ToString()
    EnvSummary    = Get-PlainTextEnvSummary -Config $config
    Modules       = Get-InstalledModuleInfo -Names $moduleNames
    Commands      = Get-CommandPresence -Names $commandNames
}

$reportPath = Write-ToolkitReport -Config $config -Name '01-prereqs' -Data $data
Write-Host "Wrote report: $reportPath"
