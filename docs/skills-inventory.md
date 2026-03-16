# M365 Skills Inventory

This workspace uses globally installed Codex skills for Microsoft 365 related work.

## Installed core M365 skills

- `flowstudio-power-automate-mcp`
- `mcp-copilot-studio-server-generator`
- `microsoft-teams-automation`
- `microsoft-sharepoint`
- `powerplatform`
- `msgraph`
- `microsoft-graph`
- `m365`
- `m365-admin`
- `m365-mail`
- `m365-agents-ts`
- `entra-app-registration`
- `entra-agent-user`

## Installed PowerShell and Azure-adjacent skills

- `powershell-windows`
- `powershell-7-expert`
- `powershell-master`
- `powershell-module-architect`
- `powershell-shell-detection`
- `powershell-ui-architect`
- `azure-admin`
- `azure-devops`
- `azure-devops-cli`
- `azure-pricing`

## Installed runbook and operations skills

- `runbook-generator`
- `runbook-creation`
- `incident-runbook-templates`

## Notes

- Skills are installed globally under the user profile, not inside this repo.
- This repo now exposes those installed skills through local folder junctions under `skills/` so you can inspect each `SKILL.md`, `references/`, and `scripts/` tree from this workspace.
- `copilot-sdk` is installed, but the final installed source is the `intellectronica/agent-skills` variant because it overwrote the earlier `github/awesome-copilot` variant.
- `doggy8088/agent-skills@copilot-sdk` failed to install due to repository authentication failure.
- Some installed skills reported medium risk or a Socket alert during installation. Review before depending on them for sensitive work.

## Suggested usage split

- Use `flowstudio-power-automate-mcp`, `powerplatform`, and `mcp-copilot-studio-server-generator` for Copilot Studio and Power Automate work.
- Use `microsoft-sharepoint`, `microsoft-teams-automation`, `msgraph`, and `microsoft-graph` for M365 integration tasks.
- Use `m365-admin`, `m365-mail`, and `entra-*` skills for tenant, identity, and messaging operations.
- Use the PowerShell skills for automation, modules, and local admin tooling.
