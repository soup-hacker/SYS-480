function 480Banner(){
    Write-Host "                                        
           (         )             )     (      
        ( /(  )\ (   ( /(      (   ( /( (   )\     
        )\())((_))\  )\())     )\  )\()))\ ((_)(   
       ((_)\   _((_)((_)\   _ ((_)(_))/((_) _  )\  
      | | (_) ( _ ) /  (_) | | | || |_  (_)| |((_) 
      |_  _|  / _ \| () |  | |_| ||  _| | || |(_-< 
        |_|   \___/ \__/    \___/  \__| |_||_|/__/ 

    "
}

function 480Connect([string]$server){
    $conn = $Global:DefaultVIServer
    if($conn){
        $msg = "Already connected to {0}" -f $conn
        Write-Host -ForegroundColor Green $msg
    }else{
        $conn = Connect-VIServer -Server $server
    }

}

function Get-480Config([string] $config_path){
    Write-Host "Reading " $config_path
    $conf=$null
    if(Test-Path $config_path){
        $conf = (Get-Content -Raw -Path $config_path | ConvertFrom-Json)
        $msg = "Using configuration at {0}" -f $config_path
        Write-Host -ForegroundColor Green $msg
    }else{
        Write-Host -ForegroundColor Yellow "No Configuration"
    }
    return $conf

}

function Select-VM([string] $folder){
    $selected_vm=$null
    try {
        $vms = Get-VM -Location "$folder"
        $index = 1
        foreach($vm in $vms){
            Write-Host [$index] $vm.Name
            $index+=1
        }
        $pick_index = Read-Host "Which index number [x] do you wish to pick?"
        $selected_vm = $vms[$pick_index -1]
        Write-Host "You picked " $selected_vm.name
        return $selected_vm
    } catch {
        Write-Host "Invalid folder: $folder" -ForegroundColor Red
    }
}

function Menu($config){
    Clear-Host
    480Banner
    Write-Host "
    [1] Full Clone
    [2] Linked Clone
    [3] Toggle Power
    [4] Change Network Adapter for VM
    [5] Create New Virtual Switch of Virtual Port Group 
    [6] Get VM Network Info
    [7] Exit
    "
    $choice = Read-Host "Enter the option"

    switch($choice){
        '1' {
            # FULL CLONE
            Clear-Host
            FullClone($config)
        }
        '2' {
            # LINKED CLONE
            Clear-Host
            LinkedClone($config)
        }
        '3' {
            # TOGGLE POWER
            Clear-Host
            TogglePower($config)
        }
        '4' {
            # CHANGE NETWORK ON ADAPTER
            Clear-Host
            NetworkChange($config)
        }
        '5'{
            # CREATE VIRTUAL SWTICH OR PORT GROUP
            Clear-Host
            NewNetwork($config)
        }
        '6'{
            # GET VM NETWORKING INFO
            Clear-Host
            GetNetwork($config)
        }
        '7'{
            $conn = $global:DefaultVIServer
            # disconnect if already connected
            if ($conn){
                Disconnect-VIServer -server * -Force -Confirm:$false
            }
            Exit

        }
        Default {
            Write-Host -ForegroundColor "Red" "NOT VALID CHOICE" 
            break
        }
    }
}

function FullClone($config){
    $folder = $config.vm_folder
    $vm = Select-VM -folder $folder
    $vmname = Read-Host "Enter new VM name: "
    #$link = $false

    foreach ($realvm in Get-VM){
        if (“{0}.linked” -f $vm.name -eq $realvm.name){
            Write-Host "Link is already created"
            #$link = $true
            $linkedvmName = “{0}.linked” -f $vm.name
            $linkedvm = Get-VM -Name $linkedvmName
            break
        }else{
            $linkedClone = “{0}.linked” -f $vm.name 
            # To create new linked clone
            $linkedvm = New-VM -LinkedClone -Name $linkedClone -VM $vm -ReferenceSnapshot $config.snapshot -VMHost $config.esxi_host -Datastore $config.default_datastore
            break
        }
    }
    # Create full clone
    Write-Host "Creating full clone ..."
    $newvm = New-VM -Name $vmname -VM $linkedvm -VMHost $config.esxi_host -Datastore $config.default_datastore

    # Take snapshot of new clone
    Write-Host "Creating base snapshot ..."
    $newvm | New-Snapshot -Name $config.snapshot

    # Remove the old link
    if (!$iflinked){
        $linkedvm | Remove-VM -DeletePermanently -Confirm:$false
    }

    Start-Sleep -Seconds 5

    Menu($config)
}

function LinkedClone($config){
    $folder = $config.vm_folder
    $vm = Select-VM -folder $folder
    $vmname = Read-Host "Enter new linked clone name VM name: "
    Write-Host "Creating linked clone ..."

    New-VM -LinkedClone -Name $vmname -VM $vm -ReferenceSnapshot $config.snapshot -VMHost $config.esxi_host -Datastore $config.default_datastore
    Start-Sleep -Seconds 5
    Menu($config)
}

function TogglePower($config){
    Write-Host "Selecting your VM" -ForegroundColor "Blue"
    $selected_vm=$null
    $vms = Get-VM
    $index = 1
    foreach($vm in $vms){
        Write-Host [$index] $vm.Name
        $index+=1
    }
    $index_choice = Read-Host "Please choose an index: "
    try {
        $selected_vm = $vms[$index_choice -1]
        Write-Host "You picked " $selected_vm.Name -ForegroundColor "Green"
    }
    catch [Exception]{
        $msg = 'Invalid format please select [1-{0}]' -f $index-1
        Write-Host -ForgroundColor "Red" $msg
    }
    $power_state = Read-Host "Would you like to turn that VM 'on' or 'off'?"
    
    if($power_state -like 'on'){
        Start-VM -VM $selected_vm -Confirm:$true -RunAsync
    }elseif ($power_state -like 'off') {
        Stop-VM -VM $selected_vm -Confirm:$true
    }
   
    Menu($config)
}

function NewNetwork($config){

    Write-Host "
    Please select which operation you would like to do.

    [1] Only Create Virtual Switch
    [2] Only Create Virtual Port Group
    [3] Assign Existing Virtual Port Group to Virtual Switch
    "
    $selection = Read-Host "Which index number [x] do you wish?"
    
    switch($selection){
        '1'{
            NewSwitch($config)
        }
        '2'{
            NewPortGroup($config)
        }
        '3'{
            NewSwitch($config)
            NewPortGroup($config)
        }
        
    }
    Read-Host "Press Enter to Continue"
    Menu($config)
}

function NewSwitch($config){
    $switchName = Read-Host "Name for new switch: "
    $found = $null
    foreach($switch in Get-VirtualSwitch){
        if ($switchName -eq $switch.Name){
            $found = $true
            break
        }
    }
    if ($found){
        Write-Host -ForegroundColor "Red" "This switch already exists!"
    }else {
        New-VirtualSwitch -VMHost $config.esxi_host -Name $switchName
    }
}

function NewPortGroup ($config){
    $portGroupName = Read-Host "New port group name: "
    $found = $null
    foreach($group in Get-VirtualPortGroup){
        if ($portGroupName -eq $group.Name){
            $found = $true
            break
        }
    }
    if($found){
        Write-Host -ForegroundColor "Red" "This group already exists!"
    }else{
        $selected_switch = $null
        $switch = Get-VirtualSwitch
        $index = 1
        foreach($switch in $switches){
            Write-Host [$index] $switch.Name
            $index+=1
        }
        $pick_index = Read-Host "Which index number [x] do you wish?"
        try {
            $selected_switch = $vms[$pick_index -1]
            Write-Host "You picked " $selected_switch.Name -ForegroundColor "Green"
        }
        catch [Exception]{
            $msg = 'Invalid format please select [1-{0}]' -f $index-1
            Write-Host -ForgroundColor "Red" $msg
        }
        New-VirtualPortGroup -VirtualSwitch $selected_switch -Name $portGroupName
    }
}

function GetNetwork($config){
    Write-Host "Select from the VMs below to get netwokring information: "
    $selected_vm=$null
    $vms = Get-VM -Location $folder
    $index = 1

    foreach($vm in $vms){
        Write-Host [$index] $vm.Name
        $index+=1

    }
    Write-Host "Which VM? "
    try {
        $selected_vm = $vms[$pick_index - 1]
        Write-Host "Selected: " $selected_vm.Name -ForegroundColor "Green"
    }
    catch [Exception]{
        $msg = 'Invalid format please select [1-{0}]' -f $index-1
        Write-Host -ForgroundColor "Red" $msg
    }
    
    $IpAddress = Get-VM $selected_vm | Select-Object @{N="IP Address";E={@($_.Guest.IPAddress[0])}} | Select-Object -ExpandProperty "IP Address"
    $Mac = Get-VM $selected_vm | Get-NetworkAdapter -Name "Network adapter 1" | Select-Object -ExpandProperty MacAddress

    $msg = "{0} hostname={1} mac={2}" -f $IpAddress,$selected_vm,$Mac

    Write-Host $msg
    
    Read-Host "Press Enter to Continue"
    Menu($config)
}

function NetworkChange($config){
    $selected_vm=$null
    $vms = Get-VM -Location $folder
    $index = 1
    foreach($vm in $vms){
         Write-Host [$index] $vm.Name
        $index+=1
        }
    $pick_index = Read-Host "Which index number [x] do you wish?"
    try {
        $selected_vm = $vms[$pick_index -1]
        Write-Host "You picked " $selected_vm.Name -ForegroundColor "Green"
    }
    catch [Exception]{
        $msg = 'Invalid format please select [1-{0}]' -f $index-1
        Write-Host -ForgroundColor "Red" $msg
    }
    Get-VirtualNetwork
    $network = Read-Host "Select network: "
    Get-NetworkAdapter -VM $selected_vm | Select-Object Name -ExpandProperty Name
    $adapter_select = Read-Host "Select adapter: "

    Get-VM $selected_vm | Get-NetworkAdapter -Name $adapter_select | Set-NetworkAdapter -NetworkName $network -Confirm:$false

    Read-Host "Press Enter to Continue"
    Menu($config)
}