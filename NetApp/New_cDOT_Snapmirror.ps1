#Connect to NetApp as admin
Write-Host "Connecting to $filer..." -foregroundcolor "green"
Connect-NcController $filer -Credential $cred -vserver $cust_svm | Out-Null

# Set internal variables
Write-Host "Loading Internal Variables..." -foregroundcolor "green"
$snapcsv = Import-Csv .\New_cDOT_Snapmirror.csv

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
