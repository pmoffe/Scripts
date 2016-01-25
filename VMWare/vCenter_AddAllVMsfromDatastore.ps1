# User Input
$Cluster = Read-Host -Prompt 'What vCenter Cluster are you adding VMs to?'
$Datastores = Read-Host -Prompt 'What is the name of the datastore you want the VMs added from?'

# Load Config File
    #File with the stored data
        $ConfigFile = ".\VMware.config"
    #Creating an empty hash table
        $Config = @{}
    #Pulling, separating, and storing the values in $Config
        Get-Content $ConfigFile | Where-Object { $_ -notmatch '^#.*' } | ForEach-Object {
            $Keys = $_ -split "="
            $Config += @{$Keys[0]=$Keys[1]}
        }

# Import modules
$powercli = Get-PSSnapin -Name VMware.VimAutomation.Core -Registered
try {
 switch ($powercli.Version.Major) {
    { $_ -ge 6 }
        { Import-Module -Name VMware.VimAutomation.Core -ErrorAction Stop
        Write-Output "PowerCLI 6+ module imported"
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
$ESXHost = Get-Cluster $Config.$Cluster | Get-VMHost | Select-Object -First 1

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
        New-VM -VMFilePath $VMXFile -VMHost $ESXHost -Location $config.VMFolder -RunAsync
    }
}