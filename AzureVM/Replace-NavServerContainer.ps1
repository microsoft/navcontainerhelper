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
 .Example
  Replace-NavServerContainer -imageName microsoft/dynamics-nav:devpreview-december-finus
 .Example
  Replace-NavServerContainer -imageName microsoft/dynamics-nav:devpreview-december-finus -alwaysPull
 .Example
  Replace-NavServerContainer
#>
function Replace-NavServerContainer {
    Param(
        [string] $imageName = "",
        [switch] $alwaysPull,
        [ValidateSet('Yes','No','Default')]
        [string] $enableSymbolLoading = 'Default'
    )

    $SetupNavContainerScript = "C:\DEMO\SetupNavContainer.ps1"
    $setupDesktopScript = "C:\DEMO\SetupDesktop.ps1"
    $settingsScript = "C:\DEMO\settings.ps1"

    if (!((Test-Path $SetupNavContainerScript) -and (Test-Path $setupDesktopScript) -and (Test-Path $settingsScript))) {
        throw "The Replace-NavServerContainer is designed to work inside the Nav on Azure DEMO VMs"
    }

    if ($enableSymbolLoading -ne "Default") {
        $settings = Get-Content -path $settingsScript | Where-Object { !$_.Startswith('$enableSymbolLoading = ') }
        $settings += ('$enableSymbolLoading = "'+$enableSymbolLoading+'"')
        Set-Content -Path $settingsScript -Value $settings
    }

    . $settingsScript

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

    Write-Host -ForegroundColor Green "Setup new Nav container"
    . $SetupNavContainerScript
    . $setupDesktopScript
}
Export-ModuleMember -Function Replace-NavServerContainer
