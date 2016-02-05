<#
To-Do:
 -Change handling of physical interfaces to allow for different configs (8040 vs 2554) - (NFS, iSCSI, FCP)
 -Dynamically set Aggr for SVM root vol based on free-space on SAS aggrs
 -Better logic for placement of SVM Data LIFs (currently static to node01)
 -Start NFS Service after LIF creation
#>

<#-----------------------------------------
 Have client run the following command to get you info about their existing SVM configuration
 vserver show -vserver [vserver name] -type data -fields ns-switch,nm-switch,language,rootvolume-security-style,allowed-protocols
 vserver services dns show
 network interface show -role intercluster
-----------------------------------------#>

#SVM Configuratino Variables
Write-Host "Loading Configuratino Variables..." -foregroundcolor "green"

#Site ID (Must match sites in config file)
$site_id =	""

#3-letter Client identifier
$cust_id =	""

#VLAN id (Leave blank for FCP-Only SVM)
$cust_vlan_id = ""

#VLAN MTU - Should match client's SVM MTU if replicating (1500 is default)
$cust_vlan_mtu = "1500"

#SVM name. (Script will prepend "$site_id_$cust_id_ to match standard naming)
$cust_svm_name = ""

#SVM allowed protocols in format "cifs,nfs,iscsi,fcp". Leave blank for none
$svm_protos = ""

#Aggregate for SVM root volume
$svm_root_aggr = ""

#Root Volume Security - Data from client
 # If this is a hosted SVM:
 # security will vary based on how you're accessing the volumes
 # unix = NFS, iSCSI, and/or FC/FCoE
 # ntfs = CIFS/SMB
 # mixed = all of the above
$svm_rootvol_sec = "unix"

#SVM Language - Match data from client
 # If this is a hosted SVM C.UTF-8
 # is a good default if unsure
$svm_lang = "C.UTF-8"

#SVM NS Switch - Match data from client
 # Use "file" if unsure
$svm_ns_switch = "file"

#SVM NM Switch - Match data from client
 # Use "file" if unsure
$svm_nm_switch = "file"

#SVM domain name in format "domain.local"
$svm_domain	= ""

#SVM DNS server(s) - Comma separated (should be 1.1.1.1,2.2.2.2 without quotes)
$svm_dns =

#SVM Default IP Gateway (leave blank if not required)
$svm_gw = ""

#SVM Management LIF (Leave IP blank if not required)
$mgmt_lif_ip = ""			    #Data LIF IP in client SVM
$mgmt_lif_netmask = "255.255.255.0"	 		#Data LIF netmask in client SVM - in format "255.255.255.0"
$mgmt_lif_home_port = "e0h-$cust_vlan_id"	#Data LIF home port - Options are: e0g or e0h (default is e0h)

#NFS LIFs (Leave IP blank if not required)
$nfs_lif00_ip = ""		    #Data LIF IP in client SVM
$nfs_lif00_netmask = "255.255.255.0"	 		#Data LIF netmask in client SVM - in format "255.255.255.0"
$nfs_lif01_ip = ""		    #Data LIF IP in client SVM
$nfs_lif01_netmask = "255.255.255.0"	 		#Data LIF netmask in client SVM - in format "255.255.255.0"
$nfs_lif_home_port = "e0h-$cust_vlan_id"	#Data LIF home port - Options are: e0g or e0h (default is e0h)

#CIFS LIFs (Leave IP blank if not required)
$cifs_lif_ip = ""		    #Data LIF IP in client SVM
$cifs_lif_netmask = "255.255.255.0"	 		#Data LIF netmask in client SVM - in format "255.255.255.0"
$cifs_lif_home_port = "e0h-$cust_vlan_id"	#Data LIF home port - Options are: e0g or e0h (default is e0h)
$cifs_joindomainas = ""						#Hostname to join the windows domain as. Must be less than 15 characters

#Intercluster LIFs (Leave IPs blank if not required)
$ic_lif_home_port = "e0g-$cust_vlan_id"	#Intercluster LIF on node00 home port - Options are: e0g or e0h (default is e0g)
$ic_lif00_ip = ""			#Intercluster LIF on node00 IP
$ic_lif00_netmask = "255.255.255.0"		#Intercluster LIF on node00 netmask in format "255.255.255.0"
$ic_lif01_ip = ""			#Intercluster LIF on node01 IP
$ic_lif01_netmask = "255.255.255.0"		#Intercluster LIF on node01 netmask in format "255.255.255.0"
$ic_lif_gw = ""               #Intercluster LIF Default Gateway in format "1.2.3.4"

