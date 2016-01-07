## Variables
$Cluster = Read-Host -Prompt 'What Cluster are you adding VMs to?'
$HAVMrestartold = Read-Host -Prompt 'How many days of history do you want searched?'
$Date = Get-Date    #Today's date, don't change

# Load Config File
    #File with the stored data
        $ConfigFile = ".\VMware.config"
    #Creating an empty hash table
        $ConfigKeys = @{}
    #Pulling, separating, and storing the values in $Config
        Get-Content $ConfigFile | Where-Object { $_ -notmatch '^#.*' } | ForEach-Object {
            $Keys = $_ -split "="
            $Config += @{$Keys[0]=$Keys[1]}
        }

# Import modules
$powercli = Get-PSSnapin -Name VMware.VimAutomation.Core -Registered
try {
 switch ($powercli.Version.Major) {
    { $_ -ge 6 }
        { Import-Module -Name VMware.VimAutomation.Core -ErrorAction Stop
        Write-Host -Object 'PowerCLI 6+ module imported'
        }
    5 { Add-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction Stop
        Write-Warning -Message 'PowerCLI 5 snapin added; recommend upgrading your PowerCLI version'
        }
    default {
        throw 'This script requires PowerCLI version 5 or later'
        }
    }
}
catch { throw 'Could not load the required VMware.VimAutomation.Vds cmdlets'}

# Ignore self-signed SSL certificates for vCenter Server
$null = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings:$false -Scope User -Confirm:$false

# Connect to vCenter
try { Connect-VIServer $config.$cluster -ErrorAction Stop }
catch { throw 'Could not connect to vCenter'}

# Get VM Restart Events
#Get-VIEvent -maxsamples 100000 -Start ($Date).AddDays(-$HAVMrestartold) -type warning | Where {$_.FullFormattedMessage -match "restarted"} |select CreatedTime,FullFormattedMessage |sort CreatedTime -Descending
$VMs = Get-VIEvent -maxsamples 100000 -Start ($Date).AddDays(-$HAVMrestartold) -type warning | Where {$_.EventTypeId -match "com.vmware.vc.ha.VmRestartedByHAEvent"} #| select CreatedTime,ObjectName

if ($VMs) {
	# Add ResourceGroup column - This is why the script takes so long to run
	$body = ForEach ($VM in $VMs){
		get-vm -name $VM.ObjectName | select name, @{n="ResourcePool"; e={$_ | Get-ResourcePool}} | add-member -membertype NoteProperty -name EventTime -Value $VM.CreatedTime -PassThru
		}
	}
else {Send-MailMessage -From $config.notifyfrom -To $config.notifyto -Subject "No VMs restarted by vSphere HA in the past $HAVMrestartold day(s)" -SmtpServer $config.smtpserver
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
    
    Send-MailMessage -From $config.notifyfrom -To $config.notifyto -Subject "VMs Restarted by vSphere HA in the past $HAVMrestartold day(s)" -SmtpServer $config.smtpserver -BodyAsHtml $htmlbody
    }
else {
    Send-MailMessage -From $config.notifyfrom -To $config.notifyto -Subject "Something went wrong w/the vSphere HA restart script" -SmtpServer $config.smtpserver -BodyAsHtml $htmlbody
    }