<#   
================================================================================ 
 Name: Create_SPN.ps1 
 Purpose: Service Principal Credential Creation 
 Author: molee
 Description: This script is for creating Azure Service Principal Credential
 Limitations/Prerequisite:
    * Replace *(Star) with your information
    * Login with the credential(txt file) you create
    * Must Run PowerShell (or ISE)  
    * Requires PowerShell Azure Module
 ================================================================================ 
#>


# 1. Login Azure account
Login-AzAccount

# Select  subscr
$subscription = Get-AzureRmSubscription
Write-Host "Your Subscriptions is"

for ($i=1; $i -lt $subscription.Count + 1; $i++) {
    $i.ToString() + ". [ " + $subscription[$i - 1].Name + " ]"
}

Write-Host ""

## Select Subscription
while($true) {
    try {
        Write-Host "Select Your Subscritpion for use"
        [int]$selectSub = Read-Host
        ## -1, -2, 0 등 0이하 정수를 입력해도 이상하게 구독이 읽어져서 추가한 코드
        if ($selectSub -le 0) {
            $selectSub = 10000
        }
        Select-AzureRmSubscription -Subscription $subscription.Id[$selectSub - 1] `
                                    -TenantId $subscription.TenantId[$selectSub - 1] `
                                    -Name $subscription.Name[$selectSub - 1]
        break
    } catch [System.Exception] {
        Write-Host "Wrong Selection !!" -ForegroundColor Red
        #Write-Host $_.Exception.GetType().FullName -ForegroundColor Red
        #Write-Host $_.Exception.Message -ForegroundColor Red
        #Write-Host ""
    }
}

# 2. Create Azure AD Application After Setting the AD app credential / Info.
Add-Type -Assembly System.Web
$password = [System.Web.Security.Membership]::GeneratePassword(16,3)
$securepassword = $password | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File "~\LoginCred.txt"
$securepassword = $password | ConvertTo-SecureString -AsPlainText -Force

$spn = "SPN_Login"
$homepage = "http://localhost/$spn"
$identifierUri = $homepage

$azureAdApplication = New-AzureRmADApplication -DisplayName $spn -IdentifierUris $identifierUri -Password $securepassword 

# Set Ad app id just made
$appid = $azureAdApplication.ApplicationId

# 3. Create a AD SP with the AD app
$azurespn = New-AzureRmADServicePrincipal -ApplicationId $appid

# Set AD SP info.
$spnname = $azurespn.ServicePrincipalNames
$spnRole = "Contributor"

# 4. Create a SP Role
New-AzureRmRoleAssignment -RoleDefinitionName $spnRole -ServicePrincipalName $appId

$cred = New-object System.Management.Automation.PSCredential($appId.Guid, $securepassword)

#Login using SPN with (App ID / App PW)
#Add-AzureRmAccount -Credential $cred -TenantId $id.TenantId -ServicePrincipal
