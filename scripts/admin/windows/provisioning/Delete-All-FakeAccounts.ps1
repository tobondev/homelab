# Delete-All-FakeAccounts.ps1

$targetGroup = "FakeAccounts"
$baseDN = "DC=tobon,DC=dev"

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

# 2. Destroy the Flat Organizational Units
$labOUs = @(
    "_GROUPS", "IT Operations", "Information Security", "Software Engineering",
    "QA and Testing", "DevOps", "Finance", "Accounting", "Sales",
    "Customer Success", "Marketing", "Communications", "HR", "Legal",
    "Facilities", "Media Production", "Event Operations", "Executive", "_SERVICE"
)

Write-Host "`n[--- Destroying Target OUs ---]" -ForegroundColor Cyan
foreach ($ouName in $labOUs) {
    $ouPath = "OU=$ouName,$baseDN"

    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouPath'" -ErrorAction SilentlyContinue) {
        Set-ADOrganizationalUnit -Identity $ouPath -ProtectedFromAccidentalDeletion $false
        Remove-ADOrganizationalUnit -Identity $ouPath -Recursive -Confirm:$false
        Write-Host "  -> Destroyed Container: $ouPath" -ForegroundColor Magenta
    }
}

Write-Host "`nTeardown complete. Lab environment is clean." -ForegroundColor Green
