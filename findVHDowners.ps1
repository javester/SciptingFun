<# 
    .SYNOPSIS
        
        find all VHDs in all classic storage accounts and get info on them such as owner etc

#>

param
(
[Parameter(Mandatory=$true)]$SubscriptionID,
[switch]$OutputToCSV
)
$OutputToCSV=$FALSE

Select-AzureSubscription -SubscriptionId $SubscriptionID -EA Stop

$results = @()

foreach ($sa in (Get-AzureStorageAccount -ErrorAction Stop))
{
    write-output "Searching Storage Account '$($SA.Name)'..."
    $storagecontext = $($SA.Context)

    foreach ($container in (Get-AzureStorageContainer -Context $storagecontext))
    {
        Write-Output "Searching container '$($container.Name)'..."

        foreach ($blob in Get-AzureStorageBlob -Container $($container.Name) -Context $storagecontext)
        {
            $blob = $blob | Where {$_.Name -like '*.vhd'}  
    
            $OBJ = New-Object -TypeName PSObject
            $OBJ | Add-Member -MemberType NoteProperty -Name Subscription -Value $SubscriptionID 
            $OBJ | Add-Member -MemberType NoteProperty -Name StorageAccount -Value $($storagecontext.Name)
            $OBJ | Add-Member -MemberType NoteProperty -Name Container -Value $($container.Name)
            $OBJ | Add-Member -MemberType NoteProperty -Name Blob -Value $($blob.Name)
            $OBJ | Add-Member -MemberType NoteProperty -Name LeaseState -Value $($blob.ICloudBlob.Properties.LeaseState)
            $OBJ | Add-Member -MemberType NoteProperty -Name LeaseStatus -Value $($blob.ICloudBlob.Properties.LeaseStatus)
            $OBJ | Add-Member -MemberType NoteProperty -Name DiskName -Value $null
            $OBJ | Add-Member -MemberType NoteProperty -Name AttachedTo -Value $null
    
            foreach ($disk in Get-AzureDisk)
            {
                if ($($disk.MediaLink.AbsoluteUri) -eq $($blob.ICloudBlob.StorageUri.PrimaryUri))
                {
                    $OBJ.DiskName = $($disk.DiskName)
                    $OBJ.AttachedTo = $($disk.AttachedTo.RoleName)
                }
            }
        
            #$OBJ 
            $results+=$OBJ
        }
    }
}
if ($OutputToCSV)
{
    $results | Export-Csv -NoTypeInformation -Path ".\VHD-$StorageAccountName.csv" -Force -Append -ErrorAction Stop
    Write-Output "File output to .\VHD-$StorageAccountName.csv"
}
else
{
    $results
}


