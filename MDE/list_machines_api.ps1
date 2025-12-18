<#
Date: 21 Jan 2025
Author: DCODEV1702 w/ AI.

#>
# -----------------------------------
# Create an App Registration in Entra ID
# Create a secret and copy the value
# Variables - replace with your own
# -----------------------------------
$tenantId     = "PASTE_TENANT_ID_HERE"
$clientId     = "PASTE_CLIENT_ID_HERE"
$clientSecret = "PASTE_CLIENT_SECRET_HERE"

# The resource scope for Defender for Endpoint
# Set additional scopes in the App Registration -> API Permissions
$scope = "https://api.securitycenter.microsoft.com/.default"

# -----------------------------------
# 1) Acquire an OAuth token
# -----------------------------------

# Build the token endpoint
$authEndpoint = (Get-AzContext).Environment.ActiveDirectoryAuthority
$tokenEndpoint = "$authEndpoint/$tenantId/oauth2/v2.0/token"

# Body for the OAuth 2.0 client_credentials flow
$body = [ordered]@{
    client_id     = $clientId
    scope         = $scope
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

try {
    # Request the token
    $tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenEndpoint -Body $body
    $accessToken = $tokenResponse.access_token
    Write-Host "Access token successfully retrieved."
}
catch {
    Write-Error "Failed to retrieve token: $_"
    return
}

# -----------------------------------
# 2) Call Defender for Endpoint API
# -----------------------------------
# Example: Get a list of machines
# Source: https://learn.microsoft.com/en-us/defender-endpoint/api/get-machines
$mdeEndpoint = "https://api.security.microsoft.com/api/machines"

# Construct the Authorization header
$headers = @{
    'Content-Type' = 'application/json'
    Accept = 'application/json'
    Authorization = "Bearer $accessToken"
}

try {
    # Make the REST API call
    $machinesResponse = Invoke-RestMethod -Method GET -Uri $mdeEndpoint -Headers $headers
    Write-Host "Machines retrieved from MDE API:"
    $machinesResponse | ConvertTo-Json | Write-Host
}
catch {
    Write-Error "Failed to retrieve machines: $_"
}
