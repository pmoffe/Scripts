param (
   [Parameter(Mandatory=$true, HelpMessage="What VM(s) do you want to change UUIDs for?")]
   [ValidateNotNullorEmpty()]
   [string[]]
   $VMs
)

$vCenter = Read-Host -Prompt 'What vCenter Server do these VMs belong to?'

Connect-viserver $vCenter | Out-Null

foreach($VM in $VMs) {
  $date = get-date -format "dd hh mm ss"
  $newUuid = "56 4d 50 2e 9e df e5 e4-a7 f4 21 3b " + $date
  $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
  $spec.uuid = $newUuid
  $vmspec = get-vm | where-object { $_.Name -like '*'+$VM+'*' }

  if (@($vmspec).count -eq 1) {
    Write-Host "VM:" $vmspec -foregroundcolor "green"
    Write-Host "Old UUID:" (get-vm "$vmspec" | %{(Get-View $_.Id).config.uuid}) -foregroundcolor "green"
    Write-Host "Applying new UUID..." -foregroundcolor "yellow"
    $vmspec.Extensiondata.ReconfigVM_Task($spec) | Out-Null
    Start-Sleep -s 5
    Write-Host "New UUID:" (get-vm "$vmspec" | %{(Get-View $_.Id).config.uuid}) `n`n -foregroundcolor "green"

    }

    else { if (@($vmspec).count -eq 0) {
        write-host $VM NOT Found! I quit. -foregroundcolor "red"}
        else { write-host $VM matches multiple virtual machines... I quit. -foregroundcolor "red" }
        }
}

disconnect-viserver * -Confirm:$false
