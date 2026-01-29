#!/usr/bin/env pwsh

$Org = "urholm"
$PatName = "mcp-server-$(Get-Date -Format 'yyyyMMdd')"
$ValidTo = (Get-Date).AddDays(7).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Scopes for MCP server
$Scopes = "vso.work vso.code vso.build"

$Body = @{
    displayName = $PatName
    scope = $Scopes
    validTo = $ValidTo
    allOrgs = $false
} | ConvertTo-Json

$Response = az rest --method post `
    --uri "https://vssps.dev.azure.com/$Org/_apis/tokens/pats?api-version=7.1-preview.1" `
    --resource "499b84ac-1321-427f-aa17-267ca6975798" `
    --body $Body `
    --headers "Content-Type=application/json" | ConvertFrom-Json

$Response.patToken.token
