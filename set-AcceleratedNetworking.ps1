
<# 

ENABLE / DISABLE ACCELERATED NETWORKING ON A LIST OF VMs

execute this in the Azure Cloud Shell (Powershell) or locally with authentication/context set


.Parameters

MACHINES: provide a list of machines in csv format: "machine1,machine2,machine3,machine4,machine5,machine6,machine8,machine9,machine10" 

SET: ENABLED or DISABLED for accel netw property

#>

param(
$machines = "Winserver1,Winserver2,winserver3", # CHANGE THIS WITH YOUR VM NAMES
[ValidateSet("Enabled","Disabled")]$setn='Enabled'  # SET THIS TO ENABLED OR DISABLED
)

$VMS = $Machines -split ","

if (($VMS -eq $null) -or ($machines -eq $null))
{
    Write-Output "No machines in list. Please pass 'Machines' param value in comma separated list, ie. 'machine1,machine2,machine3,machine4,machine5,machine6,machine8,machine9,machine10'"
    return
}

foreach ($vm in $vms)
{
    $rg = $null
    $nic = $null
    $vmnic = $null
    Write-Output "`nSetting Accelerated Networking on VM $vm..."
    $p = Get-AzVM -Name $vm -ErrorAction SilentlyContinue
    if ($p -eq $null){Write-Output "VM Not Found: $vm";continue}
    $rg = $p.ResourceGroupName
    $nic = ($p.NetworkProfile.NetworkInterfaces.id -split "/")[-1]
    $vmnic = Get-AzNetworkInterface -Name $nic
    if ($setn -eq 'Enabled'){$set1=$true}else{$set1=$false}
    if ($vmnic.EnableAcceleratedNetworking -eq $set1){Write-Output "Accelerated Networking is ALREADY '$setn' on $vm.";continue}
    $vmnic.EnableAcceleratedNetworking = $set1
    $setnic = $vmnic | Set-AzNetworkInterface
    $check = $vmnic = Get-AzNetworkInterface -Name $nic
    Write-Output "Accelerated Networking enabled is '$($check.EnableAcceleratedNetworking)' on $vm."
}

