. (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')

$modulePath = Join-Path $PSScriptRoot "..\NavContainerHelper.psm1"
Remove-Module NavContainerHelper -ErrorAction Ignore
Import-Module $modulePath -DisableNameChecking

$credential = [PSCredential]::new("admin", (Get-RandomPasswordAsSecureString))

$bcImageName = Get-BestBCContainerImageName -ImageName "mcr.microsoft.com/businesscentral/onprem:1904-rtm-w1"
$bcContainerName = 'bc'
$bcContainerPlatformVersion = '14.0.29530.0'
$bcContainerPath = Join-Path "C:\ProgramData\NavContainerHelper\Extensions" $bcContainerName
$bcMyPath = Join-Path $bcContainerPath "my"
if (-not (Test-BcContainer -containerName $bcContainerName)) {
    New-BCContainer -accept_eula -accept_outdated -containerName $bcContainerName -imageName $bcImageName -auth NavUserPassword -Credential $credential -updateHosts
}
$navImageName = Get-BestBCContainerImageName -ImageName "mcr.microsoft.com/dynamicsnav:2018-cu17-w1"
$navContainerName = 'nav'
$navContainerPlatformVersion = ''
$navContainerPath = Join-Path "C:\ProgramData\NavContainerHelper\Extensions" $navContainerName
$navMyPath = Join-Path $navContainerPath "my"
if (-not (Test-NavContainer -containerName $navContainerName)) {
    New-NavContainer -accept_eula -accept_outdated -containerName $navContainerName -imageName $navImageName -auth NavUserPassword -Credential $credential -updateHosts
}
try {

. (Join-Path $PSScriptRoot "Api.ps1")
. (Join-Path $PSScriptRoot "AppHandling.ps1")
. (Join-Path $PSScriptRoot "AzureAD.ps1")
. (Join-Path $PSScriptRoot "AzureVM.ps1")
. (Join-Path $PSScriptRoot "Bacpac.ps1")
. (Join-Path $PSScriptRoot "CompanyHandling.ps1")
. (Join-Path $PSScriptRoot "ConfigPackageHandling.ps1")
. (Join-Path $PSScriptRoot "ContainerHandling.ps1")
. (Join-Path $PSScriptRoot "ContainerInfo.ps1")
. (Join-Path $PSScriptRoot "Misc.ps1")
. (Join-Path $PSScriptRoot "ObjectHandling.ps1")
. (Join-Path $PSScriptRoot "SymbolHandling.ps1")
. (Join-Path $PSScriptRoot "TenantHandling.ps1")
. (Join-Path $PSScriptRoot "UserHandling.ps1")

}
finally {
    Remove-BCContainer -containerName $bcContainerName
    Remove-NavContainer -containerName $navContainerName
}
