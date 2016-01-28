function Get-NAConfig {
	# Load Config File
	#File with the stored data
		$ConfigFile = "$PSScriptRoot\NetApp.config"
	#Creating an empty hash table
		$global:naconfig = @{}
	#Pulling, separating, and storing the values in $Config
		Get-Content $ConfigFile | Where-Object { $_ -notmatch '^#.*' } | ForEach-Object {
			$Keys = $_ -split "="
			$global:naconfig += @{$Keys[0]=$Keys[1]}
	    	}
}

function Connect-NAFiler {
	Param (
        $nafiler
        )
    
    # Import NetApp module
	Import-Module DataONTAP
	
	# Connect to NetApp
	if ($global:DefaultVIServers.name -ne $viserver) {
		try { 
		Write-Host "Connecting to $filer..." -foregroundcolor "green"
		Connect-NcController $nafiler -ErrorAction Stop -Global | Out-Null }
			catch { throw 'Could not connect to NetApp'}
		}
}