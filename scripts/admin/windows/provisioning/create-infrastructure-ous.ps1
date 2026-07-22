# create-infrastructure-ous.ps1
# Define Base Domain Path
$domainDN = "DC=tobon,DC=dev"
$orgOU = "OU=ORG,$domainDN"
$infrastructureOU = "OU=Infrastructure,$orgOU"

# Define the desired OU structure
$structure = [ordered]@{
    "Infrastructure" = @("Domain_Controllers", "Linux", "Windows")
    "Linux"          = @("Workstations", "Servers")
    "Windows"        = @("Workstations", "Servers")
}

Write-Host "Ensuring Active Directory Infrastructure OU Tree exists..." -ForegroundColor Cyan

# 1. Create the Root ORG OU
if (-not (Get-ADOrganizationalUnit -Identity $orgOU -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "ORG" -Path $domainDN -ProtectedFromAccidentalDeletion $true
    Write-Host "Created Root OU: ORG" -ForegroundColor Green
}

# 2. Create the Infrastructure OU
if (-not (Get-ADOrganizationalUnit -Identity $infrastructureOU -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "Infrastructure" -Path $orgOU -ProtectedFromAccidentalDeletion $true
    Write-Host "Created Nested OU: Infrastructure" -ForegroundColor Green
}

# 3. Create the First-Level Sub-OUs (Domain_Controllers, Linux, Windows)
foreach ($subOU in $structure["Infrastructure"]) {
    $subOUPath = "OU=$subOU,$infrastructureOU"
    if (-not (Get-ADOrganizationalUnit -Identity $subOUPath -ErrorAction SilentlyContinue)) {
        # Corrected Path: Routing to $infrastructureOU instead of $orgOU
        New-ADOrganizationalUnit -Name $subOU -Path $infrastructureOU -ProtectedFromAccidentalDeletion $true
        Write-Host "Created First-Level OU: $subOU" -ForegroundColor Green
    }
}

# 4. Create Second-Level Sub-OUs (Workstations & Servers)
$secondLevelParents = @('Linux', 'Windows')
foreach ($parent in $secondLevelParents) {
    $parentPath = "OU=$parent,$infrastructureOU"

    foreach ($child in $structure[$parent]) {
        $childPath = "OU=$child,$parentPath"

        if (-not (Get-ADOrganizationalUnit -Identity $childPath -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $child -Path $parentPath -ProtectedFromAccidentalDeletion $true
            Write-Host "Created Second-Level OU: $child (under $parent)" -ForegroundColor Green
        }
    }
}

Write-Host "Infrastructure OU Tree verification complete." -ForegroundColor Cyan
}
