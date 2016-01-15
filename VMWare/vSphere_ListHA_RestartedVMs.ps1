## Variables
$Cluster = Read-Host -Prompt 'What Cluster are you inquiring about?'
$HAVMrestartold = Read-Host -Prompt 'How many days of history do you want searched?'
$Date = Get-Date    #Today's date, don't change

# Import custom VMWare Functions
Import-Module $PSScriptRoot\VMWare_Functions.psm1

# Load VMWare Configuration File
Get-VMWConfig

# Connect to vCenter
Connect-vSphere $Global:vmwconfig.$cluster

# Get VM Restart Events
#Get-VIEvent -maxsamples 100000 -Start ($Date).AddDays(-$HAVMrestartold) -type warning | Where {$_.FullFormattedMessage -match "restarted"} |select CreatedTime,FullFormattedMessage |sort CreatedTime -Descending
$VMs = Get-VIEvent -maxsamples 100000 -Start ($Date).AddDays(-$HAVMrestartold) -type warning | Where {$_.EventTypeId -match "com.vmware.vc.ha.VmRestartedByHAEvent"} #| select CreatedTime,ObjectName

if ($VMs) {
	# Add ResourceGroup column - This is why the script takes so long to run
	$body = ForEach ($VM in $VMs){
		get-vm -name $VM.ObjectName | select name, @{n="ResourcePool"; e={$_ | Get-ResourcePool}} | add-member -membertype NoteProperty -name EventTime -Value $VM.CreatedTime -PassThru
		}
	}
else {Send-MailMessage -From $global:vmwconfig.notifyfrom -To $global:vmwconfig.notifyto -Subject "No VMs restarted by vSphere HA in the past $HAVMrestartold day(s)" -SmtpServer $global:vmwconfig.smtpserver
	exit
	}

# Remove UUID - Currently not working -
$output = $body # -replace '\(([^)]+)\)',''

# Send email
if ($output) {
	$style = "<style type='text/css'>"
	$style = $style + "BODY{background-color:#FFFFFF;font-family:Verdana;}"
	$style = $style + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;font-size:12px;}"
	$style = $style + "TH{border-width: 1px;text-align: center;padding: 2px;border-style: solid;border-color: black;background-color:#D3D3D3 }"
	$style = $style + "TD{border-width: 1px;text-align: center;padding: 2px;border-style: solid;border-color: black;background-color:#FFFFFF }"
	$style = $style + "</style>"
   
    $htmlbody = $output | ConvertTo-Html -Head $style | Out-String 
    
    Send-MailMessage -From $global:vmwconfig.notifyfrom -To $global:vmwconfig.notifyto -Subject "VMs Restarted by vSphere HA in the past $HAVMrestartold day(s)" -SmtpServer $global:vmwconfig.smtpserver -BodyAsHtml $htmlbody
    }
else {
    Send-MailMessage -From $global:vmwconfig.notifyfrom -To $global:vmwconfig.notifyto -Subject "Something went wrong w/the vSphere HA restart script" -SmtpServer $global:vmwconfig.smtpserver -BodyAsHtml $htmlbody
    }