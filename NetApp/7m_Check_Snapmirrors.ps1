# Import custom NetApp Functions
Import-Module $PSScriptRoot\NetApp_Functions.psm1

# Load NetApp Config
Get-NAConfig

#Set connection parameters (use root password in config file to prevent password prompt for each filer)
$password = ConvertTo-SecureString $Global:naconfig.narootpasswd -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "root",$password

# Load the configuration data
$filers = $Global:naconfig.sm7mfilers -split ","
$notifyto = $Global:naconfig.notifyto -split ","

# Check SnapMirror Status
$smstatus = ForEach ($filer in $filers) {

    #Connect to NetApp as root
    Connect-NaController $filer -Credential $cred | Out-Null

    #Get list of vfilers
    $vfilers = Get-NaVfiler

        #For each vFiler, print snapmirrors with LagTime > 1.25 days.
        ForEach ($vfiler in $vfilers) {
		    Connect-NaController $filer -vfiler "$vfiler" | Out-Null
		    Get-NaSnapmirror -WarningAction SilentlyContinue | Select-Object DestinationLocation,SourceLocation,LagTime,LagTimeTS | Where-Object {$_.LagTime -gt $Global:naconfig.smlag} | Select-Object DestinationLocation,SourceLocation,LagTimeTS
		    }
}

#Send email report
if ($smstatus) {
	$style = "<style type='text/css'>"
	$style = $style + "BODY{background-color:#FFFFFF;font-family:Verdana;}"
	$style = $style + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;font-size:12px;}"
	$style = $style + "TH{border-width: 1px;text-align: center;padding: 2px;border-style: solid;border-color: black;background-color:#D3D3D3 }"
	$style = $style + "TD{border-width: 1px;text-align: center;padding: 2px;border-style: solid;border-color: black;background-color:#FFFFFF }"
	$style = $style + "</style>"

    $body = $smstatus | ConvertTo-Html -Head $style | Out-String

    Send-MailMessage -From $Global:naconfig.notifyfrom -To $notifyto -Subject "7Mode SnapMirror Issues Found!" -SmtpServer $Global:naconfig.smtpserver -BodyAsHtml $body
    }
else {
    Send-MailMessage -From $Global:naconfig.notifyfrom -To $notifyto -Subject "NO 7Mode SnapMirror Issues Found!" -SmtpServer $Global:naconfig.smtpserver
    }
