# Provision-FromJson.ps1
param(
    [string]$JsonPath = ".\users.json"
)
$domain = (Get-ADDomain).DistinguishedName
$originalPolicy = Get-ADDefaultDomainPasswordPolicy -Identity $domain

Write-Host "Current Domain Complexity: $($originalPolicy.ComplexityEnabled)" -ForegroundColor DarkGray
Write-Host "Current Minimum Length: $($originalPolicy.MinPasswordLength)" -ForegroundColor DarkGray

# Capture the current domain policy state
try {
    # Drop Password Policy temporarily
    Write-Host "Temporarily disabling password policy enforcement..." -ForegroundColor Yellow
    Set-ADDefaultDomainPasswordPolicy -Identity $domain -ComplexityEnabled $false -MinPasswordLength 0

    # Wait to ensure the policy is updated in memory
    Start-Sleep -Seconds 2
    # Ensure the error log isn't appended to endlessly
    $errorLog = ".\provisioning_errors.log"
    if (Test-Path $errorLog) { Remove-Item $errorLog -Force }
    $data = Get-Content $JsonPath -Raw | ConvertFrom-Json

        $baseDN = "DC=TOBON,DC=DEV"
        $orgOU = "OU=ORG,$baseDN"
        $groupsOU = "OU=GROUPS,$orgOU"
        $deptOU = "OU=DEPARTMENTS,$orgOU"
        $serviceOU = "OU=_SERVICE,$orgOU"

        # 1. Ensure the ORG, Department and Group OUs exists
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$orgOU'" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name "ORG" -Path $baseDN -ProtectedFromAccidentalDeletion $false
            Write-Host "Created Root OU: ORG" -ForegroundColor Cyan
        }
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$groupsOu'" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name "GROUPS" -Path $orgOU -ProtectedFromAccidentalDeletion $false
            Write-Host "Created Nested OU: GROUPS" -ForegroundColor Cyan
        }
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$deptOU'" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name "DEPARTMENTS" -Path $orgOU -ProtectedFromAccidentalDeletion $false
            Write-Host "Created Nested OU: DEPARTMENTS" -ForegroundColor Cyan
        }
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$serviceOU'" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name "_SERVICE" -Path $orgOU -ProtectedFromAccidentalDeletion $false
            Write-Host "Created Flat OU: _SERVICE" -ForegroundColor Cyan
        }

        # 2. Dynamically Ensure Nested Department OUs exist (including _SERVICE)
        $departments = $data.users | Where-Object { $_.department } | Select-Object -ExpandProperty department -Unique
        foreach ($dept in $departments) {
            if ( $dept -eq "_SERVICE") {
                $parentOuPath = "$orgOU"
                $deptOuPath = "OU=$dept,$orgOU"
            } else {
                $parentOuPath = "$deptOU"
                $deptOuPath = "OU=$dept,$deptOU"
            }
            if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$deptOuPath'" -ErrorAction SilentlyContinue)) {
                New-ADOrganizationalUnit -Name $dept -Path $parentOuPath -ProtectedFromAccidentalDeletion $false
                Write-Host "Created Nested OU: $dept" -ForegroundColor Cyan
            }
        }


        # 3. Create Groups
        foreach ($group in $data.groups) {
            if (-not (Get-ADGroup -Filter "Name -eq '$($group.name)'" -ErrorAction SilentlyContinue)) {
                New-ADGroup -Name $group.name -GroupScope Global -Path $groupsOu
                Write-Host "Created group: $($group.name)" -ForegroundColor Cyan
            }
        }

        # 4. Create Users (With Non-Terminating Error Logging)
        Write-Host "`n[--- Provisioning Users ---]" -ForegroundColor Cyan
        foreach ($user in $data.users) {
            $samAccountName = $user.username
            $upn = "$samAccountName@tobon.dev"

            if (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue) {
                Write-Host "Skipped: $samAccountName (Already exists)" -ForegroundColor DarkGray
                continue
            }
            # Route the user to their specific Department OU, evaluating for _SERVICE exception, fallback to root if blank
                        $targetOu = if ($user.department) {
                            if ($user.department -eq '_SERVICE') {
                                "OU=$($user.department),$orgOU"
                            } else {
                                "OU=$($user.department),$deptOU"
                            }
                        } else {
                            "CN=Users,$baseDN"
                        }
            $uniqueHumanName = "$($user.DisplayName) ($samAccountName)"
            $splat = @{
                Name                  = $uniqueHumanName
                DisplayName           = $uniqueHumanName
                GivenName             = $user.firstName
                Surname               = $user.lastName
                SamAccountName        = $samAccountName
                UserPrincipalName     = $upn
                AccountPassword       = (ConvertTo-SecureString $user.password -AsPlainText -Force)
                Enabled               = $user.enabled
                PasswordNeverExpires  = $user.passwordNeverExpires
                ChangePasswordAtLogon = $user.changePasswordAtLogon
                Path                  = $targetOu
            }

            if ($user.description) { $splat.Description = $user.description }
            if ($user.department) { $splat.Department = $user.department }
            if ($user.title) { $splat.Title = $user.title }

            # The Safe Execution Block
            try {
                # -ErrorAction Stop forces any AD rejection into the catch block
                New-ADUser @splat -ErrorAction Stop
                Write-Host "Provisioned: $samAccountName -> $targetOu" -ForegroundColor Green

                # Process group memberships only if the user was successfully created
                if ($user.groups) {
                    foreach ($groupName in $user.groups) {
                        Add-ADGroupMember -Identity $groupName -Members $samAccountName
                        Write-Host "  -> Assigned to: $groupName" -ForegroundColor DarkGreen
                    }
                }

                # Process SPNs
                if ($user.servicePrincipalName) {
                    foreach ($spn in $user.servicePrincipalName) {
                        Set-ADUser -Identity $samAccountName -Add @{ServicePrincipalName = $spn}
                        Write-Host "  -> Injected SPN: $spn" -ForegroundColor Magenta
                    }
                }
            }
            catch {
                $errorMessage = $_.Exception.Message

                # Print a non-terminating yellow warning to the console
                Write-Host "Failed to Provision: $samAccountName ($errorMessage)" -ForegroundColor Yellow

                # Append the failure to the text log
                $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                "$timestamp | ERROR | $samAccountName | $errorMessage" | Out-File -FilePath $errorLog -Append

                # Continue the loop for the next user
                continue
            }
        }

}
finally{
    # Restore Policy
    Write-Host "Restoring strict domain password policy..." -ForegroundColor Cyan
    Set-ADDefaultDomainPasswordPolicy -Identity $domain `
        -ComplexityEnabled $originalPolicy.ComplexityEnabled `
        -MinPasswordLength $originalPolicy.MinPasswordLength
    if (-not (Test-Path ".\Artifacts")) { New-Item -ItemType Directory -Path ".\Artifacts" | Out-Null }
    $departments | Out-File -FilePath ".\Artifacts\fake_ous_artifact.txt" -Force
    Write-Host "Password Policy restored. Lab environment staging complete." -ForegroundColor Green
}
