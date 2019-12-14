<#

 AZURE VM GUEST AGENT OFFLINE INSTALLATION/REPAIR SCRIPT FOR WINDOWS SERVER 20xx
 POC


 2019 AZURE CSS
 Authored by jasims@microsoft.com
 v1.0 11/20/2019
 v1.01 11/25/2019 - added checks for rescue vm disk mount failure





 .SYNOPSIS
     This script automates the steps to install the VM Guest agent by offline disk swap method:
     1. Stop the affected VM.
     2. create a snapshot of the disk
     3. create a disk of the snapshot
     4. spin up a small rescue VM from the marketplace
     5. attach the disk to the new VM as a data disk
     7. copy agent binaries and import needed registry keys
     8. detach the data disk
     9. swap OS disk with affected VM
     10. start affected VM



 TODO:
 current version limitations:
 does not support classic VMs yet? needs test
 does not support unmanaged disks 
 does not support encrypted OS disks 
 need to verify functionality on each windows OS

#> 

param
(
[Parameter(Mandatory=$false)][string]$SubscriptionID = '6abccfbc-2d9a-4721-925d-3d231fe91340', #testing
[Parameter(Mandatory=$false)][string]$ResourceGroupName = 'RG1', #testing
[Parameter(Mandatory=$false)][string]$VMName = 'Win2016NoAgent', #testing 
[string]$RescueVMSku = 'Standard_D2_v3' # the rescue VM sku
)


Function Cleanup
{
## Cleanup
Write-Output "Cleaning up..."


# delete rescue VM
Write-Output "Stopping Rescue VM..."
Stop-AzVM -Name $RescueVMName -ResourceGroupName $ResourceGroupName -Force
Write-Output "Deleting Rescue VM..."
Remove-AzVM -Name $RescueVMName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Continue
# delete rescue vm OS disk
Write-Output "Deleting Rescue VM OS Disk..."
Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $($Therescuevm.StorageProfile.OsDisk.name) -Force -ErrorAction Continue
# delete rescue vm nic
Write-Output "Deleting Rescue VM NIC..."
Remove-AzNetworkInterface -Name $rescuevmnicname -ResourceGroupName $ResourceGroupName -Force -ErrorAction Continue
sleep 15
# delete rescue vm pip
Write-Output "Deleting Rescue VM Public IP Address..."
Remove-AzPublicIpAddress -Name $rescuevmpipname -ResourceGroupName $ResourceGroupName -Force -ErrorAction Continue


Write-Output "`nIf no longer needed, please manually delete:"
Write-Output "Affected disk snapshot '$newsnapshotname'"
write-output "Affected disk '$vmOSdiskname'"
}


# set subscription context
$ctx = Set-AzContext -Subscription $SubscriptionID  -ErrorAction SilentlyContinue
if ($ctx -eq $null)
{
    Write-Output "Please Log in to AZ and Classic context first."
    Add-AzAccount
    exit
}


# get VM details
$vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if ($vm -eq $null)
{
    Write-Output "Unable to find VM. Please verify VM is in the selected Subscription/ResourceGroup."
    exit
}
$vmlocation = $vm.Location

# verify that the desired rescue VM size is available in this location.
$vmsizes = Get-AzVMSize -Location $vmlocation
$skufound = $false
foreach ($vmsize in $vmsizes)
{
    if ($($vmsize.Name) -like $RescueVMSku)
    {
        Write-Output "VM Size '$RescueVMSku' is available in '$vmlocation'"
        $skufound = $true
        break
    }
}
if ($skufound -eq $false)
{
    Write-Output "VM Size $RescueVMSku' is not available in location '$vmlocation'. Please specify a different Size with the 'RescueVMSku' parameter."
    exit
}

$vmvnets = Get-AzVirtualNetwork

foreach ($vnet in $vmvnets)
{
    if($vnet.Subnets.Ipconfigurations.Id -ne $null)
    {
        #$vnet.Subnets.IpConfigurations.Id
        if ($vnet.Subnets.IpConfigurations.Id -like "$($vm.NetworkProfile.NetworkInterfaces.Id)*")
        {
            $vmvnet = $vnet
            break
        }
    }

}
#$vmvnet.Name
#$vmvnet.Subnets.id

Write-Output "Selecting target VM '$VMName'..."

# 0.1 - check if disk is encrypted - if it is, exit (not supported at this time)
$diskenc = (Get-AzVMDiskEncryptionStatus -ResourceGroupName $resourceGroupName -VMName $VMName).osvolumeencrypted
if ($diskenc -eq $null)
{
    Write-Output "Unable to get VM OS Disk encryption status! Exiting..."
    exit
}
else
{
    if ($diskenc -notlike 'NotEncrypted')
    {
        Write-Output "Disk is Encrypted. Currently this script doesn't support Encrypted OS Drives."
        exit
    }
    else
    {
        Write-Output "OS Disk is not encrypted.  Proceeding..."
    }
}

