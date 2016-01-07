# Load Config File
    #File with the stored data
        $ConfigFile = ".\NetApp.config"
    #Creating an empty hash table
		$Config = @{}
    #Pulling, separating, and storing the values in $Config
        Get-Content $ConfigFile | Where-Object { $_ -notmatch '^#.*' } | ForEach-Object {
            $Keys = $_ -split "="
            $Config += @{$Keys[0]=$Keys[1]}
        }

#Load the DataONTAP Module
Import-Module DataONTAP

#Set connection parameters
$password = ConvertTo-SecureString $config.narootpasswd -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "root",$password

# Pull the data
$filers = $config.sm7mfilers -split ","
$notifyto = $config.notifyto -split ","

$smstatus = ForEach ($filer in $filers) {
    #Connect to NetApp as root
    Connect-NaController $filer -Credential $cred | Out-Null

    #Get list of vfilers
    $vfilers = Get-NaVfiler

        #For each vFiler, print snapmirrors with LagTime > 1.25 days.
        ForEach ($vfiler in $vfilers) {
		    Connect-NaController $filer -vfiler "$vfiler" | Out-Null
		    Get-NaSnapmirror -WarningAction SilentlyContinue | Select DestinationLocation,SourceLocation,LagTime,LagTimeTS | Where-Object {$_.LagTime -gt $config.smlag} | Select DestinationLocation,SourceLocation,LagTimeTS
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
    
    Send-MailMessage -From $config.notifyfrom -To $notifyto -Subject "7Mode SnapMirror Issues Found!" -SmtpServer $config.smtpserver -BodyAsHtml $body
    }
else {
    Send-MailMessage -From $config.notifyfrom -To $notifyto -Subject "NO 7Mode SnapMirror Issues Found!" -SmtpServer $config.smtpserver
    }

##end
