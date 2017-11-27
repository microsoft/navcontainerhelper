$imageName = "microsoft/dynamics-nav:devpreview"
$imageName2 = "microsoft/dynamics-nav:devpreview-finus"

#$imageName = "navdocker.azurecr.io/dynamics-nav:11.0.19378.0"
#$imageName2 = "navdocker.azurecr.io/dynamics-nav:11.0.19378.0-finus"

$licenseFile = "c:\programdata\navcontainerhelper\license.flf"
if (!(Test-Path $licenseFile)) {
    throw "License file must be in $licenseFile to run test"
}

if ($credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
    $credential = Get-Credential -Username $env:USERNAME -Message "Enter a set of credentials to use for containers in the tests"
}
$sqlCredential = New-Object System.Management.Automation.PSCredential ('sa', $credential.Password)

docker pull $imageName
docker pull $imageName2
