# Convert-CsvToJson.ps1
param(
    [string]$CsvPath = ".\users.csv",
    [string]$JsonPath = ".\users.json"
)

# ---- Memory Allocation for Collision Tracking ----
$Global:AssignedUsernames = [System.Collections.Generic.HashSet[string]]::new()

# ---- Character pools and complexity profiles ----
# For this lab exercise, lookalike characters are being banned by excluding them from the pools
# INVALID complexity: Randomly selects 2 out of 4 character pools.
# Generates a password that fails Windows default complexity requirements.
# These accounts have changePasswordAtLogon = $false to preserve the violation.
# Useful for testing Event ID 4625 (logon failure) and password policy enforcement.
# This script is for LAB USE ONLY: Even outside of the invalid passwords that are forced,
# production would require System.Security.Cryptography.RandomNumberGenerator.
$characterPools = @{
    lowercase = 'abcdefghijkmnopqrstuvwxyz'
    uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    numbers   = '0123456789'
    specials  = '!@#$%^&*'
}
# Get all pools as an array
$validPools = @($characterPools.Values)

$groupComplexityMap = @{
    "Domain Admins"    = "HIGH"
    "Finance"          = "MEDIUM"
    "InvalidPassword"  = "INVALID"
    "ServiceAccount"   = "ROAST"
}

function Get-ComplexityFromGroups {
    param([string[]]$Groups)
    # The priority order guarantees that Kerberostable passwords will be assigned to service accounts
    # and invalid passwords will supersede any other requirements. This is a deliberate choice which
    # enables domain admin passwords that violate password requirements, as well as Kerberoastable
    # service accounts. This risk is understood and accepted.
    $priorityOrder = @("LOW", "MEDIUM", "HIGH", "INVALID", "ROAST")
    $maxPriority = 0
    $selectedComplexity = "LOW"

    foreach ($group in $Groups) {
        $complexity = $groupComplexityMap[$group]
        if ($complexity) {
            $priority = [Array]::IndexOf($priorityOrder, $complexity)
            if ($priority -gt $maxPriority) {
                $maxPriority = $priority
                $selectedComplexity = $complexity
            }
        }
    }
    return $selectedComplexity
}

function New-RandomPassword {
    param([string]$Complexity)

    # Dynamically determine pool count and length based on complexity tier
    if ($Complexity -eq "ROAST") {
        $poolCount = 2
        $length = Get-Random -Min 4 -Max 7 # This is intentionally our weakest link. Kerberoastable accounts.
    }
    elseif ($Complexity -eq "INVALID") {
        $poolCount = 2
        $length = Get-Random -Min 5 -Max 8 # Triggers the Minimum Length GPO violation
    }
    elseif ($Complexity -eq "LOW") {
        $poolCount = 3
        $length = 8
    }
    elseif ($Complexity -eq "MEDIUM") {
        $poolCount = Get-Random -Min 3 -Max 5 # Randomly selects 3 or 4
        $length = 12
    }
    else {
        # HIGH complexity (Domain Admins)
        $poolCount = 4
        $length = 16
    }

    # Grab the required number of unique character pools
    $selectedPools = $validPools | Get-Random -Count $poolCount

    $allChars = $selectedPools -join ''

    # Ensure at least one character from each selected pool is used
    $requiredChars = foreach ($pool in $selectedPools) {
        $pool.ToCharArray() | Get-Random -Count 1
    }

    # Fill the remaining slots
    $allCharsArray = $allChars.ToCharArray()
    $remainingSlots = $length - $requiredChars.Count
    $randomChars = 1..$remainingSlots | ForEach-Object { $allCharsArray | Get-Random }

    # Combine and shuffle
    $passwordChars = $requiredChars + $randomChars
    return ($passwordChars | Sort-Object { Get-Random }) -join ''
}

function Get-UniqueUsername {
    param([string]$FirstName, [string]$LastName)

    $firstClean = $FirstName.ToLower().Trim()
    $lastClean  = $LastName.ToLower().Trim()

    if (-not $firstClean -and -not $lastClean) {
        throw "Both firstName and lastName are empty in the CSV row."
    }

    # Base attempt: first initial + last name
    $base = if ($firstClean) { $firstClean[0] } else { '' }
    $baseUsername = "$base$lastClean"
    $username = $baseUsername

    # Strategy 1: Letter Expansion (e.g., mtobon -> matobon -> martobon)
    $i = 2
    while ($Global:AssignedUsernames.Contains($username) -and $i -le $firstClean.Length) {
        $username = "$($firstClean.Substring(0, $i))$lastClean"
        $i++
    }

    # Strategy 2: Numeric Fallback
    $counter = 1
    while ($Global:AssignedUsernames.Contains($username)) {
        $username = "$baseUsername$counter"
        $counter++
    }

    $Global:AssignedUsernames.Add($username) | Out-Null
    return $username
}

