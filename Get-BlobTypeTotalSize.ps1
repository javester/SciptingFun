<#
# get total size of VHD files (or whatever file filter you want)  found in storage account
  might also count up snapshots sizes? let me know
  6/4/2020 v1
#>


param(
$resourcegroupname = 'resourcegroupname',    # PROVIDE RESOURCE GROUP OF STORAGE ACCOUNT
$storageaccountname = 'storageaccountname',  # PROVIDE STORAGE ACCOUNT NAME
[switch]$nototal = $true
)

$output = @()
$totalsizeofVHDs = 0

$stc = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction Stop

$containers = Get-AzStorageContainer -Context $stc.Context -ErrorAction Stop

foreach ($container in $containers)
{
    $blobs = Get-AzStorageBlob -Name $container.name -Context $stc.Context -ErrorAction Stop

    foreach ($blob in $blobs)
    {
        if ($blob.Name -like '*.vhd' -and $blob.IsDeleted -eq $false) # FILTER TO WHATEVER YOU WANT
        {   $o = New-Object -TypeName psobject
            $o | Add-Member -MemberType NoteProperty -Name Name -Value $blob.Name
            $o | Add-Member -MemberType NoteProperty -Name StorageAccount -Value $storageAccountName
            $o | Add-Member -MemberType NoteProperty -Name Container -Value $container.Name
            $o | Add-Member -MemberType NoteProperty -Name SizeGB -Value $null
            $size = ([Math]::Round($($blob.Length)/1gb,3))
            $o.SizeGB = $size
            $totalsizeofVHDs += $size
            $output += $o
        }
    }
}

$output

if ($nototal)
{
    Write-Output "`nTotal blob size in storage account '$storageaccountName': $totalsizeofVHDs GB"
}

