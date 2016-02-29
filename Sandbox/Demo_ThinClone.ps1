# Connect to vCenter:
Connect-VIServer vcenter.subdomain.domain.local

#Define the virtual machine which is the origin of the linked clone, and the Snapshotname on which the linked clone based.
$sOriginVM="mastervm"
$sOriginVMSnapshotName="mastervm_linkedclone_snap"

# Name of the new virtual machine
$sNewVMName="linkedclonevm"

#In which logical vSphere folder should the vm placed. In this example the same folder as origin VM.
$oVCenterFolder=(Get-VM $sOriginVM).Folder

#Create a snapshot of the source VM
$oSnapShot=New-Snapshot -VM $sOriginVM -Name $sOriginVMSnapshotName -Description "Snapshot for linked clones" -Memory -Quiesce

#Define the datastore where the linked clone will be stored
$oESXDatastore=Get-Datastore -Name "esxdatastore1"

#Create the linked clone. For Windows system also Customisation makes sence(New SID, New Computername) these parameters are the same like a “normal” clone.
$oLinkedClone=New-VM -Name $sNewVMName -VM $sOriginVM -Location $oVCenterFolder  -Datastore $oESXDatastore -ResourcePool Resources -LinkedClone -ReferenceSnapshot $oSnapShot

#Thats it. Start the VM
Start-VM $oLinkedClone

#Make some things in the VM and stop it
Stop-VM $oLinkedClone -Confirm:$false

#Delete the linked clone and remove the snapshot at the origin VM
Remove-VM -DeletePermanently $oLinkedClone -Confirm:$false
Remove-Snapshot -Snapshot $oSnapShot -Confirm:$false
