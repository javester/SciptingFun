
 <#
    .SYNOPSIS
        Search a drive for the top largest directory sizes!  Handy to figure out why your drive is full!
        Default is top 10 directories on the C: on the local machine.

 #>


Function GetDriveDirSizes{
    param 
    ( 
      [String]$drive = "C:",
      [int]$Top = 10,
      [string]$Server = 'localhost'
    )  
    $folders=""
    $rootdir=""
    $rootsize=$null
    
    if (!(test-path $drive)){"Drive $drive Doesn't Exist!";return}

      $sharePath = $drive.Replace(":","$")
      $FileSystemObject = New-Object -com  Scripting.FileSystemObject 
  
        
      $folders = (gci "\\$server\$sharePath\" -recurse -Directory -Force -ErrorAction Silentlycontinue | ? {$_.PSIsContainer}) #? {$_.Attributes -eq "Directory"}) }
      $rootdir = (gci "\\$server\$sharePath\" -Force -ErrorAction Silentlycontinue)
     
      
      $rootsize = [math]::Round(($rootdir | Measure-Object -Sum Length).Sum / 1gb,2)
      $rootdir | Add-Member -MemberType NoteProperty -Name "SizeGB" –Value($rootsize / 1GB) 
  

      foreach ($folder in $folders) 
      {  
          $folder | Add-Member -MemberType NoteProperty -Name "SizeGB" –Value(($FileSystemObject.GetFolder($folder.FullName).Size) / 1GB) 
      } 
  
      $output = $folders | select fullname,@{n=’SizeGB’;e={"{0:N3}" –f $_.SizeGB}} | Where-Object SizeGB -gt 0.01 | Sort-Object SizeGB -Descending
    
     $outdata=@{};
     foreach ($e in $output)
     {
         $OutData.Add($e.FullName,[string]$e.SizeGB)
     }
     $outdata.Add("\\$server\$sharePath",[string]$rootsize)
  
     $DRIVEDATA = $outdata.GetEnumerator() | select Name,Value| sort-object Value -Descending | ConvertTo-Json | ConvertFrom-Json
 
     #format for OMS
     $omsdata =  $outdata.GetEnumerator() | select Name,Value |ConvertTo-Json 
     #$omsdata

     #$obj= New-Object psobject

     
     "`nTop $top directory sizes in GB on $drive on $server"
     $drivedirdata = $DRIVEDATA | Select-Object -First $top | Out-String 
     Return $drivedirdata 
}

GetDriveDirSizes
