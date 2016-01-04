## Variables: Update these to the match the environment
$Cluster = Read-Host -Prompt 'What Cluster are you adding VMs to (PHL-01, PHL-14 or PHX-55)?'
$Datastores = Read-Host -Prompt 'What is the name of the datastore you want the VMs added from?'

$VMFolder = "Temp"

#-----------------------------------------
#No configurable variables past this point
#-----------------------------------------

#Set vCenter IP based on site Cluster
if($Cluster -eq "PHL-01") {$vcenterip = "10.30.0.19" }
if($Cluster -eq "PHL-14") {$vcenterip = "10.30.0.19" }
if($Cluster -eq "PHX-55") {$vcenterip = "10.35.0.19" }

# Import modules
$powercli = Get-PSSnapin -Name VMware.VimAutomation.Core -Registered
try {
 switch ($powercli.Version.Major) {
    { $_ -ge 6 }
        { Import-Module -Name VMware.VimAutomation.Core -ErrorAction Stop
        Write-Host -Object 'PowerCLI 6+ module imported'
        }
    5 { Add-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction Stop
        Write-Warning -Message 'PowerCLI 5 snapin added; recommend upgrading your PowerCLI version'
        }
    default {
        throw 'This script requires PowerCLI version 5 or later'
        }
    }
}
catch { throw 'Could not load the required VMware.VimAutomation.Vds cmdlets'}

# Ignore self-signed SSL certificates for vCenter Server
$null = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings:$false -Scope User -Confirm:$false

# Connect to vCenter
try { Connect-VIServer $vcenterip -ErrorAction Stop }
catch { throw 'Could not connect to vCenter'}

# Select an ESXi host to own the VMX files for the import process:
$ESXHost = Get-Cluster $Cluster | Get-VMHost | select -First 1

##Add .VMX (Virtual Machines) to Inventory from Datastore
foreach($Datastore in $Datastores) {
    # Searches for .VMX Files in datastore variable
    $ds = Get-Datastore -Name $Datastore | %{Get-View $_.Id}
    $SearchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
    $SearchSpec.matchpattern = "*.vmx"
    $dsBrowser = Get-View $ds.browser
    $DatastorePath = "[" + $ds.Summary.Name + "]"
     
    # Find all .VMX file paths in Datastore variable and filters out .snapshot
    $SearchResult = $dsBrowser.SearchDatastoreSubFolders($DatastorePath, $SearchSpec) | where {$_.FolderPath -notmatch ".snapshot"} | %{$_.FolderPath + ($_.File | select Path).Path}
     
    # Register all .VMX files with vCenter
    foreach($VMXFile in $SearchResult) {
        New-VM -VMFilePath $VMXFile -VMHost $ESXHost -Location $VMFolder -RunAsync
    }
}