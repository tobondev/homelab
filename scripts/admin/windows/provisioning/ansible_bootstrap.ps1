$ErrorActionPreference = 'Stop'
$PubKeyUrl = "http://curious-aristocrat-ubuntu-fileserver.tobon.dev/ansible_ed25519.pub"
$AdminKeyFile = "$env:ProgramData\ssh\administrators_authorized_keys"

Write-Host "Setting Keyboard Layout to Dvorak..."
$List = Get-WinUserLanguageList
$List[0].InputMethodTips.Clear()
$List[0].InputMethodTips.Add('0409:00010409')
Set-WinUserLanguageList $List -Force
Write-Host "Setting SystemLocale to Dvorak..."
Set-WinSystemLocale -SystemLocale en-DV
Write-Host "Overriding Default Input Method..."
Set-WinDefaultInputMethodOverride -InputTip "0409:00010409"


if ((Get-WindowsCapability -Online -Name OpenSSH.Server*).State -ne 'Installed') {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}
# Enable SSH service for manageability
Set-Service -Name sshd -StartupType 'Automatic'
# Set Powershell as Default for SSH
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
# Confirm the Firewall rule is configured.
if ((Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" | Where-Object -Property "Profile" -NotMatch "Domain, Private" -ErrorAction SilentlyContinue)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist or isn't properly configured. Fixing."
    Remove-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Profile "Domain, Private" -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' exists and is properly configured."
}


    Set-NetFirewallProfile -Profile "Domain" -Enabled True -ErrorAction SilentlyContinue
    Set-NetFirewallProfile -Profile "Private" -Enabled True -ErrorAction SilentlyContinue
    Set-NetFirewallProfile -Profile "Public" -Enabled False -ErrorAction SilentlyContinue


New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force | Out-Null

Write-Host "Fetching Ansible Public Key..."
$PubKey = Invoke-RestMethod -Uri $PubKeyUrl

Write-Host "Setting up Authorized Keys..."
if (-not (Test-Path "$env:ProgramData\ssh")) { New-Item -Path "$env:ProgramData\ssh" -ItemType Directory | Out-Null }
Set-Content -Path $AdminKeyFile -Value $PubKey -Force

# OpenSSH on Windows requires strict ACLs on the administrators_authorized_keys file
$Acl = Get-Acl $AdminKeyFile
$Acl.SetAccessRuleProtection($true, $false)
$AdministratorsRule = New-Object system.security.accesscontrol.filesystemaccessrule("Administrators","FullControl","Allow")
$SystemRule = New-Object system.security.accesscontrol.filesystemaccessrule("SYSTEM","FullControl","Allow")
$Acl.SetAccessRule($AdministratorsRule)
$Acl.SetAccessRule($SystemRule)
Set-Acl -Path $AdminKeyFile -AclObject $Acl
Write-Host "Starting SSH Service..."
Start-Service sshd

Write-Host "Bootstrap Complete. Ready for Ansible." -ForegroundColor Green
