Set-StrictMode -Version Latest

function Get-ToolkitRoot {
    return Split-Path -Parent $PSScriptRoot
}

function Import-ToolkitEnv {
    param(
        [string]$EnvPath = (Join-Path (Get-ToolkitRoot) '.env')
    )

    $values = @{}

    if (-not (Test-Path $EnvPath)) {
        return $values
    }

    foreach ($line in Get-Content -Path $EnvPath) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $trimmed = $line.Trim()
        if ($trimmed.StartsWith('#')) {
            continue
        }

        $parts = $trimmed -split '=', 2
        if ($parts.Count -ne 2) {
            continue
        }

        $key = $parts[0].Trim()
        $value = $parts[1].Trim()

        $values[$key] = $value
        Set-Item -Path ("Env:{0}" -f $key) -Value $value
    }

    return $values
}

function Get-ToolkitConfig {
    $envValues = Import-ToolkitEnv
    $toolkitRoot = Get-ToolkitRoot
    $outputDirName = if ($envValues.ContainsKey('OUTPUT_DIR') -and $envValues['OUTPUT_DIR']) { $envValues['OUTPUT_DIR'] } else { 'output' }
    $runLiveValue = 'false'
    if ($envValues.ContainsKey('RUN_LIVE_QUERIES') -and $envValues['RUN_LIVE_QUERIES']) {
        $runLiveValue = $envValues['RUN_LIVE_QUERIES']
    }

    return [pscustomobject]@{
        ToolkitRoot      = $toolkitRoot
        OutputRoot       = Join-Path $toolkitRoot $outputDirName
        RunLiveQueries   = ($runLiveValue.ToLowerInvariant() -eq 'true')
        TenantId         = $envValues['TENANT_ID']
        TenantDomain     = $envValues['TENANT_DOMAIN']
        DefaultUserUpn   = $envValues['DEFAULT_USER_UPN']
        SubscriptionId   = $envValues['AZURE_SUBSCRIPTION_ID']
        ResourceGroup    = $envValues['AZURE_RESOURCE_GROUP']
        PowerPlatformEnv = $envValues['POWER_PLATFORM_ENVIRONMENT_ID']
        GraphClientId    = $envValues['GRAPH_CLIENT_ID']
        GraphClientSecret = $envValues['GRAPH_CLIENT_SECRET']
        MsgGraphSkillPath = if ($envValues['MSGRAPH_SKILL_PATH']) {
            $envValues['MSGRAPH_SKILL_PATH']
        } else {
            Join-Path $toolkitRoot '..\..\skills\msgraph'
        }
    }
}

function Initialize-Toolkit {
    param(
        [pscustomobject]$Config
    )

    foreach ($path in @($Config.OutputRoot, (Join-Path $Config.OutputRoot 'json'))) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

function Write-ToolkitReport {
    param(
        [pscustomobject]$Config,
        [string]$Name,
        [object]$Data
    )

    $jsonPath = Join-Path (Join-Path $Config.OutputRoot 'json') ("{0}.json" -f $Name)
    $Data | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding utf8
    return $jsonPath
}

function Get-InstalledModuleInfo {
    param(
        [string[]]$Names
    )

    $items = foreach ($name in $Names) {
        $module = Get-Module -ListAvailable -Name $name | Sort-Object Version -Descending | Select-Object -First 1
        [pscustomobject]@{
            Name      = $name
            Installed = [bool]$module
            Version   = if ($module) { $module.Version.ToString() } else { $null }
            Path      = if ($module) { $module.Path } else { $null }
        }
    }

    return $items
}

function Get-CommandPresence {
    param(
        [string[]]$Names
    )

    $items = foreach ($name in $Names) {
        $command = Get-Command -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
        [pscustomobject]@{
            Name        = $name
            Available   = [bool]$command
            CommandType = if ($command) { $command.CommandType.ToString() } else { $null }
            Source      = if ($command) { $command.Source } else { $null }
        }
    }

    return $items
}

function Invoke-SafeStep {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock
    )

    try {
        $result = & $ScriptBlock
        return [pscustomobject]@{
            Name    = $Name
            Success = $true
            Error   = $null
            Result  = $result
        }
    } catch {
        return [pscustomobject]@{
            Name    = $Name
            Success = $false
            Error   = $_.Exception.Message
            Result  = $null
        }
    }
}

function Get-PlainTextEnvSummary {
    param(
        [pscustomobject]$Config
    )

    return [pscustomobject]@{
        RunLiveQueries        = $Config.RunLiveQueries
        TenantIdConfigured    = -not [string]::IsNullOrWhiteSpace($Config.TenantId)
        TenantDomainConfigured = -not [string]::IsNullOrWhiteSpace($Config.TenantDomain)
        DefaultUserConfigured = -not [string]::IsNullOrWhiteSpace($Config.DefaultUserUpn)
        SubscriptionConfigured = -not [string]::IsNullOrWhiteSpace($Config.SubscriptionId)
        PowerPlatformConfigured = -not [string]::IsNullOrWhiteSpace($Config.PowerPlatformEnv)
        GraphClientConfigured = -not [string]::IsNullOrWhiteSpace($Config.GraphClientId)
        GraphSkillPath        = $Config.MsgGraphSkillPath
        GraphSkillExists      = Test-Path $Config.MsgGraphSkillPath
    }
}
