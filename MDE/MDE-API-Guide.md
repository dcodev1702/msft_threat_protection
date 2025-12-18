# Microsoft Defender for Endpoint API - Software Inventory Guide
## Azure Commercial & Azure US Government

<img width="1010" height="1250" alt="image" src="https://github.com/user-attachments/assets/eb114c93-4b6e-4c05-bdb9-9ca49e327096" />


---

## API Documentation
**Software Inventory API:** https://learn.microsoft.com/en-us/defender-endpoint/api/get-software

**Azure Government Endpoints:** https://learn.microsoft.com/en-us/defender-endpoint/gov

---

## Choose Your Environment

### Azure Commercial (Worldwide)
| Endpoint Type | URL |
|--------------|-----|
| Authentication | `https://login.microsoftonline.com` |
| Auth Endpoint  | `$AuthEndpoint = (Get-AzContext).Environment.ActiveDirectoryAuthority` |
| MDE API | `https://api.securitycenter.microsoft.com` |
| API Scope | `https://api.securitycenter.microsoft.com/Software.Read` |
| Redirect URI #1 | `https://login.microsoftonline.com/common/oauth2/nativeclient` |
| Redirect URI #2 | `msal6aa843c2-fdf2-4622-a627-61a285a4e5c1://auth` |

### Azure US Government (GCC High / DoD / IL-5)
| Endpoint Type | URL |
|--------------|-----|
| Authentication | `https://login.microsoftonline.us` |
| Auth Endpoint  | `$AuthEndpoint = (Get-AzContext).Environment.ActiveDirectoryAuthority` |
| MDE API | `https://api-gov.securitycenter.microsoft.us` |
| API Scope | `https://api.securitycenter.microsoft.us/Software.Read` |
| Redirect URI #1 | `https://login.microsoftonline.us/common/oauth2/nativeclient` |
| Redirect URI #2 | `msal6aa843c2-fdf2-4622-a627-61a285a4e5c1://auth` |

**Important:** Make sure you use the correct endpoints for your environment. Mixing Commercial and Government endpoints will cause authentication failures.

---

## Prerequisites

### 1. Required PowerShell Module
```powershell
# Install MSAL.PS for authentication
Install-Module -Name MSAL.PS -Scope CurrentUser -Force
```

### 2. Azure AD App Registration (One-time Setup)
You'll need an admin to create an app registration in Azure AD:

1. Navigate to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Click **New registration**
3. Name: `MDE-API-Reader` (or your choice)
4. Supported account types: **Accounts in this organizational directory only**
5. Click **Register**

**Important:** For user-context authentication (delegated permissions), you do **NOT** need a client secret. The MSAL.PS module handles authentication using your Entra ID credentials interactively.

### 2.1 Configure Redirect URIs (Required for Interactive Auth)
After creating the app, configure redirect URIs for MSAL.PS:

1. In your app, go to **Authentication** → **Add a platform**
2. Select **Mobile and desktop applications**
3. Check **BOTH** of these boxes:

**For Azure Commercial:**
   - ✅ `https://login.microsoftonline.com/common/oauth2/nativeclient`
   - ✅ `msal6aa843c2-fdf2-4622-a627-61a285a4e5c1://auth (MSAL only)`

**For Azure US Government:**
   - ✅ `https://login.microsoftonline.us/common/oauth2/nativeclient`
   - ✅ `msal6aa843c2-fdf2-4622-a627-61a285a4e5c1://auth (MSAL only)`

4. Click **Configure**

**Note:** Both redirect URIs are required. MSAL.PS uses the first URI by default for interactive authentication flows. The second MSAL URI is the same for both environments.

### 3. Grant API Permissions (Admin Required)
1. In your app, go to **API Permissions** → **Add permission**
2. Select **APIs my organization uses** → Search for `WindowsDefenderATP`
3. Select **WindowsDefenderATP**
4. Choose **Delegated permissions**
5. Select: `Software.Read` or `Software.Read.All`
6. Click **Add permissions**
7. Admin must click **Grant admin consent**

**Note:** Only delegated permissions are needed. No application permissions or client secrets required.

<img width="1603" height="876" alt="image" src="https://github.com/user-attachments/assets/bd5a68d3-202a-4b1d-9336-6590ebd4e674" />

### 4. Copy Required IDs
From the app's **Overview** page:
- **Application (client) ID**
- **Directory (tenant) ID**

You do **NOT** need to create a client secret for this setup.

---

## PowerShell Code

### Connection Script

**Option 1: Azure Commercial**
```powershell
# Azure Commercial MDE API Connection
# Replace with your actual IDs
$TenantId = "YOUR-TENANT-ID"
$ClientId = "YOUR-APP-CLIENT-ID"

# Azure Commercial endpoints
$AuthEndpoint = "https://login.microsoftonline.com"
$ApiEndpoint = "https://api.securitycenter.microsoft.com"

# Define the API scope for MDE
$Scopes = @("https://api.securitycenter.microsoft.com/Software.Read")

# Get authentication token (interactive)
Write-Host "Authenticating to Azure Commercial..." -ForegroundColor Cyan
$MsalParams = @{
    ClientId  = $ClientId
    TenantId  = $TenantId
    Scopes    = $Scopes
}

$AuthResult = Get-MsalToken @MsalParams
$Token = $AuthResult.AccessToken

Write-Host "✓ Authentication successful" -ForegroundColor Green
```

