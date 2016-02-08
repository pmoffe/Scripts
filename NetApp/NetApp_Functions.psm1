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

function Connect-NaFiler {
	Param (
        $nafiler
        )

  # Import NetApp module
	Import-Module DataONTAP -Global

	# Connect to NetApp
	if ($global:CurrentNaController.name -ne $nafiler) {
		try {
		Write-Host "Connecting to 7mode controller: $nafiler" -foregroundcolor "green"
		Connect-NaController $nafiler -ErrorAction Stop }
			catch { throw 'Could not connect to NetApp'}
		}
}

function Connect-NcFiler {
	Param (
        $ncfiler
        )

  # Import NetApp module
	Import-Module DataONTAP -Global

	# Connect to NetApp
	if ($global:CurrentNcController.name -ne $ncfiler) {
		try {
		Write-Host "Connecting to cDOT controller: $ncfiler" -foregroundcolor "green"
		Connect-NcController $ncfiler -ErrorAction Stop }
			catch { throw 'Could not connect to NetApp'}
		}
}
