<#  This script AS - IS: use at own risk and test/validate functionality beforehand:

These sample scripts are not supported under any Microsoft standard support program or service. The sample scripts
are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without
limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising
out of the use or performance of the sample scripts and documentation remains with you. 
In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages
whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business
information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation,
even if Microsoft has been advised of the possibility of such damages. 



# down and dirty script to grab all file share snapshots for the specified storage account share name and search for a file with the name specified, and output if the file is found in each snapshot.

Update-AzConfig -DisplayBreakingChangeWarning $false | Out-Null # suppress breaking change messages for upcoming module updates

$StorageAccountName = "<storage account name>"
$resourcegroupName = "<resource group name>"
$sharename = "<file share name>"
$filename = "<file name>"  # the file you're looking for in the snapshots

#set storage account context
$ctx = Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $ResourceGroupName
# get file shares
Write-Host "Getting File Shares..."
$shares = Get-AzStorageShare -Context $ctx.Context -ea Stop

#get snapshots of specified share
$snapshots = $shares |?{$_.SnapshotTime -ne $null -and $_.IsSnapshot -eq $TRUE -and $_.Name -like $sharename}

Write-Host "$($snapshots.Count) snapshots found for file share $sharename."

foreach ($snap in $snapshots)
{
    $s = Get-AzStorageShare -SnapshotTime $snap.ListShareProperties.Snapshot -Name $sharename -Context $ctx.Context -ErrorAction Stop -WarningAction 0 | Get-AzStorageFile
    Write-Host "Searching in Snapshot $($snap.ListShareProperties.Snapshot) ..."
        
    if ($s.name -contains $filename)
    {
        Write-Host $filename found in Snapshot: $snap.ListShareProperties.Snapshot
    }
        
}

