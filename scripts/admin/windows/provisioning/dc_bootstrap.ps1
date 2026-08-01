
$adFeatures = 'AD-Domain-Services', 'DNS'
foreach ($adFeature in $adFeatures) {
    if (-not(Get-WindowsFeature -Installed | Where-Object -Property "Name" -Match $adFeature -ErrorAction SilentlyContinue)){
        Get-WindowsFeature $adFeature
        Write-Output "Installing Domain Services Feature $adFeature "
    } else {
        Write-Host "Domain Services Feauter $adFeature is already installed"
    }
}

try {
    Get-ADForest -ErrorAction Stop
    Write-Output "An Active Directory forest exists."
} catch {
    Write-Host "No AD forest found or tool cannot contact one. Installing Forest"
    Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\WINDOWS\NTDS" `
    -DomainMode "Win2025" `
    -DomainName "tobon.dev" `
    -DomainNetbiosName "TOBONDEV" `
    -ForestMode "Win2025" `
    -InstallDns:$true `
    -LogPath "C:\WINDOWS\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\WINDOWS\SYSVOL" `
    -Force:$true
    Write-Output "Active Directory Forest Created"
}
