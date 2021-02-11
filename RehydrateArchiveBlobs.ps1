# USE AT YOUR OWN RISK!

# search blobs in storage account and change any found in 'archive' tier to 'cool' tier.
# useful if needing to azcopy the data to another storage account as operations can't be done against archived blobs

# down and dirty script - no error checking or catching.  Assumes all required permissions exist etc
# tested on a storage account with 20k blobs in container and it used approx 16gb of ram on a VM!!!
# Use at your own risk!!! This is likely not the best way to do this but it works if you don't have a lot of blobs!



# User variables - modify as required
$StorageAccount = '<storage account name>'
$ResourceGroup = '<resource group name>'
$newTier = "Cool"

$starttime = Get-Date


#set storage account context
$ctx = (get-AzStorageaccount –StorageAccountName $storageAccount -resourcegroup $resourceGroup).context


#grab existing containers
$containers = Get-AzStorageContainer -Context $ctx

#loop through each container
foreach ($c in $containers)
{ 
    $i = 0
    $bc = 0
    #grab a list of blobs in container
    Write-Output "`nGather Blob info in Container '$($c.Name)' ..."
    $blobs = Get-AzStorageBlob -Context $ctx -Container $c.Name | ?{$_.ICloudBlob.IsSnapshot -eq $false -and $_.AccessTier -like "Archive"}   
    

    # This may be the fastest way to do this but there will be zero progress indication.
    # $blobs.icloudblob.setstandardblobtier($newTier)



    Write-Output "`nFound $($blobs.count) Archived Blobs in Container '$($c.Name)'."
    
    $bc = $blobs.count

    foreach ($b in $blobs)
    {
        $i++
        Write-Output "`nOperation $i of $bc ..."
        Write-Output "Changing tier for archived blob $($b.ICloudBlob.Uri)"
        $b.ICloudBlob.SetStandardBlobTier($newTier)
    }     
}



"`n`nDone."
$endtime = Get-Date

$etime = (($endtime) - ($starttime))

Write-Output "Completed in $($etime.Hours) Hours, $($etime.Minutes) Minutes, $($etime.Seconds) Seconds."



## AZ mess around
<#

$connectionString = "<ConnectionString>"
$containerName = "<ContainerName>"

$hotAccessTierFiles = az storage blob list --connection-string $connectionString --container-name $containerName --query "[?properties.blobTier=='Archive'].name" --num-results *

Add-Type -AssemblyName System.Web.Extensions
$JS = New-Object System.Web.Script.Serialization.JavaScriptSerializer

$hotAccessTierFilesObject = $JS.DeserializeObject($hotAccessTierFiles)

$hotAccessTierFilesObject | % { az storage blob set-tier --connection-string $connectionString --container-name $containerName --name $_ --tier "Hot" }

#>
