To support the AD Schema approach, the official Sudo schema was downloaded in the Domain Controller, and extended.

```bash
# Get Sudo Schema
wget https://github.com/sudo-project/sudo/blob/main/docs/schema.ActiveDirectory
scp -P 22 -i {IDENTITY_FILE} ./schema.ActiveDirectory {AD_ADMIN}@{DOMAIN}@{DOMAIN_CONTROLLER}:C:/Users/{AD_ADMIN}
```
```powershell
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/lbt/sudo/refs/heads/master/doc/schema.ActiveDirectory" -OutFile .\schema.ActiveDirectory
ldifde -i -f .\schema.ActiveDirectory -c "DC=X" "DC=TOBON,DC=DEV"
```

A top-level `sudoers` OU was created, and `sudoRole` objects (`Engineers`, `Admins`, `Maintenance`, `WebMaster`) were dynamically nested within it via the `New-ADObject` PowerShell module. A script was executed to dynamically map these roles to specific `sudoUser` groups, `sudoHost` targets, `sudoCommand` allowances, and `sudoRunAsUser` privileges.


```powershell
# Esnure sudoRole object exists.
$baseDN  = "DC=tobon,DC=dev"
$ouName  = "sudoers"
$ouPath  = "OU=$ouName,$baseDN"
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $baseDN -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name $ouName -Path $baseDN -ProtectedFromAccidentalDeletion $true
}
# Define sudoRole objects as arrays.
$sudoRoles = @(
    @{
        Name       = "Engineers"
        Attributes = @{
            'sudoUser'    = '%SystemEngineers'
            'sudoHost'    = 'ALL'
            'sudoCommand' = 'ALL'
        }
    },
    @{
        Name       = "Admins"
        Attributes = @{
            'sudoUser'      = '%LinuxAdmins'
            'sudoHost'      = '*-workstation.tobon.dev'
            'sudoCommand'   = 'ALL'
            'sudoRunAsUser' = 'root'
        }
    },
    @{
        Name       = "Maintenance"
        Attributes = @{
            'sudoUser'      = '%ITOperations'
            'sudoHost'      = '*-workstation.tobon.dev,*-server.tobon.dev'
            'sudoCommand'   = '/bin/systemctl restart *'
            'sudoRunAsUser' = 'root'
        }
    },
    @{
        Name       = "WebMaster"
        Attributes = @{
            'sudoUser'      = 'shttp'
            'sudoHost'      = '*-fileserver.tobon.dev'
            'sudoCommand'   = '/bin/systemctl * nginx'
            'sudoRunAsUser' = 'root'
        }
    }
)

# Provision or Update sudoRoles dynamically
foreach ($role in $sudoRoles) {
    $roleDN = "CN=$($role.Name),$ouPath"   
    # Check if object already exists to avoid redundant creation errors
    if (Get-ADObject -Filter "DistinguishedName -eq '$roleDN'" -ErrorAction SilentlyContinue) {
        # Update attributes if object exists
        Set-ADObject -Identity $roleDN -Replace $role.Attributes
    } else {
        # Create object if it does not exist
        New-ADObject -Type sudoRole -Name $role.Name -Path $ouPath -OtherAttributes $role.Attributes
    }
}
```

Which results in the following structure:

OU=sudoers
  CN=Engineers
  CN=Admins
  CN=Maintenance
  CN=WebMaster

Without real or simulated services and systems to map to permissions and users, the proof-of-concept permissions mapping needs to be fairly simple. In this scenario, the following simple sudo permission sets are used:

| sudoRole | Group Name | Allowed Hosts | Allowed Commands |
| --- | --- | --- | --- |
| Engineers | SystemEngineers | All | All |
| Admins | LinuxAdmins | Linux Workstations | All |
| Maintenance | ITOperations | Linux Servers | `/bin/systemctl restart` |
| WebMaster | ServiceAccount | nginx Server | `/bin/systemctl * nginx` |

While simple, they cover the basics of permissions control:

- Who is authorized
- Where are they authorized
- What are they authorized to do
