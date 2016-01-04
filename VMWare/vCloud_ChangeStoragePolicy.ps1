## Storage Policy Variables
### To Manually find a URL for a storage polociy, run "Search-Cloud -querytype AdminOrgVdcStorageProfile -Name "PHL_07_HAS_QVol" | get-ciview -viewlevel admin | select Href"

# Enter VM Name:
$uservm = Read-Host -Prompt 'What is the name of the VM you want to modify?'

# Enter Hard Disk to change:
$harddisk = Read-Host -Prompt "What hard-disk on '$uservm' do you want to modify?"

# Enter StoragePolicy Name:
$StoragePolicy = Read-Host -Prompt "What storage policy do you want to assign to '$harddisk' on '$uservm'?"

##
# Don't change anything below this line
##

# Connect to vCloud Director

try { Connect-CIServer -Server vdc.haservices.com -ErrorAction Stop }
catch { throw 'Could not connect to vCloud'}

# Get Storage Policy API URL
$StoragePolicyURL = Search-Cloud -querytype AdminOrgVdcStorageProfile -Name $StoragePolicy | get-ciview -viewlevel admin | select Href

# Change VM Storage Profile
$vm = get-civm | where-object {$_.Name -eq $uservm }

(($vm.ExtensionData.Section | where {$_ -is [VMware.VimAutomation.Cloud.Views.OvfVirtualHardwareSection]}).item | where {$_.ElementName.value -eq $harddisk}).HostResource.AnyAttr[1]."#text" = "true"
(($vm.ExtensionData.Section | where {$_ -is [VMware.VimAutomation.Cloud.Views.OvfVirtualHardwareSection]}).item | where {$_.ElementName.value -eq $harddisk}).HostResource.AnyAttr[3]."#text" = $StoragePolicyURL.Href
($vm.ExtensionData.Section|where {$_-is[VMware.VimAutomation.Cloud.Views.OvfVirtualHardwareSection]}).updateserverdata()