**Option 2: Azure US Government (GCC High / DoD)**
```powershell
# Azure Government (GCC High / DoD) MDE API Connection
# Replace with your actual IDs
$TenantId = "YOUR-TENANT-ID"
$ClientId = "YOUR-APP-CLIENT-ID"

# Azure Government endpoints (IL-5)
$AuthEndpoint = "https://login.microsoftonline.us"
$ApiEndpoint = "https://api-gov.securitycenter.microsoft.us"

# Define the API scope for MDE
$Scopes = @("https://api.securitycenter.microsoft.us/Software.Read")

# Get authentication token (interactive)
Write-Host "Authenticating to Azure Government..." -ForegroundColor Cyan
$MsalParams = @{
    ClientId  = $ClientId
    TenantId  = $TenantId
    Scopes    = $Scopes
    Authority = "$AuthEndpoint/$TenantId"
}

$AuthResult = Get-MsalToken @MsalParams
$Token = $AuthResult.AccessToken

Write-Host "✓ Authentication successful" -ForegroundColor Green
```

### Query Software Inventory
```powershell
# Get software inventory from MDE
$Headers = @{
    'Authorization' = "Bearer $Token"
    'Content-Type'  = 'application/json'
}

# API endpoint for software inventory
$Uri = "$ApiEndpoint/api/Software"

Write-Host "Querying software inventory..." -ForegroundColor Cyan

try {
    $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get
    
    # Display results
    Write-Host "✓ Retrieved $($Response.value.Count) software entries" -ForegroundColor Green
    
    # Show first 5 results as example
    $Response.value | Select-Object -First 5 | Format-Table name, vendor, exposedMachines
    
    # Export all results to CSV
    $Response.value | Export-Csv -Path ".\MDE-Software-Inventory.csv" -NoTypeInformation
    Write-Host "✓ Full results exported to MDE-Software-Inventory.csv" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}
```

### Query Software by Device (Alternative)
```powershell
# Get software inventory per device
$Uri = "$ApiEndpoint/api/machines/SoftwareInventoryByMachine"

$Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get

# Process results
$Response.value | Select-Object deviceName, softwareName, softwareVendor, softwareVersion | 
    Export-Csv -Path ".\MDE-Software-By-Device.csv" -NoTypeInformation
```

---

## Complete Example Scripts

### Azure Commercial - Complete Script
```powershell
# Complete MDE Software Inventory Script for Azure Commercial
# Requires: MSAL.PS module

# Configuration
$TenantId = "YOUR-TENANT-ID"
$ClientId = "YOUR-APP-CLIENT-ID"
$AuthEndpoint = "https://login.microsoftonline.com"
$ApiEndpoint = "https://api.securitycenter.microsoft.com"

# Authenticate
$MsalParams = @{
    ClientId  = $ClientId
    TenantId  = $TenantId
    Scopes    = @("https://api.securitycenter.microsoft.com/Software.Read")
}

$AuthResult = Get-MsalToken @MsalParams
$Headers = @{
    'Authorization' = "Bearer $($AuthResult.AccessToken)"
    'Content-Type'  = 'application/json'
}

# Query API
$Response = Invoke-RestMethod -Uri "$ApiEndpoint/api/Software" -Headers $Headers -Method Get

# Export results
$Response.value | Export-Csv -Path ".\MDE-Software-Inventory.csv" -NoTypeInformation

Write-Host "Complete! Found $($Response.value.Count) software entries" -ForegroundColor Green
```

### Azure US Government - Complete Script
```powershell
# Complete MDE Software Inventory Script for Azure Government
# Requires: MSAL.PS module

# Configuration
$TenantId = "YOUR-TENANT-ID"
$ClientId = "YOUR-APP-CLIENT-ID"
$AuthEndpoint = "https://login.microsoftonline.us"
$ApiEndpoint = "https://api-gov.securitycenter.microsoft.us"

# Authenticate
$MsalParams = @{
    ClientId  = $ClientId
    TenantId  = $TenantId
    Scopes    = @("https://api.securitycenter.microsoft.us/Software.Read")
    Authority = "$AuthEndpoint/$TenantId"
}

$AuthResult = Get-MsalToken @MsalParams
$Headers = @{
    'Authorization' = "Bearer $($AuthResult.AccessToken)"
    'Content-Type'  = 'application/json'
}

# Query API
$Response = Invoke-RestMethod -Uri "$ApiEndpoint/api/Software" -Headers $Headers -Method Get

# Export results
$Response.value | Export-Csv -Path ".\MDE-Software-Inventory.csv" -NoTypeInformation

Write-Host "Complete! Found $($Response.value.Count) software entries" -ForegroundColor Green
```

