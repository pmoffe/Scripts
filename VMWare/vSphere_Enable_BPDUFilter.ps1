$Cluster = Read-Host -Prompt 'What vCenter Cluster are you adding VMs to?'
#
$sendTo = "mgraham@haservices.com"
$sendFrom = "mgraham@haservices.com"
$smtpserver = "207.46.163.138"
#
# Import custom VMWare Functions
Import-Module $PSScriptRoot\VMWare_Functions.psm1

# Load VMWare Configuration File
Get-VMWConfig

# Connect to vCenter
Connect-vSphere -viserver $Global:vmwconfig.$cluster
#
# Verify if configuration changes are needed and if so, change the configuration to the value 1
$Body = @()
Get-VMHost | Foreach {
  if (($_ | Get-VMHostAdvancedConfiguration -name net.blockguestbpdu)["Net.BlockGuestBPDU"] -eq 0) {
$Body = $Body + "Net.BlockGuestBPDU value for $($_) is 0 and will be changed. New Configuration for $_ is" | out-string
$newBody = (set-vmhostadvancedconfiguration -vmhost $_ -name Net.BlockGuestBPDU -value 1)
$Body += $newBody | out-string
  } else {
$Body = $Body + "Net.BlockGuestBPDU value for $($_) is correct and does not need to be changed" | out-string
  }
}
#
# Send e-mail report
send-mailmessage -to $sendTo -from $sendFrom -Subject "ESXi host Net.BlockGuestBPDU traffic configuration report" -smtpserver $smtpserver -Body $Body
