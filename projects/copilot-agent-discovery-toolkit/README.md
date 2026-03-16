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

## How to use

1. Review and update `.env`
2. Open PowerShell in this project folder
3. Run:

```powershell
.\scripts\Start-DiscoveryMenu.ps1
```

If you want the scripts to attempt live read-only tenant queries, set `RUN_LIVE_QUERIES=true` in `.env` and make sure you are already authenticated to the relevant modules.
