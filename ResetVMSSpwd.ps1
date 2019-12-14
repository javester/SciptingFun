
# Reset password on win vmss

PARAM(
[Parameter(Mandatory=$true)]$subscriptionId='',
[Parameter(Mandatory=$true)]$vmssName = '', # SCALE SET NAME
[Parameter(Mandatory=$true)]$vmssResourceGroup = '', # SCALE SET RESOURCE GROUP
[Parameter(Mandatory=$true)]$publicConfig = @{'UserName' = 'sysop'}, # ADMIN USER NAME
[Parameter(Mandatory=$true)]$privateConfig = @{'Password' = '4O54RE89VR23F'} # ADMIN PASSWORD
)


if ((Get-AzContext) -eq $null)
{
    Write-Output "Please log in to Azure first."
    Add-AzAccount -EA Stop
}

Set-AzContext -Subscription $subscriptionId -ErrorAction Stop


$extName = 'VMAccessAgent'
$publisher = 'Microsoft.Compute'
$vmss = Get-AzVmss -ResourceGroupName $vmssResourceGroup -VMScaleSetName $vmssName
$vmss = Add-AzvmssExtension -VirtualMachineScaleSet $vmss -Name $extName -Publisher $publisher -Setting $publicConfig -ProtectedSetting $privateConfig -Type $extName -TypeHandlerVersion '2.0' -AutoUpgradeMinorVersion $true
Update-AzVmss -ResourceGroupName $vmssResourceGroup -Name $vmssName -VirtualMachineScaleSet $vmss

