<#
DISCLAIMER - By downloading / using these scripts you are agreeing that they are "Use at your own risk" and I will not be held responsible for any impact. Please make sure they will work for your need!
These sample scripts are not supported under any Microsoft standard support program or service. The sample scripts
are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, wihout
limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising
out of the use or performance of the sample scripts and documentation remains with you. In no event shall Microsoft,
its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages
whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business
information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation,
even if Microsoft has been advised of the possibility of such damages. #>

# This script is used to clean up soft deleted blobs and snapshots that are no longer needed.
# It will search a specified Azure Storage Account container for deleted blobs and snapshots, undelete them, then delete them.
# Before running this script, make sure that Soft Delete is DISABLED on the storage account, or else the deletion operation will simply put them right back into the soft deleted state they were in before.
#
#
# v1.0 07/04/2020
#
#
#
# .PARAMETERS
#
# ResourceGroupName = '<resource group name>'
# StorageAccountName = '<Storage Account Name>'
# ContainerName = '<Blob Container Name>'
#
#


param(

$resourceGroupName = '<rg>',
$storageaccountname = '<sa>',
$ContainerName = '<cntr>'

)


# --------------------------------------------------------------------

Write-Host "`nPlease make sure that soft-delete is disabled on the storage account before executing!"

$ct = Get-AzContext -ErrorAction SilentlyContinue
if ($ct -eq $null)
{
    Write-Host "Please log in to Azure first and then select your subscription with> Set-AzContext <subscriptionID>."
    Add-AzAccount -ErrorAction Stop
}
 
$ctx = Get-AzStorageAccount -name $storageaccountname -resourcegroup $resourceGroupName -ErrorAction Stop
$blobs = Get-AzStorageBlob -IncludeDeleted -Context $ctx.Context -Container $ContainerName -ErrorAction Stop |?{$_.IsDeleted -eq $true}

$ctx = Get-AzStorageAccount -name $storageaccountname -resourcegroup $resourceGroupName -ErrorAction Stop
$blobs = Get-AzStorageBlob -IncludeDeleted -Context $ctx.Context -Container $ContainerName -ErrorAction Stop |?{$_.IsDeleted -eq $true}

if ($blobs -eq $null)
{
    Write-Host "`nNo deleted blobs found in container '$ContainerName'."
    exit
}
$i=0
foreach ($delblob in $blobs)
{
    $blobsize = ($($delblob.Length/1MB))
    
    $i++
    $snap=$false
    
    if ($delblob.SnapshotTime -ne $null)
    {
        $snap = $true
    }
    if (!$snap)
    {Write-Output "$i / $($blobs.count): Deleting Soft-Deleted Blob: $($delblob.Name) $([math]::Round($blobsize,3))MB $($delblob.LastModified)"}
    else
    {Write-Output "$i / $($blobs.count): Deleting Soft-Deleted Snapshot: $($delblob.Name) $([math]::Round($blobsize,3))MB $($delblob.SnapshotTime)"}

    $delblob.ICloudBlob.Undelete()
    $delblob | Remove-AzStorageBlob -Force
}

