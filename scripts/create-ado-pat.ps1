#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates an Azure DevOps Personal Access Token (PAT) for MCP server.

.DESCRIPTION
    Uses Azure CLI to create a PAT with appropriate scopes for the MCP server.
    Requires: az cli logged in with access to the target organization.

.PARAMETER Org
    Azure DevOps organization name (e.g., "myorg", "contoso")

.PARAMETER Instance
    Instance name for the PAT (used in naming, e.g., "work", "personal")

.PARAMETER ValidDays
    Number of days the PAT should be valid (default: 7)

.PARAMETER TenantId
    Optional Azure AD tenant ID. Use this if the ADO org is in a different tenant
    than your default. Find it in Azure Portal > Azure Active Directory > Overview.

.EXAMPLE
    ./create-ado-pat.ps1 -Org "myorg" -Instance "personal"
    ./create-ado-pat.ps1 -Org "contoso" -Instance "work" -ValidDays 30
    ./create-ado-pat.ps1 -Org "fabrikam" -Instance "client" -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Azure DevOps organization name")]
    [string]$Org,

    [Parameter(Mandatory=$true, HelpMessage="Instance name (e.g., work, personal)")]
    [string]$Instance,

    [Parameter(Mandatory=$false, HelpMessage="PAT validity in days")]
    [int]$ValidDays = 7,

    [Parameter(Mandatory=$false, HelpMessage="Azure AD tenant ID (if different from default)")]
    [string]$TenantId
)

# Azure DevOps resource ID (well-known Microsoft constant, same for all orgs)
$AzureDevOpsResourceId = "499b84ac-1321-427f-aa17-267ca6975798"

# Check if az cli is installed
if (-not (Get-Command "az" -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Azure CLI (az) is not installed." -ForegroundColor Red
    Write-Host "Install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# Check current login status
$Account = az account show 2>&1
$IsLoggedIn = $LASTEXITCODE -eq 0

if ($IsLoggedIn) {
    $AccountInfo = az account show | ConvertFrom-Json
    Write-Host "Currently logged in as: $($AccountInfo.user.name)" -ForegroundColor Cyan
    Write-Host "Tenant: $($AccountInfo.tenantId)" -ForegroundColor Cyan
    Write-Host ""
}

# Ask if user wants to (re)login
$LoginPrompt = if ($IsLoggedIn) { "Do you want to log in (to switch tenant/account)? [y/N]" } else { "You need to log in. Log in now? [Y/n]" }
$LoginDefault = if ($IsLoggedIn) { "N" } else { "Y" }

$DoLogin = Read-Host $LoginPrompt
if ($DoLogin -eq "") { $DoLogin = $LoginDefault }

if ($DoLogin -match "^[Yy]") {
    Write-Host "Logging in..." -ForegroundColor Cyan
    if ($TenantId) {
        Write-Host "Using tenant: $TenantId" -ForegroundColor Cyan
        az login --tenant $TenantId
    } else {
        az login
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Login failed." -ForegroundColor Red
        exit 1
    }
    $AccountInfo = az account show | ConvertFrom-Json
    Write-Host "Logged in as: $($AccountInfo.user.name)" -ForegroundColor Green
    Write-Host ""
} elseif (-not $IsLoggedIn) {
    Write-Host "Login required. Exiting." -ForegroundColor Red
    exit 1
}

$PatName = "mcp-server-$Instance-$(Get-Date -Format 'yyyyMMdd')"
$ValidTo = (Get-Date).AddDays($ValidDays).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Scopes for MCP server (write access for work items)
$Scopes = "vso.work_write vso.code_write vso.build_execute"

Write-Host "Creating PAT for organization: $Org" -ForegroundColor Cyan
Write-Host "Instance: $Instance" -ForegroundColor Cyan
Write-Host "PAT Name: $PatName" -ForegroundColor Cyan
Write-Host "Valid until: $ValidTo" -ForegroundColor Cyan
Write-Host ""

$Body = @{
    displayName = $PatName
    scope = $Scopes
    validTo = $ValidTo
    allOrgs = $false
} | ConvertTo-Json

try {
    $Response = az rest --method post `
        --uri "https://vssps.dev.azure.com/$Org/_apis/tokens/pats?api-version=7.1-preview.1" `
        --resource $AzureDevOpsResourceId `
        --body $Body `
        --headers "Content-Type=application/json" | ConvertFrom-Json

    $Token = $Response.patToken.token

    Write-Host "PAT created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Token: $Token" -ForegroundColor Yellow
    Write-Host ""

    # Show environment variable name
    $EnvVarName = "AZURE_DEVOPS_PAT_$($Instance.ToUpper().Replace('-', '_'))"
    Write-Host "Add to your shell config:" -ForegroundColor Cyan
    Write-Host "  export $EnvVarName=`"$Token`"" -ForegroundColor White
    Write-Host ""

    # Return just the token for piping
    return $Token
}
catch {
    Write-Host "Error creating PAT: $_" -ForegroundColor Red
    Write-Host "Make sure you're logged in with: az login" -ForegroundColor Yellow
    exit 1
}
