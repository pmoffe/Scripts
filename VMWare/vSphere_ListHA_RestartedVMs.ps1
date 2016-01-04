## Variables: Update these to the match the environment
$Cluster = Read-Host -Prompt 'What Cluster are you adding VMs to (PHL-01, PHL-14 or PHX-55)?'
$HAVMrestartold = Read-Host -Prompt 'How many days of history do you want searched?'


#-----------------------------------------
#No configurable variables past this point
#-----------------------------------------
$Date = Get-Date    #Today's date, don't change

#Set vCenter IP based on site Cluster
if($Cluster -eq "PHL-01") {$vcenterip = "10.30.0.19" }
if($Cluster -eq "PHL-14") {$vcenterip = "10.30.0.19" }
if($Cluster -eq "PHX-55") {$vcenterip = "10.35.0.19" }

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
try { Connect-VIServer $vcenterip -ErrorAction Stop }
catch { throw 'Could not connect to vCenter'}

# Get VM Restart Events
#Get-VIEvent -maxsamples 100000 -Start ($Date).AddDays(-$HAVMrestartold) -type warning | Where {$_.FullFormattedMessage -match "restarted"} |select CreatedTime,FullFormattedMessage |sort CreatedTime -Descending
$VMs = Get-VIEvent -maxsamples 100000 -Start ($Date).AddDays(-$HAVMrestartold) -type warning | Where {$_.EventTypeId -match "com.vmware.vc.ha.VmRestartedByHAEvent"} #| select CreatedTime,ObjectName

# Add ResourceGroup column - This is why the script takes so long to run
$body = ForEach ($VM in $VMs){
    get-vm -name $VM.ObjectName | select name, @{n="ResourcePool"; e={$_ | Get-ResourcePool}} | add-member -membertype NoteProperty -name EventTime -Value $VM.CreatedTime -PassThru
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
    
    Send-MailMessage -From "mgraham@haservices.com" -To mgraham@haservices.com,rwojewoda@haservices.com,jbarry@haservices.com -Subject "VMs Restarted by vSphere HA in the past 24 hours" -SmtpServer 207.46.163.138 -BodyAsHtml $htmlbody
    }
else {
    Send-MailMessage -From "mgraham@haservices.com" -To mgraham@haservices.com -Subject "Something went wrong w/HA restart script" -SmtpServer 207.46.163.138 -BodyAsHtml $htmlbody
    }