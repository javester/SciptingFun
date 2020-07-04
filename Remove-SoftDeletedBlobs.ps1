#
# This script is used to clean up soft deleted blobs and snapshots that are no longer needed.
# It will search a specified Azure Storage Account container for deleted blobs and snapshots, undelete them, then delete them.
# Before running this script, make sure that Soft Delete is DISABLED on the storage account, or else the deletion operation will simply put them right back into the soft deleted state they were in before.
#
#
# v1.0 07/04/2020
#


param(

$resourceGroupName = '<rg>',
$storageaccountname = '<sa>',
$ContainerName = '<cntr>'

)


# --------------------------------------------------------------------

Write-Host "`nPlease make sure that soft-delete is disabled on the storage account before executing!"

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

