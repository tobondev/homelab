# Create Relevant Groups
$groups = 'SystemEngineers', 'Domain Admins', 'LinuxUsers'
$path = "OU=_GROUPS,DC=TOBON,DC=DEV"
foreach ($group in $groups) {
    New-ADGroup -Name $group -GroupScope Global -Path $path
}
$splat = @{
>>                 Name                  = "{FIRSTNAME LASTNAME}"
>>                 DisplayName           = "{FIRSTNAME LASTNAME}"
>>                 GivenName             = "{FIRSTNAME}"
>>                 Surname               = "{LASTNAME}"
>>                 SamAccountName        = "{SamAccountName}"
>>                 UserPrincipalName     = "{SamAccountName}@tobon.dev"
>>                 AccountPassword       = (ConvertTo-SecureString '{PASSWORD}' -AsPlainText -Force)
>>                 Enabled               = $true
>>                 PasswordNeverExpires  = $true
>>                 ChangePasswordAtLogon = $false
>>                 Path                  = "OU=SystemEngineers,DC=tobon,DC=dev"
>>             }
>> New-ADUser @splat
# Add User to System Engineers Group
$groups = 'SystemEngineers', 'Domain Admins', 'LinuxUsers',
$username = '{SamAccountName}'
foreach ($group in $groups) {
    Add-ADGroupMember -Identity $group -Members $username
}
