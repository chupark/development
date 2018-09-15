﻿<#   
================================================================================ 
 Name: Excute_Post_Script.ps1 
 Purpose: Post Script Excution Using Azure VM Extension 
 Author: molee
 Description: This script is for excuting a post(custom) script using Azure VM extension & Powershell. 
 Limitations/Prerequisite:
    * Need "VMconfig.csv" file for servernames
    * Must Run PowerShell (or ISE)  
    * Requires PowerShell Azure Module
    * Need Slack Application URI (if you don't want to be alerted, just remove slack part from this script)
    * 참고: https://api.slack.com/incoming-webhooks
 ================================================================================ 
#>


#Storage Account has script for after-script
#Powershell(Windows) URL: https://moonsunscripts.blob.core.windows.net/scripts/InitialScript.ps1
#Bash Script(Linux) URL: https://moonsunscripts.blob.core.windows.net/scripts/InitialScriptLinux.sh
          
#Linux Extension - https://docs.microsoft.com/ko-kr/azure/virtual-machines/extensions/custom-script-linux
#Set-AzureRmVMExtension -ResourceGroupName $resourceGroup -Location $location -VMName $vmName -Name $linuxscriptName -Publisher "Microsoft.Azure.Extensions" -Type "customScript" `
#-TypeHandlerVersion 2.0 -Settings $linuxSettings -ProtectedSettings $linuxProtectedSettings            

#Windows Extension - https://docs.microsoft.com/ko-kr/azure/virtual-machines/extensions/custom-script-windows
#Set-AzureRmVMExtension -ResourceGroupName $resourceGroup -Location $location -VMName $vmName -Name $winscriptName -Publisher "Microsoft.Compute" -Type "CustomScriptExtension" `
#-TypeHandlerVersion 1.9 -Settings $winSettings -ProtectedSettings $winProtectedSettings    

$csvpath = import-csv 'C:\VMconfig.csv'
foreach ($csv in $csvpath){
    Start-Job -Name $csv.vmName { 
        param ($vmName, $resourceGroup, $location, $os) 

        $tenantID = "**********************************"
        $appid = "**********************************"
        $pwd = Get-Content 'C:\LoginCred.txt' | ConvertTo-SecureString
        $cred = New-object System.Management.Automation.PSCredential("$appid", $pwd)
        Add-AzureRmAccount -Credential $cred -TenantID $tenantId -ServicePrincipal

        $storageAccountName = "moonsunscripts"
        $storageAccountKey = "**********************************"

        #Shell
        $linuxuri = "https://moonsunscripts.blob.core.windows.net/scripts/InitialScriptLinux.sh"
        $linuxSettings = @{"fileUris" = @($linuxuri); "commandToExecute" = "./InitialScriptLinux.sh"}
        $linuxProtectedSettings = @{"storageAccountName" = $storageAccountName; "storageAccountKey" = $storageAccountKey}
        $linuxscriptName = "Post-Script-Linux"

        #PS1
        $winuri = "https://moonsunscripts.blob.core.windows.net/scripts/InitialScript.ps1"
        $winSettings = @{"fileUris" = @($winuri); "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File InitialScript.ps1"}
        $winProtectedSettings = @{"storageAccountName" = $storageAccountName; "storageAccountKey" = $storageAccountKey}
        $winscriptName = "Post-Script-Windows"
                 
        $status = "$null"

        if($os -eq "linux")
        {
            Set-AzureRmVMExtension -ResourceGroupName $resourceGroup -Location $location -VMName $vmName -Name $linuxscriptName -Publisher "Microsoft.Azure.Extensions" -Type "customScript" `
                                   -TypeHandlerVersion 2.0 -Settings $linuxSettings -ProtectedSettings $linuxProtectedSettings
                                   
            $status = Get-AzureRmVMExtension -ResourceGroupName $resourceGroup -VMName $vmName -Name $linuxscriptName     
               
        }
        
       
        if($os -eq "windows")
        {
            Set-AzureRmVMExtension -ResourceGroupName $resourceGroup -Location $location -VMName $vmName -Name $winscriptName -Publisher "Microsoft.Compute" -Type "CustomScriptExtension" `
                                   -TypeHandlerVersion 1.9 -Settings $winSettings -ProtectedSettings $winProtectedSettings
                                   
            $status = Get-AzureRmVMExtension -ResourceGroupName $resourceGroup -VMName $vmName -Name $winscriptName           
        }
       
        #Notification to slack
        $getdate = Get-Date
        
        if($status -ne "$null")
        {       
            if($status.ProvisioningState -eq "Succeeded")
            {
                Write-Host "'$scriptName' is successfully excuted @ '$vmName'. Just notificated to Slack channel!"
        
                $payload = 
                @{
                    "text" = "'$scriptName' is successfully excuted @ '$vmName' :) `n Status: Succeeded `n Time: $getdate"
                 }
 
                $webhook = Invoke-WebRequest -UseBasicParsing `
                    -Body (ConvertTo-Json -Compress -InputObject $payload) `
                    -Method Post `
                    -Uri "https://hooks.slack.com/services/**********************************"
            }
        
            else
            {
                Write-Host "'$scriptName' is failed to excute @ '$vmName'. Just notificated to Slack channel!"
        
                $payload = 
                @{
                    "text" = "'$scriptName' execution is failed :( `n Status: Failed `n Time: $getdate"
                 }
 
                 $webhook = Invoke-WebRequest -UseBasicParsing `
                    -Body (ConvertTo-Json -Compress -InputObject $payload) `
                    -Method Post `
                    -Uri "https://hooks.slack.com/services/**********************************"
            }
  
        }

    } -ArgumentList $csv.vmName, $csv.resourceGroup, $csv.location, $csv.os

}



#REMOVE VM EXTENSION
#Remove-AzureRmVMExtension -ResourceGroupName $resourceGroup -VMName $vmName -Name $scriptName


