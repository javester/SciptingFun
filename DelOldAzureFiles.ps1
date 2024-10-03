<#  This script AS - IS: use at own risk and test/validate functionality beforehand:

These sample scripts are not supported under any Microsoft standard support program or service. The sample scripts
are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without
limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising
out of the use or performance of the sample scripts and documentation remains with you. 
In no event shall Microsoft,
its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages
whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business
information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation,
even if Microsoft has been advised of the possibility of such damages. 

 This script is used to delete any Azure Files in shares that are over x days old.
 SNAPSHOTS ARE NOT TARGETED as files inside of snapshots can't be deleted, only entire snapshots of a share can be deleted.

.PARAMETERS:
AGEINDAYS: how old in days for files/snapshots to be to target for deletion.  Deault 180.
### TO DO :  this isn't recursive - only targets one specific folder.  Need to enhance script to crawl every directory 
#>


param( 
[Parameter(Mandatory=$true)]$storageAccountname = '',
[Parameter(Mandatory=$true)]$ResourceGroupName = '',
[Parameter(Mandatory=$true)]$sharename = '',
$Folder = '',
$ageindays = '180'
)

$ctx = get-azstorageaccount -Name $storageAccountname -resourcegroupname $ResourceGroupName -ErrorAction Stop
$now = Get-Date
 
$share = Get-AzStorageShare -Name $sharename -Context $ctx.Context -ErrorAction Stop | ?{$_.IsSnapshot -eq $false}

if ($Folder -like ''){Write-Host "No folder specified - targeting root folder."}else{Write-Host "Targeting folder '$folder'"}
Write-Host "Targeting Share: '$($share.Name)'"
    
Write-Host "Gathering file details... This could take a while if there are many files/folders..."
       
$filesinfolder = Get-AzStorageFile -ShareName $sharename -Context $ctx.Context -Path "$folder" -ErrorAction Stop | Get-AzStorageFile
        
foreach ($file in $filesinfolder)
{
    Write-Host "$file"

    if ($file.GetType().Name -eq "AzureStoragefile")
    {
        Write-Host "`nFile:"
        $file.CloudFile.Url.LocalPath
        
        Write-Host "Last Modified Time:"
        $filem = $file.Fileproperties.LastModified.DateTime
        $Filem
        
        $fileage = New-TimeSpan -Start $filem -End $now
        Write-Host "Age: $($fileage.Days) Days"
         
        if ($fileage.Days -gt $ageindays)
        {
            Write-Host "File is older than $ageindays. Deleting File..."
            
            # DELETION OPERATION HERE - comment out for testing
            #$file | Remove-AzStorageFile
        }
    }
    
}

    



