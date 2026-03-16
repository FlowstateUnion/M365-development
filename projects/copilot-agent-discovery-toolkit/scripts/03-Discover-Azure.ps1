Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$config = Get-ToolkitConfig
Initialize-Toolkit -Config $config

$azureOptions = @(
    [pscustomobject]@{ Area = 'App registrations and enterprise apps'; WhyItMatters = 'Copilot integrations often rely on Entra app registrations, enterprise apps, and service principals'; Commands = @('Get-AzADApplication', 'Get-AzADServicePrincipal') },
    [pscustomobject]@{ Area = 'Resource inventory'; WhyItMatters = 'Power Automate, Logic Apps, Functions, or API connections may support agent deployment paths'; Commands = @('Get-AzResource', 'Get-AzResourceGroup') },
    [pscustomobject]@{ Area = 'Subscription and RBAC context'; WhyItMatters = 'Helps determine where automation can run and who can manage it'; Commands = @('Get-AzSubscription', 'Get-AzRoleAssignment') }
)

$liveResults = @()
if ($config.RunLiveQueries) {
    $liveResults += Invoke-SafeStep -Name 'Subscriptions' -ScriptBlock {
        if (-not (Get-Command -Name Get-AzSubscription -ErrorAction SilentlyContinue)) {
            throw 'Get-AzSubscription is not available.'
        }

        Get-AzSubscription | Select-Object Name, Id, State
    }

    $liveResults += Invoke-SafeStep -Name 'Interesting Azure resources' -ScriptBlock {
        if (-not (Get-Command -Name Get-AzResource -ErrorAction SilentlyContinue)) {
            throw 'Get-AzResource is not available.'
        }

        $resourceTypes = @(
            'Microsoft.Logic/workflows',
            'Microsoft.Web/connections',
            'Microsoft.Web/sites',
            'Microsoft.Storage/storageAccounts',
            'Microsoft.KeyVault/vaults'
        )

        Get-AzResource | Where-Object { $_.ResourceType -in $resourceTypes } |
            Select-Object -First 50 Name, ResourceType, ResourceGroupName, Location
    }

    $liveResults += Invoke-SafeStep -Name 'Entra service principals via Az' -ScriptBlock {
        if (-not (Get-Command -Name Get-AzADServicePrincipal -ErrorAction SilentlyContinue)) {
            throw 'Get-AzADServicePrincipal is not available.'
        }

        Get-AzADServicePrincipal -First 25 | Select-Object DisplayName, AppId, Id
    }
}

$data = [pscustomobject]@{
    GeneratedAt       = (Get-Date).ToString('s')
    Scope             = 'Azure discovery for Copilot and automation deployment surfaces'
    EnvSummary        = Get-PlainTextEnvSummary -Config $config
    DiscoveryOptions  = $azureOptions
    AvailableCommands = Get-CommandPresence -Names @(
        'Connect-AzAccount',
        'Get-AzSubscription',
        'Get-AzResource',
        'Get-AzADApplication',
        'Get-AzADServicePrincipal',
        'Get-AzRoleAssignment'
    )
    LiveResults       = $liveResults
    ManualQuestions   = @(
        'Which subscriptions contain Logic Apps, API connections, or Functions used by agent workflows?',
        'Which service principals look related to Copilot Studio, Power Platform, or custom bot integrations?',
        'Which Azure resources store secrets, content, or connectors that support those agents?'
    )
}

$reportPath = Write-ToolkitReport -Config $config -Name '03-azure-discovery' -Data $data
Write-Host "Wrote report: $reportPath"
