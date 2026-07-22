# Generate-TestCsv.ps1

$firstNames = @(
    "James","Mary","Robert","Patricia","John","Jennifer","Michael",
    "Giovanni","Linda","David","Elizabeth","William","Barbara",
    "Richard","Susan","Joseph","Jessica","Thomas","Sarah","Charles",
    "Karen","Gunther","Cesar",
    "Avery","Nikolai","Priya"
)

$lastNames  = @(
    "Smith","Johnson","Williams","Brown","Jones","Garcia","Miller",
    "Davis","Rodriguez","Martinez","Pilaf","Hernandez","Lopez",
    "Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore",
    "Jackson","Martin","Gruner","Lozano",
    "Kensington","Petrov","Nakamura"
)

$departments = @(

    # Technology & Engineering
    @{
        Dept   = "IT Operations"
        Titles = @("Systems Administrator", "Network Engineer", "Helpdesk Technician")
        Groups = @("ITOperations", "Employees")
    },

    @{
        Dept   = "Information Security"
        Titles = @("Cybersecurity Analyst", "Security Engineer", "IAM Specialist")
        Groups = @("LinuxAdmins","LinuxUsers","InfoSec", "Employees")
    },

    @{
        Dept   = "Software Engineering"
        Titles = @("Backend Developer", "Frontend Developer", "Full Stack Engineer")
        Groups = @("LinuxAdmins","LinuxUsers","Engineering", "Employees")
    },

    @{
        Dept   = "QA and Testing"
        Titles = @("QA Automation Engineer", "Manual Tester", "SDET")
        Groups = @("QA", "Employees")
    },

    @{
        Dept   = "DevOps"
        Titles = @("Site Reliability Engineer", "Release Manager", "Cloud Architect")
        Groups = @("SystemEngineers","LinuxUsers","DevOps", "Employees")
    },

    # Finance & Accounting
    @{
        Dept   = "Finance"
        Titles = @("Financial Analyst", "FP&A Manager", "Director of Finance")
        Groups = @("Finance", "Employees")
    },

    @{
        Dept   = "Accounting"
        Titles = @("Accountant", "Accounts Payable Clerk", "Payroll Specialist")
        Groups = @("Accounting", "Employees")
    },

    # Sales & Client Facing
    @{
        Dept   = "Sales"
        Titles = @("Account Executive", "Sales Representative", "SDR")
        Groups = @("Sales", "Employees")
    },

    @{
        Dept   = "Customer Success"
        Titles = @("Customer Success Manager", "Technical Account Manager", "Support Specialist")
        Groups = @("CustomerSuccess", "Employees")
    },

    # Marketing & Communications
    @{
        Dept   = "Marketing"
        Titles = @("Marketing Manager", "SEO Specialist", "Content Strategist")
        Groups = @("Marketing", "Employees")
    },

    @{
        Dept   = "Communications"
        Titles = @("Content Creator", "PR Specialist", "Internal Comms Manager")
        Groups = @("Communications", "Employees")
    },

    # Legal & HR
    @{
        Dept   = "HR"
        Titles = @("HR Generalist", "Recruiter", "Benefits Coordinator", "Hiring Manager")
        Groups = @("HR", "Employees")
    },

    @{
        Dept   = "Legal"
        Titles = @("Compliance Officer", "Commercial Counsel", "Litigation Counsel", "Paralegal")
        Groups = @("Legal", "Employees")
    },

    # Operations & Facilities
    @{
        Dept   = "Facilities"
        Titles = @("Facilities Manager", "Physical Security", "Maintenance Technician")
        Groups = @("Facilities", "Employees")
    },

    @{
        Dept   = "Media Production"
        Titles = @("AV Technician", "Video Editor", "Broadcast Engineer")
        Groups = @("MediaProduction", "Employees")
    },

    @{
        Dept   = "Event Operations"
        Titles = @("Event Coordinator", "Hospitality Manager", "Logistics Specialist")
        Groups = @("EventOps", "Employees")
    },

    # Leadership
    @{
        Dept   = "Executive"
        Titles = @("Chief Executive Officer", "Chief Operating Officer", "Chief Technology Officer")
        Groups = @("Executive", "Employees")
    }
)

