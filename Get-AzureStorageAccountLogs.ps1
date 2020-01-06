# Get-StorageAccountLogs.ps1
#
# Grab all Storage Account Logs from $logs container and export to CSV for easy analysis in Excel
# Why?  To simplify storage account log collection. Example: customer wants to know when ip address x.x.x.x accessed storage account in the past week. 
# This script will avoid having to open the very many log files created for a busy storage account and instead put all records into a single Excel sheet for easy analysis.
#
#
# v1.0 Dec 2019
#
#
#
# .PARAMETERS
# 
# StartDate - the begining date to search logs
# EndDate - the end date to search logs
# ResourceGroup - Resource Group where Storage Account resides
# StorageAccountName - Storage account name
#
#
#
# Example usage - 
# Grab All logs: .\Get-StorageAccountLogs.ps1 -ResourceGroup <resourcegroupname> -StorageAccountName <storageaccountname>
# Grab Logs from Dec 1st: .\Get-StorageAccountLogs.ps1 -ResourceGroup <resourcegroupname> -StorageAccountName <storageaccountname> -StartDate 12/01/2019
# Grab Logs from start to Dec 5th: .\Get-StorageAccountLogs.ps1 -ResourceGroup <resourcegroupname> -StorageAccountName <storageaccountname> -EndDate 12/05/2019
# Grab Logs from Dec 2 to Dec 10: .\Get-StorageAccountLogs.ps1 -ResourceGroup <resourcegroupname> -StorageAccountName <storageaccountname> -StartDate 12/02/2019 -EndDate 12/10/2019
#
#
#
#
#
param
(
[datetime]$StartDate, # in MM/DD/YYYY format
[datetime]$EndDate,
[Parameter(Mandatory=$true)]$ResourceGroup,
[Parameter(Mandatory=$true)]$StorageAccountName,
$LogContainer = "`$logs" # default dir for logs

)
 
if ((Get-AzContext) -eq $null){Add-AzAccount}

Write-Output "Grabbing Storage Account Logs..."

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
[datetime]$dateend = $dateend
[datetime]$datestart = $datestart

$results = @()

# Convert ; to "%3B" between " in the csv line to prevent wrong values output after split with ;
#
Function ConvertSemicolonToURLEncoding([String] $InputText)
{
    $ReturnText = ""
    $chars = $InputText.ToCharArray()
    $StartConvert = $false

    foreach($c in $chars)
    {
        if($c -eq '"') {
            $StartConvert = ! $StartConvert
        }

        if($StartConvert -eq $true -and $c -eq ';')
        {
            $ReturnText += "%3B"
        } else {
            $ReturnText += $c
        }
    }

    return $ReturnText
}

#
# If a text doesn't start with ", add "" for json value format
# If a text contains "%3B", replace it back to ";"
#
Function FormalizeJsonValue($Text)
{
    $Text1 = ""
    if($Text.IndexOf("`"") -eq 0) { $Text1=$Text } else {$Text1="`"" + $Text+ "`""}

    if($Text1.IndexOf("%3B") -ge 0) {
        $ReturnText = $Text1.Replace("%3B", ";")
    } else {
        $ReturnText = $Text1
    }
    return $ReturnText
}

Function ConvertLogLineToJson([String] $logLine)
{
    #Convert semicolon to %3B in the log line to avoid wrong split with ";"
    $logLineEncoded = ConvertSemicolonToURLEncoding($logLine)

    $elements = $logLineEncoded.split(';')

    $FormattedElements = New-Object System.Collections.ArrayList
                
    foreach($element in $elements)
    {
        # Validate if the text starts with ", and add it if not
        $NewText = FormalizeJsonValue($element)

        # Use "> null" to avoid annoying index print in the console
        $FormattedElements.Add($NewText) | Out-Null
    }

    $Columns = 
    (   "version-number",
        "request-start-time",
        "operation-type",
        "request-status",
        "http-status-code",
        "end-to-end-latency-in-ms",
        "server-latency-in-ms",
        "authentication-type",
        "requester-account-name",
        "owner-account-name",
        "service-type",
        "request-url",
        "requested-object-key",
        "request-id-header",
        "operation-count",
        "requester-ip-address",
        "request-version-header",
        "request-header-size",
        "request-packet-size",
        "response-header-size",
        "response-packet-size",
        "request-content-length",
        "request-md5",
        "server-md5",
        "etag-identifier",
        "last-modified-time",
        "conditions-used",
        "user-agent-header",
        "referrer-header",
        "client-request-id"
    )
     
    $logJson = "[{";
    For($i = 0;$i -lt $Columns.Length;$i++)
    {
        $logJson += "`"" + $Columns[$i] + "`":" + $FormattedElements[$i]
        if($i -lt $Columns.Length - 1) {
            $logJson += ","
        }
    }
    $logJson += "}]";

    return $logJson
}

if ((Get-AzContext) -eq $null)
{
    Write-Output "Please log in to Azure first."
    Add-AzAccount -ErrorAction Stop
}


$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName -ErrorAction SilentlyContinue
if($storageAccount -eq $null)
{
    throw "The storage account specified does not exist in this subscription."
}

$storageContext = $storageAccount.Context
$container = Get-AzStorageContainer -Context $storageContext -Name $LogContainer -ErrorAction SilentlyContinue
  
$Blobs = Get-AzStorageBlob -Context $storageContext -Container $Container.Name -IncludeDeleted
if($Blobs -eq $Null) 
{
    Write-Output "No Blobs Found!"
    break
}    

$bloblist=@()
$i=1
$ii=0
$file = '0.log'
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
    $logfiletext = Get-AzStorageBlobContent -Blob $blob.Name -Container $LogContainer -Context $storageContext -Destination $file -Force -ErrorAction Continue
    if ($logfiletext -eq $null){Write-Output "Unable to get Log file content!";exit}
    $logfiletext = Get-Content $file
    Remove-Item $file -Force
    if ($logfiletext -eq $null)
    {
        Write-Output "Unable to write the temp file to the current directory. Please change to a directory where you have write access and run again."
        exit
    }
    
    foreach($line in $logfiletext)
    {
        $output = $null # debug
        $json = $null # debug

        $json = ConvertLogLineToJson($line)
        
        # remove weird extra '1.0' put at the end of some of the lines that isn't valid
        if ($json.Substring($json.Length -5,5) -eq '1.0}]')
        {
            $json = $json.Substring(0,$json.Length -5)
            $json = $json + "}]"
        }
        
        try
        {
            $output = $json | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
        catch
        {
            Write-Output "Unable to convert log data for this record!"
            continue
        }
      
        $results += $output  
    }
}

$results | Export-Csv -NoTypeInformation -Path ".\StorageAccountLogs-$StorageAccountName.csv" -Force -Append -ErrorAction Stop
Write-Output "File output to .\StorageAccountLogs-$StorageAccountName.csv"




