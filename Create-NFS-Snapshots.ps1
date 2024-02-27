<# 

DISCLAIMER - By downloading / using these scripts you are agreeing that they are "Use at your own risk" and I nor Microsoft will be held responsible for any impact. 
Please make sure they will work for your need!

These sample scripts are not supported under any Microsoft standard support program or service. The sample scripts

are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without

limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising

out of the use or performance of the sample scripts and documentation remains with you. In no event shall Microsoft,

its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages

whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business

information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation,

even if Microsoft has been advised of the possibility of such damages.
    


    .DESCRIPTION
    
    This script will Create a snapshot for each NFS share found across all storage accounts on selected subscription.
#>


$StorageAccounts = Get-AzStorageAccount -errorAction Stop
$sub = Get-AzContext -ErrorAction Stop
Write-Host "`n$($StorageAccounts.Count) Storage Accounts found in subscription $($sub.subscription.Name) - $($sub.subscription.Id)"
Write-Host "If you need to change the subscription, use Set-AzContext -Subscription <subid>`n"

foreach ($sa in $StorageAccounts)
{
    $shares = $null
    Write-Host "Looking for NFS shares in Storage Account: $($sa.StorageAccountName)"
    $shares = Get-AzRmStorageShare -StorageAccountName $sa.StorageAccountName -ResourceGroupName $sa.ResourceGroupName -ErrorAction SilentlyContinue | ?{$_.EnabledProtocols -eq "NFS"} 
    foreach ($nfsshare in $shares)
    {
        Write-Host "*** Found NFS Share: $($nfsshare.Name)"
        Write-Host "Creating Snapshot...`n"
        New-AzRmStorageShare -StorageAccountName $sa.StorageAccountName -ResourceGroupName $sa.ResourceGroupName -Name $nfsshare.Name -Snapshot -ErrorAction Continue
    }
    if ($shares -ne $null){Get-AzRmStorageShare -StorageAccountName $sa.StorageAccountName -ResourceGroupName $sa.ResourceGroupName -IncludeSnapshot |?{$_.EnabledProtocols -eq "NFS" -and $_.SnapshotTime -ne $null}| Sort-Object SnapshotTime -Descending}
}