#Cluster and vServer Peering (Leave blank if not required)
$client_icip = ""	    #Data from client - client's cDOT cluster intercluster IP (a single IC IP will work)
$client_svm_name = ""	#Data from client - client's SVM name
$client_clus_name = ""  #Data from client - client's cluster name
$client_passphrase = "" #Shared Password

#-------------------------------------------#
# No configurable variables past this point #
#-------------------------------------------#

# Import custom NetApp Functions
Import-Module $PSScriptRoot\NetApp_Functions.psm1

# Load NetApp Config
Get-NAConfig

# Connect to NetApp
Connect-NAFiler -nafiler $Global:naconfig.$site_id

# Set internal variables
Write-Host "Loading Internal Variables..." -foregroundcolor "green"
$svm_name = "$site_id-$cust_id" + "-$cust_svm_name"
$svm_root_vol = $svm_name + "_root" -replace "-", "_"
$ClusterNodes = get-ncClusterNode
$ClusterNode0 = get-ncclusternode | where-object {$_.NodeName -like "*c00n00"} | Select-Object NodeName
$ClusterNode1 = get-ncclusternode | where-object {$_.NodeName -like "*c00n01"} | Select-Object NodeName

#Create VLAN
$check_vlan = Get-NcNetPortVlan | Where-Object {$_.InterfaceName -match $cust_vlan_id}
if(-Not $check_vlan -and $cust_vlan_id ){
ForEach ($Node in $ClusterNodes){
	Write-Host "Creating VLANs on $Node..." -foregroundcolor "green"
	New-NcNetPortVlan -ParentInterface e0g -Node $Node.NodeName -VlanId $cust_vlan_id -ErrorAction Stop
	New-NcNetPortVlan -ParentInterface e0h -Node $Node.NodeName -VlanId $cust_vlan_id -ErrorAction Stop
	}
}
else {Write-Host "VLAN already exists or VLAN variable empty, moving on..." -foregroundcolor "Red" }

#Create IPSpace
$check_ipspace = Get-NcNetIpspace | Where-Object {$_.Ipspace -match "$site_id-$cust_id-00"}
if(-Not $check_ipspace ) {
	Write-Host "Creating IPSpace..." -foregroundcolor "green"
	New-NcNetIpspace "$site_id-$cust_id-00" -ErrorAction Stop
}
else {Write-Host "IPSpace already exists, moving on..." -foregroundcolor "Red" }

#Create Broadcast Domain
$check_broadcastdomain = Get-NcNetPortBroadcastDomain | Where-Object {$_.BroadcastDomain -match "$site_id-$cust_id-$cust_vlan_id"}
if(-Not $check_broadcastdomain -and $cust_vlan_id ) {
	Write-Host "Creating Broadcast Domain..." -foregroundcolor "green"
	New-NcNetPortBroadcastDomain -Name "$site_id-$cust_id-$cust_vlan_id" -Ipspace "$site_id-$cust_id-00" -Mtu $cust_vlan_mtu

#Add ports to Broadcast Domain
	Write-Host "Adding VLANs to Broadcast Domain..." -foregroundcolor "Green"
	ForEach ($Node in $ClusterNodes) {
	$node_port0 = $Node.NodeName + ":e0g-" + $cust_vlan_id
	$node_port1 = $Node.NodeName + ":e0h-" + $cust_vlan_id
	Set-NcNetPortBroadcastDomain -Name "$site_id-$cust_id-$cust_vlan_id" -Ipspace "$site_id-$cust_id-00" -AddPort $node_port0
	Set-NcNetPortBroadcastDomain -Name "$site_id-$cust_id-$cust_vlan_id" -Ipspace "$site_id-$cust_id-00" -AddPort $node_port1
	}
}
else {Write-Host "Broadcast Domain already exists (so assuming VLANs are already members) or VLAN variable empty, moving on..." -foregroundcolor "Red" }

#Create new vserver
$check_svm = Get-NcVserver | Where-Object {$_.VserverName -match $svm_name}
if(-Not $check_svm) {
	Write-Host "Creating new SVM..." -foregroundcolor "green"
	New-NcVserver -name $svm_name -RootVolume $svm_root_vol  -RootVolumeAggregate $svm_root_aggr -NameServerSwitch $svm_ns_switch -RootVolumeSecurityStyle $svm_rootvol_sec -NameMappingSwitch $svm_nm_switch -Language $svm_lang -Ipspace "$site_id-$cust_id-00"
	Write-Host "Setting allowed-protocols..." -foregroundcolor "Green"
	Set-NcVserver $svm_name -AllowedProtocols $svm_protos
    if ($svm_domain -and $svm_dns) {
		Write-Host "Setting-up DNS..." -foregroundcolor "Green"
		New-NcNetDns -VserverContext $svm_name -Domains $svm_domain -NameServers $svm_dns }
	else {Write-Host "DNS and/or Domain Variable not set, moving on..." -foregroundcolor "Red" }
}
else {Write-Host "SVM name already exists, moving on..." -foregroundcolor "Red" }

