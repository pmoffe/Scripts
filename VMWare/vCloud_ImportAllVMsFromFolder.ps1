# User Input
$Cluster = Read-Host -Prompt 'What vCenter Cluster are you importing from?'
$orgvdc = Read-Host -Prompt 'What Org vDC are you importing to?'
#$cinetwork = Read-Host -Prompt 'What Org VDC Network should these VMs belong to?'

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

if ($global:DefaultVIServers.name -ne $config.$cluster) {
	try { Connect-VIServer -Server $config.$cluster -ErrorAction Stop }
		catch { throw 'Could not connect to vCenter'}
	}

if ($global:DefaultCIServers.name -ne $config.ciserver) {
	try { Connect-CIServer -Server $config.ciserver -ErrorAction Stop }
		catch { throw 'Could not connect to vCloud'}
	}

$vms = get-folder $config.VMImportFolder | get-vm

foreach ($vm in $vms) { 
	Write-Host "Importing $vm" -foregroundcolor "Green"
	new-civapp -name $vm -orgvdc $orgvdc -ErrorAction Stop | out-null
	get-civapp $vm | Import-CIVApp $vm -NoCopy:$False -RunAsync -ErrorAction Stop | out-null
}

## Change the network:  Currently Broken
#Start-Sleep -s 30
#foreach ($vm in $vms) {
#	get-civapp $vm | get-civm | Get-CINetworkAdapter | Set-CINetworkAdapter -vappnetwork $cinetwork -IPaddressAllocationMode Pool -Connected $True
#}

## Disconnect from vCloud and vSphere
#Disconnect-VIServer -Server $viserver -Confirm:$false
#Disconnect-CIServer -Server $ciserver -Confirm:$false
