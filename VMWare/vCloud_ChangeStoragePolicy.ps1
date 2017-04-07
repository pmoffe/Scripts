### Note:
### To Manually find a URL for a storage polociy, run "Search-Cloud -querytype AdminOrgVdcStorageProfile -Name "<storage-plicy-name>" | get-ciview -viewlevel admin | select Href"

param (
   [Parameter(Mandatory=$true, HelpMessage="What vCloud environment do you want to administer?")]
   [ValidateNotNullorEmpty()]
   [string[]]
   $vCloud
)

# Connect to vCloud Director
Connect-CIServer $vCloud

$uservm = Read-Host -Prompt 'What is the name of the VM you want to modify?'
$harddisk = Read-Host -Prompt "What hard-disk on '$uservm' do you want to modify?"
$StoragePolicy = Read-Host -Prompt "What storage policy do you want to assign to '$harddisk' on '$uservm'?"

# Get Storage Policy API URL
$StoragePolicyURL = Search-Cloud -querytype AdminOrgVdcStorageProfile -Name $StoragePolicy | get-ciview -viewlevel admin | select Href

# Change VM Storage Profile
$vm = get-civm | where-object {$_.Name -eq $uservm }

(($vm.ExtensionData.Section | where {$_ -is [VMware.VimAutomation.Cloud.Views.OvfVirtualHardwareSection]}).item | where {$_.ElementName.value -eq $harddisk}).HostResource.AnyAttr[1]."#text" = "true"
(($vm.ExtensionData.Section | where {$_ -is [VMware.VimAutomation.Cloud.Views.OvfVirtualHardwareSection]}).item | where {$_.ElementName.value -eq $harddisk}).HostResource.AnyAttr[3]."#text" = $StoragePolicyURL.Href
($vm.ExtensionData.Section|where {$_-is[VMware.VimAutomation.Cloud.Views.OvfVirtualHardwareSection]}).updateserverdata()
