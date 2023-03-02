 <# 
DISCLAIMER - By downloading / using these scripts you are agreeing that they are "Use at your own risk" and I will not be held responsible for any impact. Please make sure they will work for your need!

These sample scripts are not supported under any Microsoft standard support program or service. The sample scripts
are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without
limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising
out of the use or performance of the sample scripts and documentation remains with you. In no event shall Microsoft,
its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages
whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business
information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation,
even if Microsoft has been advised of the possibility of such damages.
#>

# GATHER LIST OF SERVER ENDPOINTS AGAINST EACH SYNC SERIVCE AND GROUP.

$syncservices = Get-AzStorageSyncService -ErrorAction Stop

$totalout = @()
Write-Verbose "$($syncservices.count) Sync Services Found."
foreach ($syncservice in $syncservices)
{
    Write-Verbose "`nFound Sync Service $($syncservice.StorageSyncServiceName) ..."
    $syncgroups = Get-AzStorageSyncGroup -ResourceGroupName $syncservice.ResourceGroupName -StorageSyncServiceName $syncservice.StorageSyncServiceName -ErrorAction Stop
    foreach ($syncgroup in $syncgroups)
    {
        Write-Verbose " Found Sync Group $($syncgroup.SyncGroupName) ..."
        $SEPs = Get-AzStorageSyncServerEndpoint -ResourceGroupName $syncgroup.ResourceGroupName -SyncGroupName $syncgroup.SyncGroupName -StorageSyncServiceName $syncservice.StorageSyncServiceName
        foreach ($sep in $SEPS)
        {
            $output = New-Object PSObject
            Add-Member -InputObject $output -MemberType NoteProperty -Name "SyncServiceName" -Value $syncgroup.StorageSyncServiceName
            Add-Member -InputObject $output -MemberType NoteProperty -Name "SyncGroup" -Value $syncgroup.SyncGroupName
            Add-Member -InputObject $output -MemberType NoteProperty -Name "ServerEndpointName" -Value $sep.ServerName
            $totalout += $output
        }
        
        
    }
}

$totalout

# uncomment to convert to csv  
# $totalout | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath .\AZFILESYNCSERVICES.csv -Force

