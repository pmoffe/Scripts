#SVM Configuratino Variables
$site_id =	Read-Host -Prompt 'What Site are you adding SnapMirrors to?'
$cust_id =	Read-Host -Prompt 'What Client are these new SnapMirrors for? (use the 3 character client ID)'
$cust_svm = Read-Host -Prompt 'What is the destination SVM Name?'
$agg = Read-Host -Prompt 'What Aggregate should the snapmirror volumes be placed on?'


#-------------------------------------------#
# No configurable variables past this point #
#-------------------------------------------#

#Run initial checks
if(-not $site_id -or -not $cust_id -or -not $cust_svm -or -not $agg) {
	Write-Host "Problem with Variables, I quit." -foregroundcolor "red"
	exit
}

# Set internal variables
Write-Host "Importing the cDOT_New_Snapmirror.csv file..." -foregroundcolor "green"
    $snapcsv = Import-Csv $PSScriptRoot\cDOT_New_Snapmirror.csv

# Import custom NetApp Functions
Import-Module $PSScriptRoot\NetApp_Functions.psm1

# Load NetApp Config
Get-NAConfig

# Connect to NetApp
Connect-NcFiler -ncfiler $Global:naconfig.$site_id

#Create Volume(s)
Write-Host "Creating Volume(s)..." -foregroundcolor "green"
foreach ($item in $snapcsv) {
	New-NcVol -Name ( "$site_id"+"_"+"$cust_id"+"_NVol_Repl_"+$item.source_volume -replace "-", "_" ) -Aggregate $agg -Size 1g -JunctionPath $null -SpaceReserve none -Type dp -Language $item.language
	}

#Create and Initialize snapmirrors
Write-Host "Creating and Initializing Snapmirror relationships..." -foregroundcolor "green"
foreach ($item in $snapcsv) {
	New-NcSnapmirror -DestinationVserver $cust_svm -DestinationVolume ( "$site_id"+"_"+"$cust_id"+"_NVol_Repl_"+$item.source_volume -replace "-", "_" ) -SourceVserver $item.source_vserver -SourceVolume $item.source_volume -Schedule $item.schedule -Type dp
	Invoke-NcSnapmirrorInitialize -DestinationVserver $cust_svm -DestinationVolume ( "$site_id"+"_"+"$cust_id"+"_NVol_Repl_"+$item.source_volume -replace "-", "_" )
	}
