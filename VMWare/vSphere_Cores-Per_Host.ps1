param (
   [Parameter(Mandatory=$true, HelpMessage="What vCenter(s) do you want to check?")]
   [ValidateNotNullorEmpty()]
   [string[]]
   $vCenters
)

$result = @()
foreach($vCenter in $vCenters) {
  Connect-viserver $vCenter | Out-Null
    $vmhost = get-vmhost
    foreach ($esxi in $vmhost) {
        $HostCPU = $esxi.ExtensionData.Summary.Hardware.NumCpuPkgs
        $HostCPUcore = $esxi.ExtensionData.Summary.Hardware.NumCpuCores/$HostCPU
        $obj = new-object psobject
        $obj | Add-Member -MemberType NoteProperty -Name name -Value $esxi.Name
        $obj | Add-Member -MemberType NoteProperty -Name CPUSocket -Value $HostCPU
        $obj | Add-Member -MemberType NoteProperty -Name Corepersocket -Value $HostCPUcore
        $result += $obj
    }
    disconnect-viserver -Confirm:$false
}

$result | format-table name,CPUSocket,Corepersocket -AutoSize

$sum = $result.Corepersocket -join '+'
Write-Host "Total CPU Cores:"
 Invoke-Expression $sum
