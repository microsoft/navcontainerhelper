<# 
 .Synopsis
  Replace navserver container with the same or a different image
 .Description
  This command is designed to be used in the Azure VMs, where the main container (mapped to public ip) is called navserver.
  Running this command will replace the container with a new container with a different (or the same) image.
 .Parameter imageName
  imageName you want to use to replace the navserver container (omit to recreate the same container)
 .Parameter alwaysPull
  Include this switch if you want to make sure that you pull latest version of the docker image
 .Parameter enableSymbolLoading
  Include this parameter if you want to change the enableSymbolLoading flag in the new container (default is to use the same setting as before)
 .Parameter includeCSIDE
  Include this parameter if you want to change the includeCSIDE flag in the new container (default is to use the same setting as before)
 .Parameter AadAccessToken
  Include this parameter if you want to change the AadAccessToken for the next deployment (accesstokens typically only have a lifetime of 1 hour)
 .Example
  Replace-NavServerContainer -imageName mcr.microsoft.com/dynamicsnav:2018
 .Example
  Replace-NavServerContainer -imageName mcr.microsoft.com/businesscentral/onprem:w1 -alwaysPull
 .Example
  Replace-NavServerContainer
#>
function Replace-NavServerContainer {
    Param(
        [string] $imageName = "",
        [switch] $alwaysPull,
        [ValidateSet('Yes','No','Default')]
        [string] $enableSymbolLoading = 'Default',
        [ValidateSet('Yes','No','Default')]
        [string] $includeCSIDE = 'Default',
        [string] $aadAccessToken
    )

    $SetupNavContainerScript = "C:\DEMO\SetupNavContainer.ps1"
    $setupDesktopScript = "C:\DEMO\SetupDesktop.ps1"
    $settingsScript = "C:\DEMO\settings.ps1"

    if (!((Test-Path $SetupNavContainerScript) -and (Test-Path $setupDesktopScript) -and (Test-Path $settingsScript))) {
        throw "The Replace-NavServerContainer is designed to work inside the ARM template VMs created by (ex. http://aka.ms/getbc)"
    }

    if ($enableSymbolLoading -ne "Default") {
        $settings = Get-Content -path $settingsScript | Where-Object { !$_.Startswith('$enableSymbolLoading = ') }
        $settings += ('$enableSymbolLoading = "'+$enableSymbolLoading+'"')
        Set-Content -Path $settingsScript -Value $settings
    }

    if ($includeCSIDE -ne "Default") {
        $settings = Get-Content -path $settingsScript | Where-Object { !$_.Startswith('$includeCSIDE = ') }
        $settings += ('$includeCSIDE = "'+$includeCSIDE+'"')
        Set-Content -Path $settingsScript -Value $settings
    }

    . $settingsScript

    if ($aadAccessToken) {
        $settings = Get-Content -path $settingsScript | Where-Object { !$_.Startswith('$Office365Password = ') }

        $secureOffice365Password = ConvertTo-SecureString -String $AadAccessToken -AsPlainText -Force
        $encOffice365Password = ConvertFrom-SecureString -SecureString $secureOffice365Password -Key $passwordKey
        $settings += ('$Office365Password = "'+$encOffice365Password+'"')
        Set-Content -Path $settingsScript -Value $settings
    
        . $settingsScript
    }

    if ("$imageName" -eq "") {
        $imageName = $navDockerImage.Split(',')[0]
    }
    if ("$imageName" -ne "$navDockerImage") {
        $settings = Get-Content -path $settingsScript | Where-Object { !$_.Startswith('$navDockerImage = ') }
        $settings += '$navDockerImage = "'+$imageName + '"'
        Set-Content -Path $settingsScript -Value $settings
    }

    $imageName = Get-BestNavContainerImageName -imageName $imageName
    if ($alwaysPull) {
        Write-Host "Pulling docker Image $imageName"
        docker pull $imageName
    }

    Write-Host -ForegroundColor Green "Setup new Container"
    . $SetupNavContainerScript
    . $setupDesktopScript
}
Set-Alias -Name Replace-BCServerContainer -Value Replace-NavServerContainer
Export-ModuleMember -Function Replace-NavServerContainer -Alias Replace-BCServerContainer