function Get-MaxDepth {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [AllowNull()]
        $InputObject,

        [int]$CurrentDepth = 1
    )

    # Base case: If the object is null, we hit the bottom.
    if ($null -eq $InputObject) { return $CurrentDepth }

    $maxFoundDepth = $CurrentDepth

    # Check if the object is a Dictionary (like our [ordered] hashtables)
    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            $childDepth = Get-MaxDepth -InputObject $InputObject[$key] -CurrentDepth ($CurrentDepth + 1)
            if ($childDepth -gt $maxFoundDepth) { $maxFoundDepth = $childDepth }
        }
    }
    # Check if the object is an Array/List (but NOT a string, which is technically an array of chars)
    elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        foreach ($item in $InputObject) {
            $childDepth = Get-MaxDepth -InputObject $item -CurrentDepth ($CurrentDepth + 1)
            if ($childDepth -gt $maxFoundDepth) { $maxFoundDepth = $childDepth }
        }
    }
    # Check if the object is a PSCustomObject (created by Import-Csv)
    elseif ($InputObject -is [PSCustomObject]) {
        foreach ($property in $InputObject.psobject.properties) {
            $childDepth = Get-MaxDepth -InputObject $property.Value -CurrentDepth ($CurrentDepth + 1)
            if ($childDepth -gt $maxFoundDepth) { $maxFoundDepth = $childDepth }
        }
    }

    return $maxFoundDepth
}

# ---- Main conversion ----
Write-Host "Reading $CsvPath and generating schema..." -ForegroundColor Cyan

$users = Import-Csv $CsvPath | ForEach-Object {
    $row = $_

    $username = Get-UniqueUsername -FirstName $row.firstName -LastName $row.lastName

    $groups = @()
    if ($row.groups) {
        $groups = $row.groups -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    $complexity = Get-ComplexityFromGroups -Groups $groups
$generatedPassword = New-RandomPassword -Complexity $complexity

    # IMPORTANT: Override changePasswordAtLogon for invalid passwords
    if ($complexity -eq "INVALID" -or $complexity -eq "ROAST") {
        $changePwdAtLogon = $false
    }
    else {
        $changePwdAtLogon = if ([string]::IsNullOrWhiteSpace($row.changePasswordAtLogon)) { $true }
                            else { [bool]::Parse($row.changePasswordAtLogon) }
    }

    # Build user object as before, using $changePwdAtLogon
    $user = [ordered]@{
        username              = $username
        firstName             = $row.firstName
        lastName              = $row.lastName
        displayName           = if ($row.displayName) { $row.displayName } else { "$($row.firstName) $($row.lastName)".Trim() }
        password              = $generatedPassword
        enabled               = if ([string]::IsNullOrWhiteSpace($row.enabled)) { $true } else { [bool]::Parse($row.enabled) }
        passwordNeverExpires  = if ([string]::IsNullOrWhiteSpace($row.passwordNeverExpires)) { $false } else { [bool]::Parse($row.passwordNeverExpires) }
        changePasswordAtLogon = $changePwdAtLogon
        groups                = $groups
    }

    if ($row.department) { $user.department = $row.department }
    if ($row.title) { $user.title = $row.title }
    if ($row.description) { $user.description = $row.description }
    if ($row.servicePrincipalName) {
        $spns = $row.servicePrincipalName -split ';' |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ }
        if ($spns) { $user.servicePrincipalName = $spns }
    }

    $user
}

$allGroups = $users | ForEach-Object { $_.groups } | Where-Object { $_ } | Sort-Object -Unique
$schema = @{
    groups = $allGroups | ForEach-Object { @{ name = $_ } }
    users  = $users
}

# Dynamically calculate the maximum depth of our constructed object
$requiredDepth = Get-MaxDepth -InputObject $schema

Write-Host "Calculated dynamic object depth: $requiredDepth" -ForegroundColor DarkGray

# Apply the calculated depth exactly
$schema | ConvertTo-Json -Depth $requiredDepth | Set-Content -Path $JsonPath -Encoding UTF8
Write-Host "Success: Identity state locked and saved to $JsonPath." -ForegroundColor Green
