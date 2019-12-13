<#
     DISABLE FIPS AND TLS 1.1/1.0 For Powershell!  If you can't fetch repositories or install any modules in Powershell, this may be why!
     
   
#>

# Run this to check if TLS 1.0 or 1.1 is enabled. You only want to see 'Tls12' as output.
[Net.ServicePointManager]::SecurityProtocol

 
# If you see more than just "Tls12", like "Tls, Tls11, Tls12", then run the following to force using only TLS 1.2 - no reboot needed.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

 
# Check for FIPS being enabled, which will also prevent reaching the repository.
Get-Item HKLM:\System\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy

 
# If you see "Enabled : 1" here, then you need to disable it and reboot. You can disable it with the following:
New-ItemProperty - Path HKLM\System\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy -name Enabled -value 0 -Force

 
# Once those are done (assuming one was incorrect and needed fixing), run:
Register-PsRepository -Default
 

# Then you should be able to install-module Az -force or whatever!
# AzureRM is over a year old with no updates and won't support new features, I would strongly suggest to not use AzureRm anymore.
