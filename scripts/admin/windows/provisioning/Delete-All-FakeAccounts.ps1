# Delete-All-FakeAccounts.ps1

$targetGroup = "FakeAccounts"
$baseDN = "OU=GROUPS,OU=ORG,DC=tobon,DC=dev"

Write-Host "Initiating teardown based on membership in: $targetGroup" -ForegroundColor Yellow

# 1. Nuke everyone in the FakeAccounts group (Surgical User Deletion)
if (Get-ADGroup -Filter "Name -eq '$targetGroup'" -ErrorAction SilentlyContinue) {
    Write-Host "`n[--- Scrubbing Synthetic Users ---]" -ForegroundColor Cyan

    $syntheticUsers = Get-ADGroupMember -Identity $targetGroup | Where-Object { $_.objectClass -eq 'user' }

    foreach ($user in $syntheticUsers) {
        Remove-ADUser -Identity $user.SamAccountName -Confirm:$false
        Write-Host "  -> Purged User: $($user.SamAccountName)" -ForegroundColor DarkRed
    }
}

#Read  Organizational Units from the artifact
$artifactPath = ".\Artifacts\fake_ous_artifact.txt"
if (Test-Path $artifactPath) {
    $labOUs = Get-Content $artifactPath
} else {
    Write-Host "Artifact file not found. Skipping OU teardown." -ForegroundColor Red
    $labOUs = @()
}

# Destroy
Write-Host "`n[--- Destroying Target OUs ---]" -ForegroundColor Cyan

$orgOU = "OU=ORG,DC=tobon,DC=dev"
$deptOU = "OU=DEPARTMENTS,$orgOU"

foreach ($ouName in $labOUs) {
    # Route the deletion path based on the _SERVICE exception
    if ($ouName -eq '_SERVICE') {
        $ouPath = "OU=$ouName,$orgOU"
    } else {
        $ouPath = "OU=$ouName,$deptOU"
    }

    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouPath'" -ErrorAction SilentlyContinue) {
        Set-ADOrganizationalUnit -Identity $ouPath -ProtectedFromAccidentalDeletion $false
        Remove-ADOrganizationalUnit -Identity $ouPath -Recursive -Confirm:$false
        Write-Host "  -> Destroyed Container: $ouPath" -ForegroundColor Magenta
    }
}

Write-Host "`nTeardown complete. Lab environment is clean." -ForegroundColor Green