#Create FCP DATA LIFs
$check_fcplif = Get-NcNetInterface | where-object {$_.InterfaceName -like "$site_id-$cust_id-FC-*"}
if (-Not $check_fcplif -and $svm_protos -eq "fcp") {
	Write-Host "Creating new FCP LIF Interfaces..." -foregroundcolor "green"
	New-NcNetInterface -Name "$site_id-$cust_id-FC-00-0e" -Vserver $svm_name -Role data -DataProtocols fcp -Node $ClusterNode0.NodeName -Port "0e"
	New-NcNetInterface -Name "$site_id-$cust_id-FC-00-0f" -Vserver $svm_name -Role data -DataProtocols fcp -Node $ClusterNode0.NodeName -Port "0f"
	New-NcNetInterface -Name "$site_id-$cust_id-FC-01-0e" -Vserver $svm_name -Role data -DataProtocols fcp -Node $ClusterNode1.NodeName -Port "0e"
	New-NcNetInterface -Name "$site_id-$cust_id-FC-01-0f" -Vserver $svm_name -Role data -DataProtocols fcp -Node $ClusterNode1.NodeName -Port "0f"
	Write-Host "Starting FCP server..." -foregroundcolor "green"
	Get-NcVserver $svm_name | Add-NcFcpService
}
else {Write-Host "At least one FCP LIF already exists or FCP not defined in the svm_protos variable, moving on..." -foregroundcolor "Red" }

#Create MGMT DATA LIF IP
$check_datalif = Get-NcNetInterface | where-object {$_.InterfaceName -like "$site_id-$cust_id-MGMT-*"}
if(-Not $check_datalif -and $mgmt_lif_ip ) {
	Write-Host "Creating new MGMT LIF Interface..." -foregroundcolor "green"
	New-NcNetInterface -Name "$site_id-$cust_id-MGMT-00" -Vserver $svm_name -FailoverGroup "$site_id-$cust_id-$cust_vlan_id" -Role data -Node $ClusterNode0.NodeName -Port $mgmt_lif_home_port -Address $mgmt_lif_ip -Netmask $mgmt_lif_netmask -DataProtocols none -AutoRevert 1
}
else {Write-Host "At least one MGMT LIF already exists or MGMT LIF IP variable not defined, moving on..." -foregroundcolor "Red" }

#Create NFS-00 DATA LIFs
$check_nfslif0 = Get-NcNetInterface | where-object {$_.InterfaceName -like "$site_id-$cust_id-NFS-00"}
if(-Not $check_nfslif0 -and $nfs_lif00_ip ) {
	Write-Host "Creating new InterCluster LIF Interface on Node0..." -foregroundcolor "green"
	New-NcNetInterface -Name "$site_id-$cust_id-NFS-00" -Vserver $svm_name -FailoverGroup "$site_id-$cust_id-$cust_vlan_id" -Role data -Node $ClusterNode0.NodeName -Port $nfs_lif_home_port -Address $nfs_lif00_ip -Netmask $cifs_lif_netmask -DataProtocols nfs -AutoRevert 1
}
else {Write-Host "At least one NFS-00 LIF already exists or NFS LIF-00 IP variable not defined, moving on..." -foregroundcolor "Red" }

#Create NFS-01 DATA LIFs
$check_nfslif1 = Get-NcNetInterface | where-object {$_.InterfaceName -like "$site_id-$cust_id-NFS-01"}
if(-Not $check_nfslif1 -and $nfs_lif01_ip ) {
	Write-Host "Creating new InterCluster LIF Interface on Node1..." -foregroundcolor "green"
	New-NcNetInterface -Name "$site_id-$cust_id-NFS-01" -Vserver $svm_name -FailoverGroup "$site_id-$cust_id-$cust_vlan_id" -Role data -Node $ClusterNode1.NodeName -Port $nfs_lif_home_port -Address $nfs_lif01_ip -Netmask $cifs_lif_netmask -DataProtocols nfs -AutoRevert 1
}
else {Write-Host "At least one NFS-01 LIF already exists or NFS LIF-01 IP variable not defined, moving on..." -foregroundcolor "Red" }

