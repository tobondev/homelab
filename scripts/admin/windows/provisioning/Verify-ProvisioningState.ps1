# Test-ProvisioningStatus.ps1

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
$expectedOUs = @(
    "IT Operations", "Information Security", "Software Engineering",
    "QA and Testing", "DevOps", "Finance", "Accounting", "Sales",
    "Customer Success", "Marketing", "Communications", "HR", "Legal",
    "Facilities", "Media Production", "Event Operations", "Executive",
    "_SERVICE"
)

Write-Host "--- Checking OU Population ---" -ForegroundColor Yellow
foreach ($ou in $expectedOUs) {
    $userCount = (Get-ADUser -Filter * -SearchBase "OU=$ou,DC=tobon,DC=dev" -ErrorAction SilentlyContinue).Count
    if ($ou -eq "_SERVICE") {
        $pass = Test-Result -Condition ($userCount -eq 3) -TestName "OU '_SERVICE' contains exactly 3 service accounts (found $userCount)"
    } else {
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
