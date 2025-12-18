# Entra ID App Registration: Application vs Delegated Permissions

## PIM (Privileged Identity Management) Requirements

> **Important**: This environment uses Entra ID PIM. You must **activate** your eligible role before performing privileged operations.

### Activating Your Role

1. Go to **Entra ID** → **Identity Governance** → **Privileged Identity Management**
2. Select **My roles** → **Entra ID roles**
3. Find your eligible role (e.g., Cloud Application Administrator) and click **Activate**
4. Provide justification and set duration
5. Wait for activation to complete before proceeding

### Roles Requiring Activation

| Task | Role to Activate |
|------|------------------|
| Create App Registration | Application Developer, Application Administrator, or Cloud Application Administrator |
| Grant Admin Consent | Global Administrator, Privileged Role Administrator, or Cloud Application Administrator |
| Assign Users to Enterprise App | Cloud Application Administrator or Application Administrator |

> **Tip**: Role activations are time-limited. Plan your work accordingly and request sufficient duration when activating.

---

## Overview

When accessing Microsoft APIs like WindowsDefenderATP (Defender for Endpoint), there are two permission models:

| Aspect | Application | Delegated |
|--------|-------------|-----------|
| **Context** | App acts as itself (no user) | App acts on behalf of a signed-in user |
| **Use Case** | Automation, services, scheduled tasks | Interactive apps, user-driven actions |
| **Auth Flow** | Client Credentials | Device Code, Authorization Code, Interactive |
| **Permissions Scope** | Tenant-wide access | Limited to user's own access level |
| **User Present** | No | Yes |

---

## Permissions to Create and Configure an App Registration

### To Create an App Registration

- **Minimum Role**: Cloud Application Administrator, Application Administrator, or Application Developer
- Users can also self-register apps if "Users can register applications" is enabled in Entra ID (User settings)

### To Grant Admin Consent for API Permissions

- **Required Role**: Global Administrator, Privileged Role Administrator, or Cloud Application Administrator

### To Assign Users/Groups to the App Registration

1. Go to **Enterprise Applications** (not App Registrations)
2. Find your app by name or client ID
3. Go to **Users and groups** → **Add user/group**
4. Select users or groups that should be allowed to use the app

> **Note**: User assignment is only enforced if "Assignment required?" is set to **Yes** under Enterprise Application → Properties.

---

## WindowsDefenderATP Permission Examples

### Application Permissions (app acts alone)

| Permission | Description |
|------------|-------------|
| Machine.Read.All | Read all machine info |
| Alert.Read.All | Read all alerts |
| AdvancedQuery.Read.All | Run hunting queries |

### Delegated Permissions (app + user)

| Permission | Description |
|------------|-------------|
| Machine.Read | Read machine info the user has access to |
| Alert.Read | Read alerts the user has access to |
| AdvancedQuery.Read | Run queries as the user |

---

## PowerShell Authentication Examples

### Application Flow (Client Credentials)

```powershell
<#
    APPLICATION AUTHENTICATION (Client Credentials Flow)
    - No user interaction required
    - App authenticates as itself using a secret or certificate
    - Uses Application permissions (not Delegated)
    - Ideal for: scheduled tasks, automation, background services
#>

$tenantId     = "YOUR_TENANT_ID"
$clientId     = "YOUR_CLIENT_ID"
$clientSecret = "YOUR_CLIENT_SECRET"
$scope        = "https://api.securitycenter.microsoft.com/.default"

$tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

$body = @{
    client_id     = $clientId
    scope         = $scope
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

$tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenEndpoint -Body $body
$accessToken = $tokenResponse.access_token

# Use the token
$headers = @{ Authorization = "Bearer $accessToken" }
$machines = Invoke-RestMethod -Uri "https://api.security.microsoft.com/api/machines" -Headers $headers
```

---

### Delegated Flow (Device Code)

```powershell
<#
    DELEGATED AUTHENTICATION (Device Code Flow)
    - Requires user interaction (sign-in via browser)
    - App acts on behalf of the signed-in user
    - Uses Delegated permissions
    - Access is limited to what the user can see/do
    - Ideal for: CLI tools, scripts run by users, interactive scenarios
#>

$tenantId = "YOUR_TENANT_ID"
$clientId = "YOUR_CLIENT_ID"
$scope    = "https://api.securitycenter.microsoft.com/Machine.Read offline_access"

# Step 1: Request device code
$deviceCodeEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/devicecode"

$deviceCodeResponse = Invoke-RestMethod -Method POST -Uri $deviceCodeEndpoint -Body @{
    client_id = $clientId
    scope     = $scope
}

# Display instructions to user
Write-Host $deviceCodeResponse.message -ForegroundColor Yellow
# Example output: "To sign in, use a web browser to open https://microsoft.com/devicelogin and enter the code XXXXXXXX"

# Step 2: Poll for token (user completes sign-in in browser)
$tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

$tokenBody = @{
    client_id   = $clientId
    grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
    device_code = $deviceCodeResponse.device_code
}

# Simple polling loop
$accessToken = $null
while (-not $accessToken) {
    Start-Sleep -Seconds $deviceCodeResponse.interval
    try {
        $tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenEndpoint -Body $tokenBody
        $accessToken = $tokenResponse.access_token
        Write-Host "Authentication successful." -ForegroundColor Green
    }
    catch {
        $errorMsg = $_.ErrorDetails.Message | ConvertFrom-Json
        if ($errorMsg.error -eq "authorization_pending") {
            Write-Host "Waiting for user to authenticate..." -ForegroundColor Gray
        }
        elseif ($errorMsg.error -eq "expired_token") {
            Write-Error "Device code expired. Please restart."
            return
        }
        else {
            throw $_
        }
    }
}

# Use the token (results scoped to user's access)
$headers = @{ Authorization = "Bearer $accessToken" }
$machines = Invoke-RestMethod -Uri "https://api.security.microsoft.com/api/machines" -Headers $headers
```

---

## Quick Reference: When to Use Which

| Scenario | Use |
|----------|-----|
| Scheduled task pulling alerts nightly | Application |
| SIEM integration running as a service | Application |
| Admin running a script interactively | Delegated |
| Help desk tool for analysts | Delegated |
| Automated remediation pipeline | Application |

---

## User Assignment Summary

### For Delegated Flows

Users must:

1. Be assigned to the Enterprise Application (if assignment is required)
2. Have the appropriate MDE RBAC role (Security Reader, Security Operator, etc.)
3. Sign in when prompted

### For Application Flows

- No user assignment needed
- The app itself has tenant-wide access based on granted Application permissions
- Secure the client secret/certificate carefully

---

## References

- [MDE API Overview](https://learn.microsoft.com/en-us/defender-endpoint/api/apis-intro)
- [Create App for MDE API](https://learn.microsoft.com/en-us/defender-endpoint/api/exposed-apis-create-app-webapp)
- [Microsoft Identity Platform - Client Credentials](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow)
- [Microsoft Identity Platform - Device Code](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code)
