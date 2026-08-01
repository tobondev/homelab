# Verify-ProvisioningState.ps1

$transcriptPath = ".\Artifacts\2026_AD_Provisioning_Verification_$(Get-Date -Format 'yyyyMMdd_HHmm').log"
# Ensure artifact directory exists
if (-not (Test-Path ".\Artifacts")) { New-Item -ItemType Directory -Path ".\Artifacts" | Out-Null }

Start-Transcript -Path $transcriptPath -NoClobber

Write-Host "`n=== AD Provisioning Verification Suite ===`n" -ForegroundColor Cyan

$allPassed = $true
$testResults = @()

# Helper function for console output and array tracking
function Test-Result {
    param([bool]$Condition, [string]$TestName)
    if ($Condition) {
        Write-Host "[PASS] $TestName" -ForegroundColor Green
        $Script:testResults += [PSCustomObject]@{ Test = $TestName; Status = "PASS" }
        return $true
    } else {
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        $Script:testResults += [PSCustomObject]@{ Test = $TestName; Status = "FAIL" }
        return $false
    }
}

# 1. Verify expected Department OUs exist and have users
$artifactPath = ".\Artifacts\fake_ous_artifact.txt"
if (Test-Path $artifactPath) {
    $expectedOUs = Get-Content $artifactPath
} else {
    Write-Host "Artifact file not found. Cannot Verify OU Creation." -ForegroundColor Red
    $expectedOUs = @()
}


Write-Host "--- Checking OU Population ---" -ForegroundColor Yellow

$orgOU = "OU=ORG,DC=tobon,DC=dev"
$deptOU = "OU=DEPARTMENTS,$orgOU"

foreach ($ou in $expectedOUs) {
    # Dynamically build the SearchBase depending on whether it is a service account or standard department
    if ($ou -eq "_SERVICE") {
        $searchBase = "OU=$ou,$orgOU"
        $userCount = (Get-ADUser -Filter * -SearchBase $searchBase -ErrorAction SilentlyContinue).Count
        $pass = Test-Result -Condition ($userCount -eq 3) -TestName "OU '_SERVICE' contains exactly 3 service accounts (found $userCount)"
    } else {
        $searchBase = "OU=$ou,$deptOU"
        $userCount = (Get-ADUser -Filter * -SearchBase $searchBase -ErrorAction SilentlyContinue).Count
        $pass = Test-Result -Condition ($userCount -gt 0) -TestName "OU '$ou' has at least 1 user (found $userCount)"
    }

    if (-not $pass) { $allPassed = $false }
}

# 2. Verify FakeAccounts group membership
Write-Host "`n--- Checking FakeAccounts Group ---" -ForegroundColor Yellow
$fakeMembers = (Get-ADGroupMember -Identity "FakeAccounts" -ErrorAction SilentlyContinue).Count
$totalUsers = (Get-ADUser -Filter *).Count

# Subtract built-in accounts to get synthetic total
$baseAccounts = @(Get-ADUser -Filter {Enabled -eq $true -and Name -like "Guest*"}).Count + @(Get-ADUser -Filter {Name -eq "Administrator"}).Count
$expectedFakeCount = 1000

$pass = Test-Result -Condition ($fakeMembers -ge 990 -and $fakeMembers -le $totalUsers) -TestName "FakeAccounts group contains $fakeMembers members (expected ~$expectedFakeCount)"
if (-not $pass) { $allPassed = $false }

# 3. Verify Kerberoastable service accounts and their SPNs
Write-Host "`n--- Checking Kerberoastable Accounts ---" -ForegroundColor Yellow
$spnAccounts = Get-ADUser -Filter {ServicePrincipalName -like "*"} -Properties ServicePrincipalName

# Updated to match the Get-UniqueUsername generation logic (s + lastname)
$expectedSpns = @{
    "smssql"   = "MSSQLSvc/sql.tobon.dev:1433"
    "shttp"    = "HTTP/web.tobon.dev"
    "sbackup"  = "cifs/fileserver.tobon.dev"
}

foreach ($account in $expectedSpns.Keys) {
    $user = $spnAccounts | Where-Object { $_.SamAccountName -eq $account }
    if ($user) {
        $hasSpn = $user.ServicePrincipalName -contains $expectedSpns[$account]
        $pass = Test-Result -Condition $hasSpn -TestName "Account '$account' has SPN '$($expectedSpns[$account])'"
        if (-not $pass) { $allPassed = $false }
    } else {
        Test-Result -Condition $false -TestName "Account '$account' exists (NOT FOUND)"
        $allPassed = $false
    }
}

# 4. Verify password policy is restored
Write-Host "`n--- Checking Password Policy ---" -ForegroundColor Yellow
$policy = Get-ADDefaultDomainPasswordPolicy
$passComplex = Test-Result -Condition ($policy.ComplexityEnabled -eq $true) -TestName "Password complexity enabled"
$passLength = Test-Result -Condition ($policy.MinPasswordLength -ge 7) -TestName "Minimum password length >= 7 (currently $($policy.MinPasswordLength))"
if (-not ($passComplex -and $passLength)) { $allPassed = $false }

# 5. Verify Error Log
Write-Host "`n--- Checking Provisioning Error Log ---" -ForegroundColor Yellow
$errorLog = ".\provisioning_errors.log"

if (-not (Test-Path $errorLog)) {
    Test-Result -Condition $true -TestName "Provisioning error log not found (no errors generated)"
} else {
    $errors = @(Get-Content $errorLog | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($errors.Count -eq 0) {
        Test-Result -Condition $true -TestName "Provisioning error log exists but is empty"
    } else {
        Test-Result -Condition $false -TestName "Provisioning error log has $($errors.Count) entries. Review manually."
        $allPassed = $false
    }
}

# Final summary
Write-Host "`n=== Verification Summary ===" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "ALL TESTS PASSED. Provisioning is ready for next stage." -ForegroundColor Green
} else {
    Write-Host "SOME TESTS FAILED. Review output above before proceeding." -ForegroundColor Red
}

Stop-Transcript
