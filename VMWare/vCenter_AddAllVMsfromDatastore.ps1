# User Input
$Cluster = Read-Host -Prompt 'What vCenter Cluster are you adding VMs to?'
$Datastores = Read-Host -Prompt 'What is the name of the datastore you want the VM(s) added from?'
$VMFolder = Read-Host -Prompt 'What vCenter folder do you want the VMs placed into?'

# Import custom VMWare Functions
Import-Module $PSScriptRoot\VMWare_Functions.psm1

# Load VMWare Configuration File
Get-VMWConfig

# Connect to vCenter
Connect-vSphere -viserver $Global:vmwconfig.$cluster

# Select an ESXi host to own the VMX files for the import process:
$ESXHost = Get-Cluster $Config.$Cluster | Get-VMHost | Get-Random

##Add .VMX (Virtual Machines) to Inventory from Datastore
foreach($Datastore in $Datastores) {
    # Searches for .VMX Files in datastore variable
    $ds = Get-Datastore -Name $Datastore | ForEach-Object {Get-View $_.Id}
    $SearchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
    $SearchSpec.matchpattern = "*.vmx"
    $dsBrowser = Get-View $ds.browser
    $DatastorePath = "[" + $ds.Summary.Name + "]"

    # Find all .VMX file paths in Datastore variable and filters out .snapshot
    $SearchResult = $dsBrowser.SearchDatastoreSubFolders($DatastorePath, $SearchSpec) | Where-Object {$_.FolderPath -notmatch ".snapshot"} | ForEach-Object {$_.FolderPath + ($_.File | Select-Object Path).Path}

    # Register all .VMX files with vCenter
    foreach($VMXFile in $SearchResult) {
        New-VM -VMFilePath $VMXFile -VMHost $ESXHost -Location $VMFolder -RunAsync
    }
}