# 1. stop vm

$VMstate = $(get-azvm -Name $VMName -Status).powerstate
if ($VMstate -notlike "Vm deallocated")
{
    Write-Output "Stopping VM '$VMName' ..."
    $stopvm = Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
    if ($stopvm.Status -ne "Succeeded")
    {
        Write-Output "Unable to Stop VM. Please try to stop manually from Azure Portal and try again."
        exit
    }
    Write-Output "VM stopped."
}
else
{
    Write-Output "VM already in stopped state."
}

#2 make disk snapshot

$vmOSdisk = $vm.StorageProfile.OsDisk.ManagedDisk.Id
$vmOSdiskname = $vmOSdisk.Split('/')[-1]
if ($vmOSdisk -eq $null)
{
    Write-Output "Unable to get OS disk details!"
    exit
}

$snapshotconfig = New-AzSnapshotConfig -SourceUri $vmOSdisk -Location $vmlocation -AccountType Standard_LRS -OsType Windows -CreateOption copy
$ran = (New-Guid).Guid
$newsnapshotname = "$VMName-BackupSnapshot-$ran"

$newsnap = New-AzSnapshot -Snapshot $snapshotconfig -SnapshotName $newsnapshotname -ResourceGroupName $ResourceGroupName -ErrorAction Stop
if ($newsnap -eq $null)
{
    Write-Output "Unable to Create snapshot!"
    exit
}
else
{
    Write-Output "Created OS Disk Snapshot:"
    $newsnap.Name
}


#create disk from snapshot

$newdiskconfig = New-AzDiskConfig -Location $vmlocation -DiskSizeGB $newsnap.DiskSizeGB  -SkuName Standard_LRS -CreateOption Copy -SourceResourceId $newsnap.Id -ErrorAction Stop
$diskcopy = New-AzDisk -ResourceGroupName $ResourceGroupName -DiskName "$newsnapshotname-copy" -Disk $newdiskconfig

if ($diskcopy -eq $null)
{
    Write-Output "Unable to create new disk!"
    exit
}
Write-Output "Disk created:"
$diskcopy.Name 


# create nic
$rescuevmpipname = "$vmname-pip-copy"
$rescuevmnicname = "$vmname-nic-copy"
$rescuevmsubnetip = ($vnet.Subnets |?{$_.id -notlike "*AzureBastionSubnet" -and $_.id -notlike "*AzureFirewallSubnet"})
write-output "Creating Public IP Address..."
$rescuevmPIP = New-AzPublicIpAddress -Name $rescuevmpipname -ResourceGroupName $ResourceGroupName -Location $vmlocation -AllocationMethod Dynamic -ErrorAction Stop
write-output "Public IP: $($rescuevmPIP.Ipaddress)"
write-output "Creating NIC..."
$rescuevmNIC = New-AzNetworkInterface -Name $rescuevmnicname -ResourceGroupName $ResourceGroupName -Location $vmlocation -SubnetId $rescuevmsubnetip.id -PublicIpAddressId $rescuevmPIP.Id -ErrorAction Stop
write-output "Network Adapter: $($rescuevmNIC.Name)"

# create VM
$now = Get-Date -Format "yyyyMMddhhmmss"
$RescueVMName = "R$now"
$RescueVM = New-AzVMConfig -VMName $RescueVMName -VMSize $RescueVMSku
 
$Credential = Get-Credential -Message "Please enter new credentials for the new Rescue VM."

$RescueVM = Set-AzVMOperatingSystem -VM $RescueVM -Windows -ComputerName $RescueVMName -ProvisionVMAgent -Credential $Credential
$RescueVM = Add-AzVMNetworkInterface -VM $RescueVM -Id $rescuevmNIC.Id
$RescueVM = Set-AzVMSourceImage -VM $RescueVM -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest
$RescueVM = Set-AzVMBootDiagnostic -Disable -VM $RescueVM

write-output "Creating Rescue VM...This will take a few minutes."
$newRescueVM = New-AzVM -ResourceGroupName $ResourceGroupName -Location $vmlocation -VM $RescueVM
if ($newRescueVM -eq $null)
{
    Write-Output "Failed to Create VM... cleaning up."
    Cleanup
}
Write-Output "Rescue VM Created:  $RescueVMName"

$RescueVMstate = $(get-azvm -Name $RescueVMName -Status).powerstate
while($RescueVMstate -ne "VM running"){Write-Output "Waiting for VM to Start...";sleep 15;$RescueVMstate = $(get-azvm -Name $RescueVMName -Status).powerstate}

