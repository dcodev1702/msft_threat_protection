# New-ADUser -Name "John Snow" -GivenName "John" -Surname "Snow" -SamAccountName "jsnow" -UserPrincipalName "jsnow@hawk-ir.local" -Path "CN=Users,DC=hawk-ir,DC=local" -AccountPassword (ConvertTo-SecureString "Passw0rd123!@#" -AsPlainText -Force) -Enabled $true

Import-Module ActiveDirectory

$password = ConvertTo-SecureString "Passw0rd123!@#" -AsPlainText -Force
$path = "CN=Users,DC=hawk-ir,DC=local"

$users = @(
    @("John Snow", "John", "Snow", "jsnow", "jsnow@hawk-ir.local"),
    @("Lorenzo Ireland", "Lorenzo", "Ireland", "gcc", "gcc@hawk-ir.local"),
    @("Jon Butler", "Jon", "Butler", "jjbottles", "jjbottles@hawk-ir.local"),
    @("Paul Navarro", "Paul", "Navarro", "pjhawk", "pjhawk@hawk-ir.local"),
    @("Ron HD", "Ron", "HD", "ronhd", "ronhd@hawk-ir.local"),
    @("Destiny Staton", "Destiny", "Staton", "dstaton", "dstaton@hawk-ir.local")
    
)

foreach ($user in $users) {
    $userDetails = [ordered]@{
        Name               = $user[0]
        GivenName          = $user[1]
        Surname            = $user[2]
        SamAccountName     = $user[3]
        UserPrincipalName  = $user[4]
        Path               = $path
        AccountPassword    = $password
        Enabled            = $true
    }
    New-ADUser @userDetails
}

# Extract SamAccountNames from the $users array
$samAccountNames = $users | ForEach-Object { $_[3] }

# Add all users to the Domain Admins group
Add-ADGroupMember -Identity "Domain Admins" -Members $samAccountNames

Get-ADGroupMember -Identity "Domain Admins"


# Enumeration of AD environment & sensitive groups
net user /domain 
net group /domain
net group "Domain Admins" /domain
net group "Enterprise Admins" /domain 
net group "Schema Admins" /domain

# Suspicious additions to sensitive groups
net user RonHD Passw0rd123 /FULLNAME:"Ron HD" /DOMAIN /add
Invoke-Command -ComputerName zolab-win11-az- -ScriptBlock { net localgroup Administrators hawk-ir.local\RonHD /add }
