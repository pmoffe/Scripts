# User Input
$Cluster = Read-Host -Prompt 'What vCenter Cluster are you importing from?'
$VMImportFolder = Read-Host -Prompt 'What folder do you want the VM(s) imported from?'
$orgvdc = Read-Host -Prompt 'What Org vDC are you importing to?'
#$cinetwork = Read-Host -Prompt 'What Org VDC Network should these VMs belong to?'

# Import custom VMWare Functions
Import-Module $PSScriptRoot\VMWare_Functions.psm1

# Load VMWare Configuration File
Get-VMWConfig

# Connect to vCenter
Connect-vSphere -viserver $Global:vmwconfig.$cluster

# Connect to vCloud Director
Connect-vCloud -ciserver $Global:vmwconfig.ciserver


$vms = get-folder $VMImportFolder | get-vm

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