$TheRescueVM = Get-AzVM|?{$_.Name -eq $RescueVMName}


# attach the copied affected OS disk as a data disk
# $diskcopy

Write-Output "Attaching affected disk copy to Rescue VM as data disk..."
$diskcopyid = $($diskcopy.Id).ToString()
$TheRescueVM = Add-AzVMDataDisk -VM $TheRescueVM -CreateOption attach -ManagedDiskId $diskcopyid -Lun 1 -ErrorAction Stop

Update-AzVM -VM $TheRescueVM -ResourceGroupName $ResourceGroupName
Write-output "Disk Attached."

# get pip 
$rescuevmPIP = (Get-Azpublicipaddress -ResourceGroupName $ResourceGroupName -Name $rescuevmpipname).IpAddress


# enable psremoting
Write-Output "Enabling PSRemoting on Rescue VM..."
$psremote = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $RescueVMName -CommandId 'EnableRemotePS' -ErrorAction Stop
$psremote.Status


# connect to rescue vm and execute the agent repair steps - registry and binary copy

$psops = New-PSSessionOption -SkipCACheck -SkipCNCheck
$invoke = Invoke-Command -ComputerName $rescuevmPIP -Credential $Credential -UseSSL -SessionOption $psops -ScriptBlock {
Get-Volume | where DriveLetter -eq "C" | Get-Partition | Get-Disk

get-volume | Get-Disk | Get-Partition | Where location -like "*: LUN 1"

foreach ($vol in get-volume)
{
    $datadisk = $vol | get-partition | get-Disk | Where location -like "*: LUN 1"
}
$datadrives = ($datadisk | Get-Partition).DriveLetter

# find windows installation on data disk
$c=0
foreach ($drive in $datadrives)
{
    $drive = "$drive"+':'
    
    $foundwindows = Test-Path -Path "$drive\windows"
    
    if ($foundwindows)
    {
        $c++
        Write-Output "Found data disk Windows directory on root of drive $drive ...($drive\windows)"
        $targetdrive = $drive
    }
}

if ($targetdrive -ne $null)
{
    Write-Output "No Windows folder found on data disk! Please mount the datadisk with a drive letter and type the letter here and press enter:"
    $targetdrive = Read-Host
}

if ($c -gt 1)
{
    Write-Output "Multiple Windows installations were found... Please type only the drive letter where the target install resides and press enter:"
    $targetdrive = Read-Host
}

if (!(Test-Path $targetdrive\Windows))
{
    Write-Output "Unable to find Windows directory on $targetdrive. Investigate disk issue manually. Exiting script without cleanup."
    exit
}
# backup broken agent dir
$agentinstalled = Test-Path $targetdrive\WindowsAzure
if ($agentinstalled -eq $true)
{
    Write-Output "Backing up old Agent directory to WindowsAzure.old.backup..."
    Move-Item G:\WindowsAzure -Destination $targetdrive\WindowsAzure.old.backup -Force
}

Write-Output "Copying Healthy WindowsAgent files from Rescue VM to affected drive..."
mkdir $targetdrive\WindowsAzure -Force
Copy-Item C:\WindowsAzure\Guest* -Destination $targetdrive\WindowsAzure\ -Recurse -Force
Copy-Item C:\WindowsAzure\Windows* -Destination $targetdrive\WindowsAzure\ -Recurse -Force
Copy-Item C:\WindowsAzure\SecAgent* -Destination $targetdrive\WindowsAzure\ -Recurse -Force

# backup reg section

Copy-Item $targetdrive\windows\System32\config -Recurse -Destination $targetdrive\AgentfixBackup -ErrorAction SilentlyContinue -Force

Write-Output "Loading registry hive..."
reg.exe load HKLM\BROKENSYSTEM $targetdrive\windows\system32\config\SYSTEM

# export broken keys if they exist

if (Test-Path HKLM:\BROKENSYSTEM\ControlSet001\Services\WindowsAzureGuestAgent)
{
    Write-Output "Existing VM Agent found in broken system. Backing up keys to $targetdrive\Agentfixbackupkeys"
    $newdir0 = mkdir $targetdrive\AgentfixBackupkeys -Force
    Write-output "Exporting key 1 from broken disk..."
    reg.exe export HKLM\BROKENSYSTEM\ControlSet001\Services\WindowsAzureGuestAgent $targetdrive\AgentfixBackupkeys\WindowsAzureGuestAgent.reg
    Write-output "Exporting key 2 from broken disk..."
    reg.exe export HKLM\BROKENSYSTEM\ControlSet001\Services\WindowsAzureTelemetryService $targetdrive\AgentfixBackupkeys\WindowsAzureTelemetryService.reg
    Write-output "Exporting key 3 from broken disk..."
    reg.exe export HKLM\BROKENSYSTEM\ControlSet001\Services\RdAgent $targetdrive\AgentfixBackupkeys\RdAgent.reg
}
else
{
    Write-Output "No existing Registry keys found for VM Agent."
}

# export working keys from rescue vm
Write-Output "Creating new directory $targetdrive\AgentfixExportkeys"
$newdir1 = mkdir $targetdrive\AgentfixExportkeys -Force

Write-output "Exporting key 1 from rescue VM..."
reg.exe export HKLM\SYSTEM\ControlSet001\Services\WindowsAzureGuestAgent $targetdrive\AgentfixExportkeys\WindowsAzureGuestAgent.reg
Write-output "Exporting key 2 from rescue VM..."
reg.exe export HKLM\SYSTEM\ControlSet001\Services\WindowsAzureTelemetryService $targetdrive\AgentfixExportkeys\WindowsAzureTelemetryService.reg
Write-output "Exporting key 3 from rescue VM..."
reg.exe export HKLM\SYSTEM\ControlSet001\Services\RdAgent $targetdrive\AgentfixExportkeys\RdAgent.reg

Write-Output "Modifying registry files..."
$file1 = Get-Content $targetdrive\AgentfixExportkeys\WindowsAzureGuestAgent.reg
$file2 = Get-Content $targetdrive\AgentfixExportkeys\WindowsAzureTelemetryService.reg
$file3 = Get-Content $targetdrive\AgentfixExportkeys\RdAgent.reg

$file1[2] = $file1[2].Replace('\SYSTEM\','\BROKENSYSTEM\')
$file2[2] = $file2[2].Replace('\SYSTEM\','\BROKENSYSTEM\')
$file3[2] = $file3[2].Replace('\SYSTEM\','\BROKENSYSTEM\')

Write-Output "Updating registry files..."
Set-Content -Value $file1 -Path $targetdrive\AgentfixExportkeys\WindowsAzureGuestAgent.reg -Force
Set-Content -Value $file2 -Path $targetdrive\AgentfixExportkeys\WindowsAzureTelemetryService.reg -Force
Set-Content -Value $file3 -Path $targetdrive\AgentfixExportkeys\RdAgent.reg -Force

Write-Output "Importing fixed registry key 1..."
reg.exe import $targetdrive\AgentfixExportkeys\WindowsAzureGuestAgent.reg
Write-Output "Importing fixed registry key 2..."
reg.exe import $targetdrive\AgentfixExportkeys\WindowsAzureTelemetryService.reg
Write-Output "Importing fixed registry key 3..."
reg.exe import $targetdrive\AgentfixExportkeys\RdAgent.reg

Write-Output "Unloading registry hive..."
reg.exe unload HKLM\BROKENSYSTEM
}

$invoke

if ($invoke -eq $null) # if rescue vm command invoke fails
{
    Write-Output "Unable to Invoke commands on the rescue VM.  Please check connectivity."
    write-output "Please execute registry modification and binary copy steps manually on the rescue VM and press ENTER when done to proceed with detaching and re-attaching the disk to the affected VM."
    Read-Host
}
# todo: return failure/success here, this all assumes everything went well on the rescue vm.


#detach the data disk from the rescue VM
Write-output "Detaching the data disk from the rescue VM..."
$removedisk = Remove-AzVMDataDisk -VM $TheRescueVM -DataDiskNames "$newsnapshotname-copy"
$upvm0 = Update-AzVM -VM $TheRescueVM -ResourceGroupName $ResourceGroupName
if ($upvm0.StatusCode -ne "OK")
{
    Write-Output "Unable to detach data disk!  Please investigate on the rescue VM."
}
 
# swap OS disk on affected VM with repaired data disk from rescue vm
Write-Output "Swapping OS disk on '$VMName' with fixed disk '$newsnapshotname-copy"
$swapdisko = Set-AzVMOSDisk -VM $VM -ManagedDiskId $diskcopyid -Name $($diskcopy.Name)
$swapdisk = Update-AzVM -ResourceGroupName $ResourceGroupName -VM $VM
if ($swapdisk.IsSuccessStatusCode -ne "True")
{
    Write-Output "Unable to swap OS disk."
}
else
{
    Write-Output "Disk swap successful!"
    
    Write-Output "Starting vm $($VM.name) ..."
    $startvm = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $($vm.name)
    if ($startvm.Status -ne "Succeeded")
    {
        Write-Output "Unable to start VM!"
    }
    else
    {
        Write-Output "VM Successfully Started!"
    }
}

# clean up - delete rescue VM and its resources
Cleanup

