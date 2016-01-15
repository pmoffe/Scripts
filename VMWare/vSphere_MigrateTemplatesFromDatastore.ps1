## Variables
$Cluster = Read-Host -Prompt 'In which cluster are you moving templates?'
$SrcDatastore = Read-Host -Prompt 'What Datstore are you moving templates from?'
$DstDatastore = Read-Host -Prompt 'What Datastore are you moving templates to?'

# Import custom VMWare Functions
Import-Module $PSScriptRoot\VMWare_Functions.psm1

# Load VMWare Configuration File
Get-VMWConfig

# Connect to vCenter
Connect-vSphere $Global:vmwconfig.$cluster

# Find templates in datastore
$templates = get-datastore $SrcDatastore | Get-template | select name

# Move templates to new datastore
foreach ($template in $templates.name) {
	Set-Template $template -ToVM -confirm:$False
	Get-VM -Name $template | Move-VM -datastore $DstDatastore
	Set-VM -VM $template -ToTemplate -confirm:$False
	}