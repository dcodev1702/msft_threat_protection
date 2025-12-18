<#
.AUTHOR DCODEV1702 & Claude Sonnet 4.5
.DATE 18 DEC 2025
.SYNOPSIS
    Microsoft Defender for Endpoint API Authentication Script
    
.DESCRIPTION
    Authenticates to MDE API for both Azure Commercial and Azure US Government environments
    
.PARAMETER Environment
    Specify 'Commercial' or 'Government' (default: Commercial)
    
.EXAMPLE
    .\Connect-MDEAPI.ps1 -Environment Commercial
    .\Connect-MDEAPI.ps1 -Environment Government
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Commercial','Government')]
    [string]$Environment = 'Commercial'
)

# Configuration - Replace with your actual IDs
$TenantId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
$ClientId = "12345678-abcd-ef12-3456-7890abcdef12"

# Check and install MSAL.PS module if needed
if (-not (Get-Module -ListAvailable -Name MSAL.PS)) {
    Write-Host "MSAL.PS module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module MSAL.PS -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "✓ MSAL.PS module installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to install MSAL.PS module: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Import the MSAL.PS module
try {
    Import-Module MSAL.PS -Force -ErrorAction Stop
}
catch {
    Write-Host "✗ Failed to import MSAL.PS module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Set endpoints based on environment
$AuthEndpoint = (Get-AzContext).Environment.ActiveDirectoryAuthority
# /.default includes all of your assigned scopes (e.g. Software.Read)
switch ($Environment) {
    'Commercial' {
        $ApiEndpoint = "https://api.securitycenter.microsoft.com"
        $Scopes = @("https://api.securitycenter.microsoft.com/.default")
        Write-Host "`nEnvironment: Azure Commercial" -ForegroundColor Cyan
    }
    'Government' {
        $ApiEndpoint = "https://api-gov.securitycenter.microsoft.us"
        $Scopes = @("https://api.securitycenter.microsoft.us/.default")
        Write-Host "`nEnvironment: Azure US Government" -ForegroundColor Cyan
    }
}

Write-Host "Auth Endpoint: $AuthEndpoint" -ForegroundColor Gray
Write-Host "API Endpoint: $ApiEndpoint" -ForegroundColor Gray
Write-Host "`nAuthenticating..." -ForegroundColor Cyan

# Get authentication token
try {
    $MsalParams = @{
        ClientId  = $ClientId
        TenantId  = $TenantId
        Scopes    = $Scopes
        Authority = "$AuthEndpoint/$TenantId"
    }
    
    $AuthResult = Get-MsalToken @MsalParams -ErrorAction Stop
    $Token = $AuthResult.AccessToken
    
    Write-Host "✓ Authentication successful" -ForegroundColor Green
    Write-Host "Token expires: $($AuthResult.ExpiresOn.LocalDateTime)" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    
    # Provide helpful error messages
    if ($_.Exception.Message -like "*AADSTS50011*") {
        Write-Host "`nTroubleshooting: Missing redirect URIs in app registration" -ForegroundColor Yellow
        Write-Host "Fix: Add both redirect URIs in Azure AD App Registration > Authentication" -ForegroundColor Yellow
    }
    elseif ($_.Exception.Message -like "*AADSTS700016*") {
        Write-Host "`nTroubleshooting: Invalid client ID or tenant ID" -ForegroundColor Yellow
        Write-Host "Fix: Verify your ClientId and TenantId values" -ForegroundColor Yellow
    }
    elseif ($_.Exception.Message -like "*AADSTS65001*") {
        Write-Host "`nTroubleshooting: User consent required" -ForegroundColor Yellow
        Write-Host "Fix: Admin must grant consent for the app permissions" -ForegroundColor Yellow
    }
    
    exit 1
}

# Test API connection
Write-Host "`nTesting API connection..." -ForegroundColor Cyan

try {
    $Headers = @{
        'Authorization' = "Bearer $Token"
        'Content-Type'  = 'application/json'
    }
    
    $Uri = "$ApiEndpoint/api/Software"
    
    # Use -SkipHttpErrorCheck for PowerShell 7+, or try/catch for PS 5.1
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get -SkipHttpErrorCheck
    }
    else {
        $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get
    }
    
    if ($Response.value) {
        Write-Host "✓ API connection successful" -ForegroundColor Green
        Write-Host "Retrieved $($Response.value.Count) software entries" -ForegroundColor Green
        
        # Display sample results
        Write-Host "`nSample results (first 5):" -ForegroundColor Cyan
        $Response.value | Select-Object -First 5 | Format-Table name, vendor, exposedMachines -AutoSize
        
        # Export to CSV
        $ExportPath = ".\MDE-Software-Inventory-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        $Response.value | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "`n✓ Full results exported to: $ExportPath" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ API call succeeded but returned no data" -ForegroundColor Yellow
    }
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "✗ API call failed: $($_.Exception.Message)" -ForegroundColor Red
    
    # Provide helpful error messages based on HTTP status code
    switch ($StatusCode) {
        401 {
            Write-Host "`nHTTP 401 - Unauthorized" -ForegroundColor Yellow
            Write-Host "Possible causes:" -ForegroundColor Yellow
            Write-Host "  - Token expired (re-run the script)" -ForegroundColor Yellow
            Write-Host "  - Wrong environment endpoint" -ForegroundColor Yellow
            Write-Host "  - Missing required scopes" -ForegroundColor Yellow
        }
        403 {
            Write-Host "`nHTTP 403 - Forbidden" -ForegroundColor Yellow
            Write-Host "Possible causes:" -ForegroundColor Yellow
            Write-Host "  - User lacks required permissions (need Security Reader role)" -ForegroundColor Yellow
            Write-Host "  - App permissions not granted by admin" -ForegroundColor Yellow
        }
        404 {
            Write-Host "`nHTTP 404 - Not Found" -ForegroundColor Yellow
            Write-Host "Possible causes:" -ForegroundColor Yellow
            Write-Host "  - Wrong API endpoint for your environment" -ForegroundColor Yellow
            Write-Host "  - Check that you're using the correct environment parameter" -ForegroundColor Yellow
        }
        default {
            Write-Host "`nHTTP $StatusCode - Unexpected error" -ForegroundColor Yellow
        }
    }
    
    exit 1
}

# Export token for use in other scripts (optional)
Write-Host "`nToken stored in `$Token variable for this session" -ForegroundColor Gray
Write-Host "API Endpoint available in `$ApiEndpoint variable" -ForegroundColor Gray
