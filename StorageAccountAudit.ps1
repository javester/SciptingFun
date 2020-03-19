<# 

 Audit azure storage accounts for count of blobs, files, tables, queues
 currently supports ARM only accounts, not classic
 authored by jasims@microsoft.com
 v1.0 03/19/2020

 .PARAMETERS
 StorageAccountName: Storage Account name to audit.  By default audits all accounts.


#>

param(
$StorageAccountName
)

if ($StorageAccountName -ne $null)
{
    $storageaccounts = Get-AzStorageAccount -ErrorAction Stop |?{$_.StorageAccountName -like $StorageAccountName}
}
else
{
    $storageaccounts = Get-AzStorageAccount -ErrorAction Stop
}

#all results array
$results = @()
 

#go through each storage account
foreach ($sa in $storageaccounts)
{
    Write-verbose "Getting info on storage account: $($sa.storageaccountname)"

    #reset vars in case of failures
    $containers = $null
    $blobs = $null
    $files = $null
    $queues = $null
    $tables = $null

    #create output obj
    $saobj = New-Object -TypeName pscustomobject
    $saobj | Add-Member -MemberType NoteProperty -Name StorageAccountName -Value $sa.StorageAccountName
    $saobj | Add-Member -MemberType NoteProperty -Name Containers -Value $null
    $saobj | Add-Member -MemberType NoteProperty -Name Blobs -Value $null
    $saobj | Add-Member -MemberType NoteProperty -Name BlobSnapshots -Value $null
    $saobj | Add-Member -MemberType NoteProperty -Name Files -Value $null
    $saobj | Add-Member -MemberType NoteProperty -Name ShareSnapshots -Value $null
    $saobj | Add-Member -MemberType NoteProperty -Name Queues -Value $null
    $saobj | Add-Member -MemberType NoteProperty -Name Tables -Value $null

    # get containers
    Write-Verbose "Getting Storage Containers in account $($sa.StorageAccountName) ..."
    try  # for some reason this won't catch ... have to do some alternate error checking
    {
        $errorcount = $error.Count
        $containers = Get-AzStorageContainer -Context $sa.context -ErrorAction Stop
        if ($($containers -eq $null)){$saobj.Containers = 0}

        
        #get blobs
        foreach ($container in $containers)
        {
            $saobj.Containers += 1
            $blobs = Get-AzStorageBlob -Container $container.Name -Context $sa.Context 
            # get blob snapshots
            $blobsnapshots = Get-AzStorageBlob -Container $container.Name -Context $sa.Context|?{$_.SnapshotTime -ne $null}
            $saobj.Blobsnapshots = $blobsnapshots.count

            Write-Verbose "Number of Blobs found in container: $($Blobs.count)"
            $saobj.Blobs += $($blobs.count)
        }
        if ($($blobs.count) -eq 0){$saobj.Blobs=0}
        if ($($blobsnapshots.count) -eq 0){$saobj.Blobsnapshots=0}

    }
    catch
    {
        $saobj.Containers = "UNABLE TO READ CONTAINERS"
        $saobj.BlobSnapshots = "UNABLE TO READ CONTAINERS"
        $saobj.Blobs = "UNABLE TO READ CONTAINERS"
        $containers = $null
    }
    
    

    # get share snapshots
    try
    {
        $sharesnapshots = Get-AzStorageShare -Context $sa.Context -ErrorAction stop | ?{$_.IsSnapshot -eq $true}
        $saobj.Sharesnapshots = $sharesnapshots.Count
    }
    catch
    {
        $saobj.ShareSnapshots = "UNABLE TO READ SHARES"
    }

    #get files
    try
    {
        $shares = Get-AzStorageShare -Context $sa.Context -ErrorAction Stop| ?{$_.IsSnapshot -eq $false}
        foreach ($share in $shares)
        {
            $files = Get-AzStorageFile -ShareName $share.Name -Context $sa.Context
            $saobj.Files += $files.Count
        }
        if ($($files -eq $null)){$saobj.Files = 0}
    }
    catch
    {
        $saobj.Files = "UNABLE TO READ SHARES"
    }
    #get tables
    try
    {
        $tables = Get-AzStorageTable -Context $sa.Context -WarningAction SilentlyContinue -ErrorAction Stop
        $saobj.Tables = $tables.Count
    }
    catch{$saobj.Tables = "UNABLE TO READ TABLES"}

    #get queues
    try
    {
        $queues = Get-AzStorageQueue -Context $sa.Context -WarningAction SilentlyContinue -ErrorAction Stop
        $saobj.Queues = $queues.Count
    }
    catch{$saobj.Queues = "UNABLE TO READ QUEUES"}

    # see final storage account info counts
    $saobj

    #add result to list of results
    $results += $saobj
    
}

# see all results
# $results
