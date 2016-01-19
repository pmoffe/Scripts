<#
What's required on Templates:
Server 2008/2012 Templates need to be running PowerShell v.3 minimum but v.4 is highly recommended.
PowerShell 4 for 2008 server can be downloaded here: http://www.microsoft.com/en-us/download/details.aspx?id=40855

The Windows Update PowerShell Module needs to be installed on your templates.
Can be downloaded from here: https://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
Note: This Windows Update Module includes the Get-WUInstall PowerShell command which is the one used to install patches remotely.
#>

$Cluster = Read-Host -Prompt 'What Cluster are you migrating templates on?'
$TemplateVMName = Read-Host -Prompt 'What template do you want to update?'
$TemplatePass = Read-Host -Prompt ' What is the local Administrators password?'

# Build guest OS credentials
$username="$TemplateVMName\Administrator"
$password = ConvertTo-SecureString -String $TemplatePass -AsPlainText -Force
$GuestOSCred=New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $password

Write-Output "Script started $(Get-Date)"

# Import custom VMWare Functions
Import-Module $PSScriptRoot\VMWare_Functions.psm1

# Load VMWare Configuration File
Get-VMWConfig

# Connect to vCenter
Connect-vSphere $Global:vmwconfig.$cluster

# Convert the template to a VM
Set-Template -Template $TemplateVMName -ToVM -Confirm:$false
Start-Sleep -Seconds 20

# Start the VM. Answer any question with the default response
Write-Output "Starting VM $TemplateVMName"
Start-VM -VM $TemplateVMName | Get-VMQuestion | Set-VMQuestion -DefaultOption -Confirm:$false

# Wait for the VM to become accessible after starting
do {
	Write-Output "Waiting for $TemplateVMName to respond...`r`n"
	Start-Sleep -Seconds 10
	# Get vm attb's (We need the VMs IP)
	do { $vmip = (Get-VM $TemplateVMName | Get-View).Guest.IPAddress }
	until ( $vmip )
	}
until( Test-Connection $vmip -Quiet | ? { $True } )

# Wait additional time for the VM to "settle" after booting up
Write-Output "$TemplateVMName is up. Resting for 2 minutes to allow the VM to `"settle`"."
Start-Sleep 120

# Update VMware tools if needed
Write-Output "Checking VMware Tools on $TemplateVMName"
do { 
	$toolsStatus = (Get-VM $TemplateVMName | Get-View).Guest.ToolsStatus 
	Write-Output "Tools Status: " $toolsStatus 
	sleep 3 
	if ($toolsStatus -eq "toolsOld") 
		{ Write-Output "Updating VMware Tools on $TemplateVMName"
		Update-Tools -VM $TemplateVMName -NoReboot
		}
else { Write-Output "VMWare tools updated or no VMware Tools update required" }
	}
until ( $toolsStatus -eq "toolsOk" ) 
 
# Set PowerShell Execution Policy to UnRestricted
Write-Output "UnRestricting PowerShell Execution Policy"
Invoke-VMScript -ScriptType PowerShell -ScriptText "invoke-command -scriptblock { set-executionpolicy unrestricted -confirm:`$false }" -VM $TemplateVMName -GuestCredential $GuestOSCred

<#
The following is the cmdlet that will invoke the Get-WUInstall inside the GuestVM to install all available Windows 
updates; optionally results can be exported to a log file to see the patches installed and related results.
#>

Write-Output "Running PSWindowsUpdate script"
Invoke-VMScript -ScriptType PowerShell -ScriptText "Import-Module PSWindowsUpdate; Get-WUInstall –AcceptAll –AutoReboot -Verbose | Out-File C:\PSWindowsUpdate.log" -VM $TemplateVMName -GuestCredential $GuestOSCred | Out-file -Filepath WUResults.log

Write-Output "Waiting 300 seconds for automatic reboot if updates were applied"
Start-Sleep -Seconds 300

do {
	Write-Output "Waiting for $TemplateVMName to respond...`r`n"
	Start-Sleep -Seconds 10
	$vmip = (Get-VM $TemplateVMName | Get-View).Guest.IPAddress
	}
until( Test-Connection $vmip -Quiet | ? { $True } )


Write-Output "$TemplateVMName is up. Waiting 1 hour for large updates to complete before final reboot."
Start-Sleep -Seconds 3600
 
#Restart VMGuest one more time in case Windows Update requires it and for whatever reason the –AutoReboot switch didn’t complete it.
Write-Output "Performing final reboot of $TemplateVMName"
Restart-VMGuest -VM $TemplateVMName -Confirm:$false
do {
	Write-Output "Waiting 10 seconds for $TemplateVMName to respond...`r`n"
	Start-Sleep -Seconds 10
	$vmip = (Get-VM $TemplateVMName | Get-View).Guest.IPAddress
	}
until( Test-Connection $vmip -Quiet | ? { $True } )

# Wait additional time for the VM to "settle" after booting up
Write-Output "$TemplateVMName is up. Resting for 2 minutes to allow the VM to `"settle`"."
Start-Sleep 120

# Set PowerShell Execution Policy to Restricted
Write-Output "Restricting PowerShell Execution Policy"
Invoke-VMScript -ScriptType PowerShell -ScriptText "invoke-command -scriptblock { set-executionpolicy restricted -confirm:`$false }" -VM $TemplateVMName -GuestCredential $GuestOSCred

# Shut down the VM and convert it back to a template
Write-Output "Shutting down $TemplateVMName and converting it back to a template"
Stop-VMGuest –VM $TemplateVMName -Confirm:$false

do {
	Write-Output "Waiting for $TemplateVMName to shut down...`r`n"
	Start-Sleep -Seconds 10
	}
until(Get-VM -Name $TemplateVMName | Where-Object { $_.powerstate -eq "PoweredOff" } )
Set-VM –VM $TemplateVMName -ToTemplate -Confirm:$false

Write-Output "Finished updating $TemplateVMName"

Write-Output "Script completed $(Get-Date)"