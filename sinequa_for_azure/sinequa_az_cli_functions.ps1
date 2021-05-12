function SqAzureCLILogin($tenantId, $subscriptionId, $user, [securestring]$password) {
    <#
    .SYNOPSIS
        Login on Azure with login and password
    .PARAMETER tenantId
        Azuez Tenant Id
    .PARAMETER subscriptionId
        Azuez subscription Id
    .PARAMETER user
        User login
    .PARAMETER password
        User password
    #>
    if ($user.length -gt 0 -and $password.length -gt 0) 
    {
        az login -u "$user" -p "$password"
    }   
    WriteLog "Use Subscription ID: $subscriptionId"
    az account set --subscription $subscriptionId
}

