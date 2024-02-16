$vcenter="vcenter-480.campbell.local"
$vm_name="ubuntu"
$new_vm_name="server.ubuntu.base"

Connect-VIServer -Server $vcenter
$vm = Get-VM -Name $vm_name
$snapshot = Get-Snapshot -VM $vm -Name "base"
$vmhost=Get-VMHost -Name "192.168.7.14"
$ds = Get-DataStore -Name "datastore1-super4"
$linkedClone = "{0}.linked" -f $vm.name
$linkedvm = New-VM -LinkedClone -Name $linkedClone -VM $vm -ReferenceSnapshot $snapshot -VMHost $vmhost -Datastore $ds
$newvm = New-VM -Name $new_vm_name -VM $linkedvm -VMHost $vmhost -Datastore $ds
$newvm | New-Snapshot -Name "Base"
$linkedvm | Remove-VM