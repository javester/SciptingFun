<# DISCLAIMER - By downloading / using these scripts you are agreeing that they are "Use at your own risk" and I will not be held responsible for any impact. Please make sure they will work for your need!
These sample scripts are not supported under any Microsoft standard support program or service. The sample scripts
are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without
limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising
out of the use or performance of the sample scripts and documentation remains with you. In no event shall Microsoft,
its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages
whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business
information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation,
even if Microsoft has been advised of the possibility of such damages. #>


# RehydrateArchiveBlobs.ps1
# Search blobs in storage account and change access tier from A to B.
# useful if needing to azcopy the data to another storage account as operations can't be done against archived blobs.
# down and dirty script - no error checking or catching.  Assumes all required permissions exist etc.

# User variables - modify as required

$StorageAccount = '<StorageAccountName>'
$ResourceGroup = '<ResourceGroupName>'

$oldtier = "Archive" # default 'Archive'
$newTier = "Cool" # Hot,Cool,Archive - Default 'cool'
$maxblobs = 10000 # maximum number of blobs to return at once - this effects the local machine's resources greatly. Recommend 10k maximum and this might still use a lot of RAM.

$starttime = Get-Date

#set storage account context
$ctx = (get-AzStorageaccount -ErrorAction Stop –StorageAccountName $storageAccount -resourcegroup $resourceGroup).context

#grab existing containers
$containers = Get-AzStorageContainer -Context $ctx

$blobc = 0
#loop through each container
foreach ($c in $containers)
{
    $contoken = $null
    $total = 0
    $loopc = 0
    
    do # loop begin
    {        
        $loopc++ 
        $i = 0
        $bc = 0
        #grab a list of blobs in container
        Write-Output "`nGathering Blob info in Container '$($c.Name)'... Batch $loopc (of $maxblobs blobs each max)"
        
        $allblobs = Get-AzStorageBlob -Context $ctx -Container $($c.Name) -MaxCount $maxblobs -ContinuationToken $contoken 
        $blobs = $allblobs | ?{$_.ICloudBlob.IsSnapshot -eq $false -and $_.AccessTier -like $oldtier}   
        
        $blobc += $blobs.Count
        $Total += $allblobs.Count

        foreach ($b in $blobs)
        {
            Write-Output "Changing tier from '$oldtier' blob $($b.ICloudBlob.Uri)"
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
Write-Output "Total blobs found in tier '$oldtier': $($blobc)"
Write-Output "Completed in $($etime.Hours) Hours, $($etime.Minutes) Minutes, $($etime.Seconds) Seconds."
