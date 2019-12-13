<# 

.SYNOPSIS
    MOVES BLOB CONTAINERS INTO ROOT CONTAINER

.DESCRIPTION
    This script will move a bunch of containers into a common root level container, for example, if you want one common share/mount point to reach all of your blob containers.

 .EXAMPLE
    .\copyBlobContainers.ps1 -subscriptionID = 1234-1234-1234-1234 -StorageAccount mystorage -ResourceGroup RGroup1 -rootcontainer alltestcontainers -containerscope "testcontainer*" -Overwrite


#>
param(
[Parameter(Mandatory=$true)]$SubscriptionID = '',
[Parameter(Mandatory=$true)]$StorageAccount='',
[Parameter(Mandatory=$true)]$ResourceGroup='',
[Parameter(Mandatory=$true)]$rootcontainer = "", # the root container to move all other containers into
[Parameter(Mandatory=$true)]$containerscope = "", # the containers that we're moving. using wildcard to move multiple containers
[switch]$OverWrite = $false # OVERWRITES BLOBS IF THEY ALREADY EXIST!
)

if ((Get-AzContext) -eq $null)
{
    Write-Output "Please log in to Azure first."
    Add-AzAccount -EA Stop
}

Set-AzContext -Subscription $subscriptionId -ErrorAction Stop

$storagecontext = (get-azstorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccount -ErrorAction Stop).context # get storage context

$containers = Get-AzStorageContainer -Context $storagecontext -ErrorAction Stop | Where {$_.Name -like $containerscope} # get list of containers that exist

Write-Output "`n`nCopying to root container: $rootcontainer"

foreach ($container in $containers) # iterate through each container
{
    Write-Output "`nContainer Name: $($container.Name)`n"
    $blobs = Get-AzStorageBlob -Context $storagecontext -Container $container.name # grab the blobs in this container
    foreach ($blob in $blobs) # iterate through each blob in the container
    {
        Write-Output "Copying Blob: $($blob.name)"
        if ($OverWrite)
        {$copy = Start-AzStorageBlobCopy -SrcContainer $($container.Name) -SrcBlob $($blob.Name) -DestContainer $rootcontainer -DestBlob "$($container.name)/$($blob.Name)" -Context $storagecontext -ErrorAction Stop -Force} # copy blob}
        else{$copy = Start-AzStorageBlobCopy -SrcContainer $($container.Name) -SrcBlob $($blob.Name) -DestContainer $rootcontainer -DestBlob "$($container.name)/$($blob.Name)" -Context $storagecontext -ErrorAction Stop}
    }
}