# Special Group mapping based on specific titles
$specialGroupsByTitle = @{
    "Systems Administrator"          = @("LinuxAdmins", "Maintenance")
    "Security Engineer"              = @("SecurityEngineers", "Linux Admins")
    "Network Engineer"               = @("NetworkEngineers", "LinuxUsers")
    "Video Editor"                   = @("MediaNetworkShare")
    "Chief Technology Officer"       = @("AuditAccess")
    "Frontend Developer"             = @("WebServerAdmins")
    "Support Specialist"             = @("Tier1Support")
    "Site Reliability Engineer"      = @("Linux Admins")
    "Full Stack Engineer"            = @("LinuxAdmins","WebServerAdmins")
    "Cloud Architect"                = @("CloudAdmins")
    "Payroll Specialist"             = @("PayrollManagers")
}

Write-Host "Generating 1,000 AD users for load testing..." -ForegroundColor Cyan

# Using pipeline assignment for performance (much faster than += array appending)
$users = for ($i = 1; $i -le 997; $i++) {
    $first = $firstNames | Get-Random
    $last  = $lastNames | Get-Random
    $deptObj = $departments | Get-Random
    $dept    = $deptObj.Dept
    $title   = $deptObj.Titles | Get-Random

    # Start with the base department groups and default flags
    $realGroupsList = [System.Collections.Generic.List[string]]::new()
    $realGroupsList.AddRange([string[]]$deptObj.Groups)

    # CHECK: Does this title belong to the special group pool?
    if ($specialGroupsByTitle.ContainsKey($title)) {
        $realGroupsList.AddRange([string[]]$specialGroupsByTitle[$title])
    }

    # Build the final semicolon-delimited groups string
    $groups = ($realGroupsList -join ';') + ";FakeAccounts"

    # Introduce a 10% chance to poison the account with the InvalidPassword group
    if ((Get-Random -Min 1 -Max 101) -le 10) {
        $groups += ";InvalidPassword"
    }

    # Introduce some realistic chaos to the boolean values
    $enabled     = if ((Get-Random -Min 1 -Max 101) -gt 5) { $true } else { $false }  # 95% enabled
    $pwdNeverExp = if ((Get-Random -Min 1 -Max 101) -gt 90) { $true } else { $false } # 10% never expire
    if ($pwdNeverExp) {
            $changeLogon = $false # AD will not allow non-expiring passwords to be forced to change at next logon.
        } else {
            $changeLogon = if ((Get-Random -Min 1 -Max 101) -gt 20) { $true } else { $false } # 80% must change at logon
        }

    [PSCustomObject]@{
        firstName             = $first
        lastName              = $last
        groups                = $groups
        enabled               = $enabled.ToString().ToLower()
        passwordNeverExpires  = $pwdNeverExp.ToString().ToLower()
        changePasswordAtLogon = $changeLogon.ToString().ToLower()
        department            = $dept
        title                 = $title
        description           = "Automated load test account - $dept"
        servicePrincipalName  = $null # Added to ensure that Kerberoastable service accounts are fully compatible with the schema
    }
}

$serviceAccounts = @(
    [PSCustomObject]@{
        firstName             = "svc"
        lastName              = "mssql"
        groups                = "ServiceAccount;FakeAccounts"
        enabled               = "true"
        passwordNeverExpires  = "true"
        changePasswordAtLogon = "false"
        department            = "_SERVICE"
        title                 = "Service Account"
        description           = "Kerberoastable - MSSQL service account"
        servicePrincipalName  = "MSSQLSvc/sql.tobon.dev:1433"
    },
    [PSCustomObject]@{
        firstName             = "svc"
        lastName              = "http"
        groups                = "ServiceAccount;FakeAccounts"
        enabled               = "true"
        passwordNeverExpires  = "true"
        changePasswordAtLogon = "false"
        department            = "_SERVICE"
        title                 = "Service Account"
        description           = "Kerberoastable - HTTP service account"
        servicePrincipalName  = "HTTP/web.tobon.dev"
    },
    [PSCustomObject]@{
        firstName             = "svc"
        lastName              = "backup"
        groups                = "ServiceAccount;FakeAccounts"
        enabled               = "true"
        passwordNeverExpires  = "true"
        changePasswordAtLogon = "false"
        department            = "_SERVICE"
        title                 = "Service Account"
        description           = "Kerberoastable - Backup service account"
        servicePrincipalName  = "cifs/fileserver.tobon.dev"
    }
)

$outputPath = ".\users.csv"

# Append to users array before export
$allUsers = @($users) + @($serviceAccounts)
$allUsers | Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "Success! Created $outputPath with $($allUsers.Count) rows." -ForegroundColor Green
