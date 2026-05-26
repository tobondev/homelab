# Define structural paths
$provisioningDir = "C:\Scripts\Admin\UserProvisioning"
$helperDir       = "C:\Scripts\Admin\HelperScripts"

# 1. Create the working directories
Write-Host "Creating directory structure..." -ForegroundColor Cyan
New-Item -Path $provisioningDir -ItemType Directory -Force | Out-Null
New-Item -Path $helperDir -ItemType Directory -Force | Out-Null

# 2. Relocate this helper script
$currentScriptPath = $PSCommandPath

# Check if the script is running from a file (not an interactive prompt)
# and ensure it isn't already inside the target directory
if ($currentScriptPath -and ($currentScriptPath -notmatch [regex]::Escape($helperDir))) {
    $targetScriptPath = Join-Path $helperDir (Split-Path $currentScriptPath -Leaf)
    Write-Host "Moving helper script to $targetScriptPath..." -ForegroundColor Yellow

    # Move the file (PowerShell retains the execution context in memory)
    Move-Item -Path $currentScriptPath -Destination $targetScriptPath -Force
}

# 3. Pivot to the target directory for payload delivery
Set-Location -Path $provisioningDir
Write-Host "Context switched to $provisioningDir." -ForegroundColor Green

# 4. Hydrate the provisioning directory from GitHub
$apiEndpoint = "https://api.github.com/repos/tobondev/homelab/contents/scripts/admin/windows/provisioning"

Write-Host "Querying GitHub API for payload..." -ForegroundColor Cyan
(Invoke-RestMethod -Uri $apiEndpoint) | Where-Object { $_.name -like "*.ps1" } | ForEach-Object {
    Write-Host " -> Downloading $($_.name)..." -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $_.download_url -OutFile (Join-Path $provisioningDir $_.name)
}

Write-Host "Environment setup finished. Current Directory:" -ForegroundColor Green
# 5. List the downloaded contents
Get-ChildItem | Select-Object Name, Length, LastWriteTime
