<#

    Easily fetch an App Service's logs from Azure Storage based on time range and output it into CSV for easy analyzing in Excel!

#>
param(
[string][Parameter(Mandatory=$false)]$SubscriptionID,
[string][Parameter(Mandatory=$false)]$ResourceGroup,
[datetime]$StartDate, # in MM/DD/YYYY format
[datetime]$EndDate,
[string][Parameter(Mandatory=$false)]$StorageAccountName,
[string][Parameter(Mandatory=$false)]$LogContainer,
[string]$OutputFile="AppServiceLogs-$LogContainer.csv"
)

if ($StartDate -ne $null)
{
    try{$datestart = (get-date -Format d $startdate -ErrorAction Stop)}catch{Write-Output "*** Please enter a valid Date in the format of MM/DD/YYYY.";exit}
    Write-Output "Start Date: $datestart"
} else {$datestart = get-date 1/1/1980}

if ($EndDate -ne $null)
{
    try{$dateend = (get-date -Format d $enddate -ErrorAction Stop)}catch{Write-Output "*** Please enter a valid Date in the format of MM/DD/YYYY.";exit}
    Write-Output "End Date: $dateend"
} else {$dateend = Get-Date -Format d}

if ($datestart -ne $null -and $dateend -ne $null -and $datestart -gt $dateend)
{
    Write-Output "*** End date must be after Start date."
    exit
}

if ($StartDate -eq $null -and $EndDate -eq $null)
{
    Write-Output "No Time Range specified - Getting ALL logs..."
}

[datetime]$dateend = $dateend
[datetime]$datestart = $datestart

$results = @()

$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName -ErrorAction Stop
if($storageAccount -eq $null)
{
    throw "The storage account specified does not exist in this subscription."
}

$storageContext = $storageAccount.Context
$container = Get-AzStorageContainer -Context $storageContext -Name $LogContainer -ErrorAction SilentlyContinue
  
$Blobs = Get-AzStorageBlob -Context $storageContext -Container $($Container.Name) -IncludeDeleted
if($Blobs -eq $Null) 
{
    Write-Output "No Blobs Found!"
    break
}    

$bloblist=@()
$i=1
$ii=0
$file = '.\0.log'
foreach ($blob in $blobs)
{
    $d = ($blob.name).Split('/')
    [string]$d1 = $d[2] +"/"+ $d[3] + "/" + $d[1]
    [datetime]$blobdate = (Get-Date -f d $d1)

    if (($Datestart -le $blobdate) -and ($dateEnd -ge $blobdate))
    {
        $ii++
        $bloblist += $blob
        $totalblobcount = $ii
    }
}
Write-Output "Total Blobs found in time span: $ii"

foreach($blob in $bloblist)
{
    $d = ($blob.name).Split('/')
    [string]$d1 = $d[2] +"/"+ $d[3] + "/" + $d[1]
    [datetime]$blobdate = (Get-Date -f d $d1)

    Write-Output("Grabbing blob: $($blob.Name) - Size: $($blob.Length) - $i of $totalblobcount")
    $i++
    #$logfiletext = $blob.ICloudBlob.DownloadText()  # this doesn't work as it grabs the log file as one big string and then can't iterate through each record
    $logfiletext = Get-AzStorageBlobContent -Blob $blob.Name -Container $LogContainer -Context $storageContext -Destination $file -Force -ErrorAction SilentlyContinue
    $logfiletext = Get-Content $file
    Remove-Item $file -Force
    if ($logfiletext -eq $null)
    {
        Write-Output "Unable to write the temp file to the current directory. Please change to a directory where you have write access and run again."
        exit
    }
}

$log = $logfiletext
$nlog = $log -replace ' ',','
$nlog = $nlog[1..($nlog.Count)]
$nlog[0] = $nlog[0].Replace('#Fields:,','')
$nlog = $nlog | ConvertFrom-Csv | ConvertTo-Csv -NoTypeInformation -Delimiter ","

if ($OutputFile -eq "AppServiceLogs-$LogContainer.CSV")
{
    $nlog | Out-File -Append -Force -FilePath ".\AppServiceLogs-$LogContainer.CSV" -ErrorAction Stop -Encoding ascii
    Write-Output "`n Output to file: .\AppServiceLogs-$LogContainer.CSV"
}
else
{
    $nlog | Out-File -Append -Force -FilePath $OutputFile -ErrorAction Stop
    Write-Output "`n Output to file: $OutputFile"
}

