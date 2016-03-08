function Get-VMWConfig {
	# File with the stored data
		$ConfigFile = "$PSScriptRoot\VMware.config"
	# Creating an empty hash table
		$global:vmwconfig = @{}
	# Pulling, separating, and storing the values in $Global:vmwconfig
		Get-Content $ConfigFile | Where-Object { $_ -notmatch '^#.*' } | ForEach-Object {
			$Keys = $_ -split "="
			$global:vmwconfig += @{$Keys[0]=$Keys[1]}
	    	}
}

function Connect-VSphere {
	Param (
        $viserver
        )

    # Import VIM module
	$powercli = Get-PSSnapin -Name VMware.VimAutomation.Core -Registered
	try {
	 switch ($powercli.Version.Major) {
		{ $_ -ge 6 }
			{ Import-Module -Name VMware.VimAutomation.Core -ErrorAction Stop -Global
			# Write-Output "PowerCLI 6+ module imported"
			}
		5 {
		#	Add-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction Stop
			Write-Warning -Message 'PowerCLI version 6 or later required, you appear to have version 5. Please upgrade.'
			exit
			}
		default {
			throw 'This script requires PowerCLI version 5 or later'
			}
		}
	}
	catch { throw 'Could not load the required VMware cmdlets, do you have PowerCLI version 6 or later installed?'}

	# Ignore self-signed SSL certificates for vCenter Server
	$null = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings:$false -Scope User -Confirm:$false

	# Connect to vCenter if not already connected
	if ($global:DefaultVIServers.name -ne $viserver) {
		try { Connect-VIServer -Server $viserver -ErrorAction Stop | Out-Null }
			catch { throw 'Could not connect to vCenter'}
		}
}

function Connect-VCloud {
	Param (
        $ciserver
        )
	$powercli = Get-PSSnapin -Name VMware.VimAutomation.Core -Registered
	try {
	 switch ($powercli.Version.Major) {
		{ $_ -ge 6 } {
            Import-Module -Name VMware.VimAutomation.Vds -ErrorAction Stop -Global
            Import-Module -Name VMware.VimAutomation.Cloud -ErrorAction Stop -Global
			}
		5 {
    #        Add-PSSnapin -Name VMware.VimAutomation.Vds -ErrorAction Stop
    #        Add-PSSnapin -Name VMware.VimAutomation.Cloud -ErrorAction Stop
			Write-Warning -Message 'PowerCLI version 6 or later required, you appear to have version 5. Please upgrade.'
			exit
			}
		default {
			throw 'This script requires PowerCLI version 5 or later'
			}
		}
	}
	catch { throw 'Could not load the required VMware cmdlets, do you have PowerCLI version 6 or later installed?'}

	# Ignore self-signed SSL certificates for vCenter Server
	$null = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings:$false -Scope User -Confirm:$false

    if ($global:DefaultCIServers.name -ne $ciserver) {
	    try { Connect-CIServer -Server $ciserver -ErrorAction Stop | Out-Null }
		    catch { throw 'Could not connect to vCloud'}
    }
}
