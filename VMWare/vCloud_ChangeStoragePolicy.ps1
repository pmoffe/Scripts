### Note:
### To Manually find a URL for a storage polociy, run "Search-Cloud -querytype AdminOrgVdcStorageProfile -Name "<storage-plicy-name>" | get-ciview -viewlevel admin | select Href"

# Enter VM Name:
$uservm = Read-Host -Prompt 'What is the name of the VM you want to modify?'

# Enter Hard Disk to change:
$harddisk = Read-Host -Prompt "What hard-disk on '$uservm' do you want to modify?"

# Enter StoragePolicy Name:
$StoragePolicy = Read-Host -Prompt "What storage policy do you want to assign to '$harddisk' on '$uservm'?"

# Load Config File
    #File with the stored data
        $ConfigFile = ".\VMware.config"
    #Creating an empty hash table
        $ConfigKeys = @{}
    #Pulling, separating, and storing the values in $Config
        Get-Content $ConfigFile | Where-Object { $_ -notmatch '^#.*' } | ForEach-Object {
            $Keys = $_ -split "="
            $Config += @{$Keys[0]=$Keys[1]}
        }

# Connect to vCloud Director
if ($global:DefaultCIServers.name -ne $config.ciserver) {
	try { Connect-CIServer -Server $config.ciserver -ErrorAction Stop }
		catch { throw 'Could not connect to vCloud'}
	}

# Get Storage Policy API URL
$StoragePolicyURL = Search-Cloud -querytype AdminOrgVdcStorageProfile -Name $StoragePolicy | get-ciview -viewlevel admin | select Href

# Change VM Storage Profile
$vm = get-civm | where-object {$_.Name -eq $uservm }

(($vm.ExtensionData.Section | where {$_ -is [VMware.VimAutomation.Cloud.Views.OvfVirtualHardwareSection]}).item | where {$_.ElementName.value -eq $harddisk}).HostResource.AnyAttr[1]."#text" = "true"
(($vm.ExtensionData.Section | where {$_ -is [VMware.VimAutomation.Cloud.Views.OvfVirtualHardwareSection]}).item | where {$_.ElementName.value -eq $harddisk}).HostResource.AnyAttr[3]."#text" = $StoragePolicyURL.Href
($vm.ExtensionData.Section|where {$_-is[VMware.VimAutomation.Cloud.Views.OvfVirtualHardwareSection]}).updateserverdata()