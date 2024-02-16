$vcenter="vcenter-480.campbell.local"
$vm_name="ubuntu"
$new_vm_network="480-WAN"


Connect-VIServer -Server $vcenter
$vm = Get-VM -Name $vm_name
$vmhost=Get-VMHost -Name "192.168.7.14"
$ds = Get-DataStore -Name "datastore1-super4"
$linkedClone = "awx"
$snapshot = Get-Snapshot -VM $vm -Name "base"
$linkedvm = New-VM -LinkedClone -Name $linkedClone -VM $vm -ReferenceSnapshot $snapshot -VMHost $vmhost -Datastore $ds
$linkedvm | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $new_vm_network