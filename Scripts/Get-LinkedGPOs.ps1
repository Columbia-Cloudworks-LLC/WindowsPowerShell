Get-Module ActiveDirectory, GroupPolicy

# Specify the OU that you want to check for linked GPOs
$OU = "OU=Servers,OU=NA,OU=Fluor,DC=fdnet,DC=com"
Get-ADOrganizationalUnit $OU

$LinkedGPOs = Get-ADOrganizationalunit $OU | Select-Object -ExpandProperty LinkedGroupPolicyObjects
$LinkedGPOs

# Get the GUID of each Linked GPO
$LinkedGPOGUIDs = $LinkedGPOs | ForEach-Object {$_.Substring(4,36}
$LinkedGPOGUIDs

$LinkedGPOGUIDs | ForEach-Object {Get-GPO -Guid $_ | Select-Object DisplayName}