#Create CIFS DATA LIF
$check_datalif = Get-NcNetInterface | where-object {$_.InterfaceName -like "$site_id-$cust_id-CIFS-*"}
if(-Not $check_datalif -and $cifs_lif_ip ) {
	Write-Host "Creating new InterCluster LIF Interfaces..." -foregroundcolor "green"
	New-NcNetInterface -Name "$site_id-$cust_id-CIFS-00" -Vserver $svm_name -FailoverGroup "$site_id-$cust_id-$cust_vlan_id" -Role data -Node $ClusterNode1.NodeName -Port $cifs_lif_home_port -Address $cifs_lif_ip -Netmask $cifs_lif_netmask -DataProtocols cifs -AutoRevert 1
	Write-Host "Adding SVM to $svm_domain domain..." -foregroundcolor "green"
	Add-NcCifsServer -Name $cifs_joindomainas -VserverContext $svm_name -Domain $svm_domain -AdminCredential (Get-Credential)
	Write-Host "Starting CIFS server..." -foregroundcolor "green"
	Get-NcVserver $svm_name | Start-NcCifsServer
}
else {Write-Host "At least one CIFS LIF already exists or CIFS LIF IP variable not defined, moving on..." -foregroundcolor "Red" }

#Create InterCluster LIF IPs
$check_intercluster = Get-NcNetInterface | Where-Object {$_.InterfaceName -like "$site_id-$cust_id-IC-*"}
if(-Not $check_intercluster -and ($ic_lif00_ip -and $ic_lif01_ip ) ) {
	Write-Host "Creating new InterCluster LIF Interfaces..." -foregroundcolor "green"
	New-NcNetInterface -Name "$site_id-$cust_id-IC-00" -Vserver "$site_id-$cust_id-00" -FailoverGroup "$site_id-$cust_id-$cust_vlan_id" -Role intercluster -Node $ClusterNode0.NodeName -Port $ic_lif_home_port -Address $ic_lif00_ip -Netmask $ic_lif00_netmask -AutoRevert 1
	New-NcNetInterface -Name "$site_id-$cust_id-IC-01" -Vserver "$site_id-$cust_id-00" -FailoverGroup "$site_id-$cust_id-$cust_vlan_id" -Role intercluster -Node $ClusterNode1.NodeName -Port $ic_lif_home_port -Address $ic_lif01_ip -Netmask $ic_lif01_netmask -AutoRevert 1
    $check_lifgw = get-ncnetroute | where-object {$_.Vserver -like $svm_name}
    if(-Not $check_lifgw -and $ic_lif_gw){
        Write-Host "Setting IPSpace Default Gateway..." -ForegroundColor "green"
        New-NcNetRoute -destination 0.0.0.0/0 -gateway $ic_lif_gw -vservercontext "$site_id-$cust_id-00"
    }
    else {Write-Host "InterCluster LIF Gateway already set or variable not defined, moving on..." -ForegroundColor "Red"}
}
else {Write-Host "At least one InterCluster LIF already exists or LIF IP variables not defined, moving on..." -foregroundcolor "Red" }

#Set Default Route
$check_svmgw = get-ncnetroute | where-object {$_.Vserver -like $svm_name}
if(-Not $check_svmgw -and $svm_gw) {
	Write-Host "Setting SVM Default Gateway..." -foregroundcolor "green"
	New-NcNetRoute -destination 0.0.0.0/0 -gateway $svm_gw -vservercontext $svm_name
}
else {Write-Host "Default gateway already set or variable not defined, moving on..." -foregroundcolor "Red" }

#Set-up Cluster and vServer Peering
if(($client_icip -and $client_passphrase) -or ($client_svm_name -and $client_clus_name)) {

    $check_clusterpeer = Get-NcClusterPeer | Where-Object {$_.ClusterName -like $client_clus_name}
    if( -Not $check_clusterpeer -and $client_passphrase -and $client_icip){
        Write-Host "Creating Cluster Peer Relatinoship..." -ForegroundColor "Green"
        Add-NcClusterPeer -Address $client_icip -Passphrase $client_passphrase -IpspaceName "$site_id-$cust_id-00"
    }
    else {Write-Host "Cluster peer already exists or client Cluster name or LIF IP variables missing. Moving on..." -ForegroundColor "Red" }

    $check_vserverpeer = Get-NcVserverPeer | Where-Object {$_.PeerVserver -like $client_svm_name}
    if( -Not $check_vserverpeer -and $svm_name -and $client_clus_name -and $client_svm_name) {
        Write-Host "Creating vServer Peer Relationship..." -ForegroundColor "Green"
        New-NcVserverPeer -vserver $svm_name -PeerVserver $client_svm_name -Application snapmirror -PeerCluster $client_clus_name
    }
    else {Write-Host "vServer peer already exists or client vserver/cluster variables not set.  Moving on..." -ForegroundColor "Red" }
}
else {Write-Host "No client cluster, vserver or IC LIF variables set, moving on..." -foregroundcolor "Red" }

Write-Host "Done." -foregroundcolor "Magenta"
