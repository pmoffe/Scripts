<#
The Windows Update PowerShell Module needs to be installed on your templates.
Can be downloaded from here: https://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
Note: This Windows Update Module includes the Get-WUInstall PowerShell command which is the one used to install patches remotely.
#>

$Cluster = Read-Host -Prompt 'What Cluster are you updating machines on?'
$VMName = Read-Host -Prompt 'What machine do you want to update?'
$Password = Read-Host -Prompt 'What is the local Administrator account password?' -assecurestring

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

# Start VM if not already on and answer any VM question with the default response
if ( ($WasTemplate) -or (get-vm $VMName | where-object {$_.powerstate -match "PoweredOff"})) {
	$WasOff = "Y"
	Write-Host "Starting VM $VMName" -foregroundcolor "Green"
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
}
else {
		write-host -nonewline "$VMName is alreadu Powered-On, are you sure you want to continue? (Y,N): " -foregroundcolor "Red"
		$response = read-host
		if ( $response -ne "Y" ) { exit }
	}

# Build guest OS credentials
$hostname = (get-vm $VMName).extensiondata.Guest.HostName
$username = "$hostname\Administrator"
#$password = ConvertTo-SecureString -String $MachinePass -AsPlainText -Force
$GuestOSCred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $password

# Update VMware tools if needed
Write-Host "`r`nChecking VMware Tools on $VMName" -foregroundcolor "Green"
$toolsStatus = (Get-VM $VMName | Get-View).Guest.ToolsStatus
Write-Output "Tools Status: $toolsStatus"

if ($toolsStatus -eq "toolsOld") {
		Write-Host "Updating VMware Tools on $VMName" -foregroundcolor "Green"
		Update-Tools -VM $VMName -NoReboot
		do {
			Start-Sleep 5
			$toolsStatus = (Get-VM $VMName | Get-View).Guest.ToolsStatus
			}
		until ( $toolsStatus -eq "toolsOk" )
		}
else { Write-Output "No VMware Tools update required" }

# Set PowerShell Execution Policy to UnRestricted
Write-Host "`r`nUnRestricting PowerShell Execution Policy" -foregroundcolor "Green"
Invoke-VMScript -ScriptType PowerShell -ScriptText "invoke-command -scriptblock { set-executionpolicy unrestricted -Force }" -VM $VMName -GuestCredential $GuestOSCred | Out-Null

# Sleep
Start-Sleep 5

<#
The following is the cmdlet that will invoke the Get-WUInstall inside the GuestVM to install all available Windows
updates; optionally results can be exported to a log file to see the patches installed and related results.
#>

Write-Host "`r`nRunning PSWindowsUpdate script. This may take some time..." -foregroundcolor "Green"
Invoke-VMScript -ScriptType PowerShell -ScriptText "Import-Module PSWindowsUpdate; Get-WUInstall -AcceptAll -AutoReboot -Verbose | Out-File C:\PSWindowsUpdate.log" -VM $VMName -GuestCredential $GuestOSCred | Out-file -Filepath WUResults.log

do {
	Write-Output "Update installation complete, Waiting for $VMName to respond via the network..."
	Start-Sleep 30
	# Get vm IP
	do { $vmip = (Get-VM $VMName | Get-View).Guest.IPAddress }
	until ( $vmip )
	}
until( Test-Connection $vmip -Quiet | Where-Object { $True } )

#Write-Output "$VMName is up. Waiting half hour for large updates to complete before final reboot."
#Start-Sleep 1800

# Restart VMGuest one more time in case Windows Update requires it and for whatever reason the -AutoReboot switch didn't complete it.
Write-Host "Performing final reboot of $VMName" -foregroundcolor "Green"
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
Write-Host "`r`nRestricting PowerShell Execution Policy" -foregroundcolor "Green"
Invoke-VMScript -ScriptType PowerShell -ScriptText "invoke-command -scriptblock { set-executionpolicy restricted -Force }" -VM $VMName -GuestCredential $GuestOSCred | Out-Null

# Shut down the VM if it was a template or off when script started.
if ($WasOff) {
	Write-Host "`r`nShutting down $VMName" - foregroundcolor "Green"
	Stop-VMGuest -VM $VMName -Confirm:$false | Out-Null
	# Waiting for VM to be powered-off
	do {
		Write-Output "Waiting for $VMName to shut down...`r`n"
		Start-Sleep 10
		}
		until (Get-VM -Name $VMName | Where-Object { $_.powerstate -eq "PoweredOff" } )
}

If ($WasTemplate) {
	Write-Host "Converting $VMName to template" -foregroundcolor "Green"
	Set-VM -VM $VMName -ToTemplate -Confirm:$false | Out-Null
	}

# Set note with last updated date
set-VM -VM $VMName -Notes "VM Last Updated $(Get-Date)" -Confirm:$false | Out-Null

Write-Host "Finished updating $VMName" -foregroundcolor "Magenta"

Write-Output "Script Finished $(Get-Date)"
