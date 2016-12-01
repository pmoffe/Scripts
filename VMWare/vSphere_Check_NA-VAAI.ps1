param (
   [Parameter(Mandatory=$true, HelpMessage="What vCenter(s) do you want to check?")]
   [ValidateNotNullorEmpty()]
   [string[]]
   $vCenters
)

Foreach ($vCenter in $vCenters) {

  # Connect to vCenter
  Connect-viserver $vCenter | Out-Null

  Foreach ($vmhost in Get-VMHost) {
       $esxcli = Get-EsxCli -vmhost $vmhost
       # check that netapp vib is installed
       $vsc = $esxcli.software.vib.list() | Where-Object { $_.Name -eq "NetAppNasPlugin" }
       if ($vsc) {
          "Found " + $vsc.id + " on " + $vmhost.Name
       } else {
          Write-Host "NetAppNasPlugin missing from" $vmhost.Name -foregroundcolor "red"
       }
  }

  #Disconnect vCenter
  disconnect-viserver -Confirm:$false

}
