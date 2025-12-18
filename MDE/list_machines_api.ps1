<#
.SYNOPSIS
    Retrieves machine information from Microsoft Defender for Endpoint (MDE) API.

.DESCRIPTION
    This script authenticates to Microsoft Defender for Endpoint using an Entra ID
    App Registration with client credentials (OAuth 2.0 client_credentials flow).
    It then queries the MDE API to retrieve a list of onboarded machines.

.NOTES
    Date:   21 Jan 2025
    Author: DCODEV1702 w/ Claude Sonnet 4.5

    ============================================================
    APP REGISTRATION SETUP
    ============================================================
    1. Go to Entra ID (portal.azure.com) -> App registrations -> New registration
    2. Name: "MDE-API-Access" (or your preferred name)
    3. Supported account types: "Accounts in this organizational directory only"
    4. Click Register

    ============================================================
    CLIENT SECRET SETUP
    ============================================================
    1. In your App Registration -> Certificates & secrets
    2. Click "New client secret"
    3. Add a description and set expiration
    4. COPY THE SECRET VALUE IMMEDIATELY (it won't be shown again)
    5. Paste the value into $clientSecret below

    ============================================================
    API PERMISSIONS (App Registration -> API permissions)
    ============================================================
    1. Click "Add a permission"
    2. Select "APIs my organization uses"
    3. Search for "WindowsDefenderATP" and select it
    4. Choose "Application permissions" (NOT Delegated)
    5. Add the following permissions based on your needs:

       FOR THIS SCRIPT (minimum required):
       - Machine.Read.All          : Read machine information

       ADDITIONAL PERMISSIONS (add as needed):
       - Alert.Read.All            : Read alerts
       - Alert.ReadWrite.All       : Read/write alerts
       - AdvancedQuery.Read.All    : Run advanced hunting queries
       - Vulnerability.Read.All    : Read vulnerability information
       - Software.Read.All         : Read software inventory
       - Ti.ReadWrite              : Read/write threat indicators

    6. Click "Grant admin consent for <YourTenant>"
       (Requires Global Admin or Privileged Role Admin)

    ============================================================
    REFERENCES
    ============================================================
    - MDE API Overview: https://learn.microsoft.com/en-us/defender-endpoint/api/apis-intro
    - Get Machines API: https://learn.microsoft.com/en-us/defender-endpoint/api/get-machines
    - API Permissions:  https://learn.microsoft.com/en-us/defender-endpoint/api/exposed-apis-create-app-webapp

#>

# -----------------------------------
# Variables - replace with your own
# -----------------------------------
$tenantId     = "PASTE_TENANT_ID_HERE"      # Found in Entra ID -> Overview -> Tenant ID
$clientId     = "PASTE_CLIENT_ID_HERE"      # Found in App Registration -> Overview -> Application (client) ID
$clientSecret = "PASTE_CLIENT_SECRET_HERE"  # The secret VALUE (not the Secret ID)

# Resource scope for Defender for Endpoint (uses .default for all granted permissions)
$scope = "https://api.securitycenter.microsoft.com/.default"

# -----------------------------------
# 1) Acquire an OAuth token
# -----------------------------------
# Using login.microsoftonline.com directly (no Az module dependency)
$tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

# Body for OAuth 2.0 client_credentials flow
$body = @{
    client_id     = $clientId
    scope         = $scope
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

try {
    $tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenEndpoint -Body $body
    $accessToken = $tokenResponse.access_token
    Write-Host "Access token successfully retrieved." -ForegroundColor Green
}
catch {
    Write-Error "Failed to retrieve token: $_"
    return
}

# -----------------------------------
# 2) Call Defender for Endpoint API
# -----------------------------------
# Get list of machines: https://learn.microsoft.com/en-us/defender-endpoint/api/get-machines
$mdeEndpoint = "https://api.security.microsoft.com/api/machines"

$headers = @{
    'Content-Type'  = 'application/json'
    'Accept'        = 'application/json'
    'Authorization' = "Bearer $accessToken"
}

try {
    $machinesResponse = Invoke-RestMethod -Method GET -Uri $mdeEndpoint -Headers $headers
    Write-Host "Machines retrieved from MDE API:" -ForegroundColor Green
    $machinesResponse.value | Format-Table computerDnsName, osPlatform, healthStatus, onboardingStatus -AutoSize
}
catch {
    Write-Error "Failed to retrieve machines: $_"
}
