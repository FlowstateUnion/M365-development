# Copilot Agent Discovery Toolkit

Read-only PowerShell toolkit for understanding how Copilot-related agents, apps, flows, and supporting resources may be deployed across Microsoft 365, Azure, Power Automate, and Microsoft Graph.

## What this does

- inventories useful PowerShell modules and commands
- optionally runs safe read-only tenant queries when you are already authenticated
- writes JSON reports under `output/`
- provides a menu script to run the discovery scripts

## Layout

- `.env` configuration values for your tenant and output preferences
- `scripts/Start-DiscoveryMenu.ps1` interactive launcher
- `scripts/01-Check-Prereqs.ps1` module and command inventory
- `scripts/02-Discover-M365.ps1` Teams and M365 discovery options
- `scripts/03-Discover-Azure.ps1` Azure discovery options
- `scripts/04-Discover-PowerAutomate.ps1` Power Platform and flow discovery options
- `scripts/05-Discover-Graph.ps1` Graph discovery options and local Graph-skill searches

## Environment configuration

The scripts read settings from a `.env` file in the project root. This file is **excluded from source control** (via `.gitignore`) because it can contain tenant IDs, subscription IDs, and client secrets that should never be committed.

A sample is provided as `.env.sample`. To get started:

```powershell
Copy-Item .env.sample .env
```

Then fill in the values relevant to your environment:

| Variable | Purpose |
|---|---|
| `RUN_LIVE_QUERIES` | Set to `true` to run read-only tenant queries (default `false`) |
| `OUTPUT_DIR` | Directory for JSON report output (default `output`) |
| `TENANT_ID` | Your Azure AD / Entra ID tenant ID |
| `TENANT_DOMAIN` | Primary domain (e.g. `contoso.onmicrosoft.com`) |
| `DEFAULT_USER_UPN` | UPN used for user-scoped queries |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription to query |
| `AZURE_RESOURCE_GROUP` | Resource group to scope Azure discovery |
| `POWER_PLATFORM_ENVIRONMENT_ID` | Power Platform environment for flow discovery |
| `GRAPH_CLIENT_ID` | App registration client ID for app-only Graph calls |
| `GRAPH_CLIENT_SECRET` | Corresponding client secret — **keep this safe** |
| `MSGRAPH_SKILL_PATH` | Optional override for the local Graph skill folder |

> **Note:** You only need to fill in the variables for the services you plan to query. The scripts handle missing values gracefully.

## How to use

1. Copy `.env.sample` to `.env` and fill in your values
2. Open PowerShell in this project folder
3. Run:

```powershell
.\scripts\Start-DiscoveryMenu.ps1
```

If you want the scripts to attempt live read-only tenant queries, set `RUN_LIVE_QUERIES=true` in `.env` and make sure you are already authenticated to the relevant modules.
