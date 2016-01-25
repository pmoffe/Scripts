function Get-VMWConfig {
	# Load Config File
		#File with the stored data
			$ConfigFile = "$PSScriptRoot\VMware.config"
		#Creating an empty hash table
			$global:vmwconfig = @{}
		#Pulling, separating, and storing the values in $Config
			Get-Content $ConfigFile | Where-Object { $_ -notmatch '^#.*' } | ForEach-Object {
				$Keys = $_ -split "="
				$global:vmwconfig += @{$Keys[0]=$Keys[1]}
			}
}

function Connect-VSphere ($viserver) {
	# Import modules
	$powercli = Get-PSSnapin -Name VMware.VimAutomation.Core -Registered
	try {
	 switch ($powercli.Version.Major) {
		{ $_ -ge 6 }
			{ Import-Module -Name VMware.VimAutomation.Core -ErrorAction Stop
			Write-Output -Object 'PowerCLI 6+ module imported'
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
	if ($global:DefaultVIServers.name -ne $viserver) {
		try { Connect-VIServer -Server $viserver -ErrorAction Stop }
			catch { throw 'Could not connect to vCenter'}
		}
}