---

## API Endpoints Reference

### Authentication & API Endpoints by Environment

| Environment | Login Endpoint | API Endpoint |
|-------------|---------------|--------------|
| **Azure Commercial** | `https://login.microsoftonline.com` | `https://api.securitycenter.microsoft.com` |
| **GCC High** | `https://login.microsoftonline.us` | `https://api-gov.securitycenter.microsoft.us` |
| **DoD** | `https://login.microsoftonline.us` | `https://api-gov.securitycenter.microsoft.us` |

### Available Software APIs (Same for All Environments)
| Endpoint | Description |
|----------|-------------|
| `/api/Software` | Organization-wide software inventory |
| `/api/machines/SoftwareInventoryByMachine` | Software inventory per device |
| `/api/machines/SoftwareInventoryExport` | Bulk export (for large datasets) |

---

## Beginner's Guide: How to Connect to APIs

### Understanding the Authentication Flow

1. **App Registration**
   - Think of this as creating a "service account" for your scripts
   - The app gets permissions instead of using your personal account directly

2. **OAuth2 Authentication**
   - You authenticate using your Entra ID credentials
   - The system generates a temporary token (valid for 1 hour)
   - This token proves you have permission to access the API

3. **Making API Calls**
   - Include the token in the `Authorization` header
   - The API validates your token and returns data
   - Token format: `Bearer <your-token-here>`

### Common Authentication Patterns

#### User Context (Delegated - What You're Using)
```powershell
# User logs in interactively
# Token represents: "User X, acting through App Y"
# Best for: Interactive scripts, user-specific actions
# Requires: NO client secret - just your Entra ID credentials
$Token = Get-MsalToken -ClientId $ClientId -TenantId $TenantId -Scopes $Scopes
```

#### App Context (Application Permissions)
```powershell
# App authenticates with a secret (no user login)
# Token represents: "App X, acting independently"
# Best for: Automated scripts, scheduled tasks, background services
# Requires: Client Secret or Certificate
# Note: This is NOT what you need for your scenario
```

**Key Difference:**
- **Delegated (User Context):** You authenticate with your user account. No client secret needed. MSAL.PS prompts you to sign in.
- **Application (App Context):** The app authenticates on its own using a secret. User doesn't log in. Requires client secret/certificate.

### Making API Requests

Basic structure of an API call:
```powershell
# 1. Prepare headers with your token
$Headers = @{
    'Authorization' = "Bearer $Token"
    'Content-Type'  = 'application/json'
}

# 2. Define the API endpoint URL
$Uri = "https://api-gov.securitycenter.microsoft.us/api/Software"

# 3. Make the request
$Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get

# 4. Process the results
$Response.value  # Contains the actual data
```

### Troubleshooting Common Issues

**AADSTS50011 - "No reply address is registered" or "Redirect URI mismatch"**
- The app registration is missing redirect URIs for interactive authentication
- Go to **Authentication** → **Add platform** → **Mobile and desktop applications**
- Add BOTH redirect URIs (see section 2.1 above)
- Make sure you use the correct URI for your environment (.com for Commercial, .us for Government)

**HTTP 401 - "Unauthorized" / "Invalid token"**
- Token expired (they last 1 hour) - just re-authenticate
- Using wrong endpoint for your environment (Commercial vs Government)
- Token doesn't have the required scopes/permissions
- Mixing Commercial and Government endpoints in the same script

**HTTP 403 - "Forbidden" / "Access denied"**
- Check that admin granted consent for the app permissions
- Verify your user account has the right roles (Security Reader, Global Reader, etc.)
- Your account may not have permission to access the specific resource
- Verify the app registration has the correct delegated permissions

**HTTP 404 - "Resource not found"**
- Make sure you're using the correct API endpoint for your environment
- Commercial endpoints won't work with Government tenants (and vice versa)
- Verify the API path is correct (check for typos)
- The specific resource you're querying may not exist

---

## Additional Resources

- **MDE API Documentation:** https://learn.microsoft.com/en-us/defender-endpoint/api/apis-intro
- **MSAL.PS Module:** https://github.com/AzureAD/MSAL.PS
- **Azure Government Docs:** https://learn.microsoft.com/en-us/defender-endpoint/gov

---

## Notes

- **No client secret required** - User-context authentication uses your Entra ID credentials via MSAL.PS
- Only **delegated permissions** on WindowsDefenderATP are needed (e.g., Software.Read)
- **Environment consistency is critical** - All endpoints (auth, API, scopes, redirect URIs) must match your environment
- Tokens expire after 1 hour - re-authenticate as needed
- Rate limits: 30 calls/minute, 1,000 calls/hour for most APIs
- MSAL.PS handles token caching automatically (speeds up repeated calls)
- For large datasets, use the bulk export APIs

### Environment Quick Reference
**Commercial:** Use `.com` endpoints  
**Government:** Use `.us` endpoints
