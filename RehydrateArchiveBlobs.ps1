# USE AT YOUR OWN RISK!

# search blobs in storage account and change any found in 'archive' tier to 'cool' tier.
# useful if needing to azcopy the data to another storage account as operations can't be done against archived blobs

# down and dirty script - no error checking or catching.  Assumes all required permissions exist etc
# tested on a storage account with 20k blobs in container and it used approx 16gb of ram on a VM!!!
# Use at your own risk!!! This is likely not the best way to do this but it works if you don't have a lot of blobs!


 

# search blobs in storage account and change any found in 'archive' tier to 'cool' tier.
# useful if needing to azcopy the data to another storage account as operations can't be done against archived blobs

# down and dirty script - no error checking or catching.  Assumes all required permissions exist etc


# User variables - modify as required
$StorageAccount = '<storageaccount>'
$ResourceGroup = '<resourcegroup>'
$newTier = "<tier>" # Hot,Cool,Archive
$maxblobs = 10000 # maximum number of blobs to return at once - this effects the local machine's resources greatly. Recommend 10k maximum and this might still use a lot of RAM.

$starttime = Get-Date


#set storage account context
$ctx = (get-AzStorageaccount –StorageAccountName $storageAccount -resourcegroup $resourceGroup).context


#grab existing containers
$containers = Get-AzStorageContainer -Context $ctx


#loop through each container
foreach ($c in $containers)
{
    $contoken = $null
    $total = 0
    do 
    {        
        $i = 0
        $bc = 0
        #grab a list of blobs in container
        Write-Output "`nGathering Blob info in Container '$($c.Name)'..."
        
        $allblobs = Get-AzStorageBlob -Context $ctx -Container $($c.Name) -MaxCount $maxblobs -ContinuationToken $contoken 
        $blobs = $allblobs | ?{$_.ICloudBlob.IsSnapshot -eq $false -and $_.AccessTier -like "Archive"}   
        
        #Write-Output "`nFound $($blobs.count) Archived Blobs in Container '$($c.Name)'."
        
        $Total += $allblobs.Count
        foreach ($b in $blobs)
        {
            Write-Output "Changing tier for archived blob $($b.ICloudBlob.Uri)"
            $b.ICloudBlob.SetStandardBlobTier($newTier)
        }
        if($allblobs.Length -le 0) {break}
        $contoken = $allblobs[$allblobs.Count -1].ContinuationToken; 
    } while ($contoken -ne $Null)
    Write-Output "Total blobs in container '$($c.Name)': $Total" 
}



"`n`nDone."
$endtime = Get-Date

$etime = (($endtime) - ($starttime))

Write-Output "Completed in $($etime.Hours) Hours, $($etime.Minutes) Minutes, $($etime.Seconds) Seconds."
