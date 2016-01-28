<#
The Windows Update PowerShell Module needs to be installed on your templates.
Can be downloaded from here: https://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
Note: This Windows Update Module includes the Get-WUInstall PowerShell command which is the one used to install patches remotely.
#>

$Cluster = Read-Host -Prompt 'What Cluster are you updating machines on?'
$VMName = Read-Host -Prompt 'What machine do you want to update?'
$MachinePass = Read-Host -Prompt 'What is the local Administrator account password?'

Write-Output "`r`nScript started $(Get-Date)`r`n"

# Import custom VMWare Functions
Import-Module $PSScriptRoot\VMWare_Functions.psm1

# Load VMWare Configuration File
Get-VMWConfig

# Connect to vCenter
Connect-vSphere -viserver $Global:vmwconfig.$cluster

# If Template, convert to VM
if ( Get-Template $VMName -erroraction Silentlycontinue ) {
	Set-Template -Template $VMName -ToVM -Confirm:$false | Out-Null
	Start-Sleep 20
	$WasTemplate = "Y"
	}

# Build guest OS credentials
$username = "$hostname\Administrator"
$password = ConvertTo-SecureString -String $MachinePass -AsPlainText -Force
$GuestOSCred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $password

$hostname = (get-vm $VMName).extensiondata.Guest.HostName

# Start the VM. Answer any question with the default response
Write-Output "Starting VM $VMName"
Start-VM -VM $VMName | Get-VMQuestion | Set-VMQuestion -DefaultOption -Confirm:$false

# Wait for the VM to become accessible after starting
do {
	Write-Output "Waiting for $VMName to respond..."
	Start-Sleep 10
	# Get vm IP
	do { $vmip = (Get-VM $VMName | Get-View).Guest.IPAddress }
	until ( $vmip )
	}
until( Test-Connection $vmip -Quiet | Where-Object { $True } )

# Wait additional time for the VM to "settle" after booting up
Write-Output "$VMName is up. Resting for 2 minutes to allow the VM to `"settle`"."
Start-Sleep 120

# Update VMware tools if needed
Write-Output "`r`nChecking VMware Tools on $VMName"
do { 
	$toolsStatus = (Get-VM $VMName | Get-View).Guest.ToolsStatus 
	Write-Output "Tools Status: $toolsStatus"
	if ($toolsStatus -eq "toolsOld") {
		Write-Output "Updating VMware Tools on $VMName"
		Update-Tools -VM $VMName -NoReboot
		do { 
			Start-Sleep 5
			$toolsStatus = (Get-VM $VMName | Get-View).Guest.ToolsStatus
			}
		until ( $toolsStatus -eq "toolsOk" )
		}
	else { Write-Output "No VMware Tools update required" }
	}
until ( $toolsStatus -eq "toolsOk" ) 
 
# Set PowerShell Execution Policy to UnRestricted
Write-Output "`r`nUnRestricting PowerShell Execution Policy"
Invoke-VMScript -ScriptType PowerShell -ScriptText "invoke-command -scriptblock { set-executionpolicy unrestricted -Force }" -VM $VMName -GuestCredential $GuestOSCred | Out-Null

# Sleep
Start-Sleep 5

<#
The following is the cmdlet that will invoke the Get-WUInstall inside the GuestVM to install all available Windows 
updates; optionally results can be exported to a log file to see the patches installed and related results.
#>

Write-Output "`r`nRunning PSWindowsUpdate script"
Invoke-VMScript -ScriptType PowerShell -ScriptText "Import-Module PSWindowsUpdate; Get-WUInstall -AcceptAll -AutoReboot -Verbose | Out-File C:\PSWindowsUpdate.log" -VM $VMName -GuestCredential $GuestOSCred | Out-file -Filepath WUResults.log

do {
	Write-Output "Update installation complete, waiting for $VMName to respond via the network...`r`n"
	Start-Sleep 30
	# Get vm IP
	do { $vmip = (Get-VM $VMName | Get-View).Guest.IPAddress }
	until ( $vmip )
	}
until( Test-Connection $vmip -Quiet | Where-Object { $True } )

Write-Output "$VMName is up. Waiting half hour for large updates to complete before final reboot."
Start-Sleep 1800
 
# Restart VMGuest one more time in case Windows Update requires it and for whatever reason the -AutoReboot switch didn't complete it.
Write-Output "Performing final reboot of $VMName"
Restart-VMGuest -VM $VMName -Confirm:$false | Out-Null

do {
	Write-Output "Waiting for $VMName to respond..."
	Start-Sleep 10
	# Get vm IP
	do { $vmip = (Get-VM $VMName | Get-View).Guest.IPAddress }
	until ( $vmip )
	}
until( Test-Connection $vmip -Quiet | Where-Object { $True } )

# Wait additional time for the VM to "settle" after booting up
Write-Output "$VMName is up. Resting for 2 minutes to allow the VM to `"settle`"."
Start-Sleep 120

# Set PowerShell Execution Policy to Restricted
Write-Output "`r`nRestricting PowerShell Execution Policy"
Invoke-VMScript -ScriptType PowerShell -ScriptText "invoke-command -scriptblock { set-executionpolicy restricted -Force }" -VM $VMName -GuestCredential $GuestOSCred | Out-Null

# Shut down the VM
Write-Output "`r`nShutting down $VMName"
Stop-VMGuest -VM $VMName -Confirm:$false | Out-Null

# Waiting for VM to be powered-off
do {
	Write-Output "Waiting for $VMName to shut down...`r`n"
	Start-Sleep 10
	}
until (Get-VM -Name $VMName | Where-Object { $_.powerstate -eq "PoweredOff" } )

# Set note with last updated date
Set-VM -VM $VMName -Notes "VM Last Updated $(Get-Date)" -Confirm:$false

If ($WasTemplate) { 
	Write-Output "Converting $VMName to template"
	Set-VM -VM $VMName -ToTemplate -Confirm:$false | Out-Null
	}

Write-Output "Finished updating $VMName"

Write-Output "Script Finished $(Get-Date)"
