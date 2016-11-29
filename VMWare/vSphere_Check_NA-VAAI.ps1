$vCenter = Read-Host -Prompt 'What vCenter do you want to check?'

# Connect to vCenter
Connect-viserver $vCenter

Foreach ($vmhost in Get-VMHost) {
     $esxcli = Get-EsxCli -vmhost $vmhost
     # check that netapp vib is installed
     $vsc = $esxcli.software.vib.list() | Where-Object { $_.Name -eq "NetAppNasPlugin" }
     if ($vsc) {
        "Found " + $vsc.id + " on " + $vmhost.Name
     } else {
        Write-Host "NetAppNasPlugin missing from " $vmhost.Name -foregroundcolor "red"
     }
}
