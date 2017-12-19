<# 
 .Synopsis
  Replace navserver container with the same or a different image
 .Description
  This command is designed to be used in the Azure VMs, where the main container (mapped to public ip) is called navserver.
  Running this command will replace the container with a new container with a different (or the same) image.
 .Parameter imageName
  imageName you want to use to replace the navserver container (omit to recreate the same container)
 .Example
  Replace-NavServerContainer -imageName microsoft/dynamics-nav:devpreview-december-finus
 .Example
  Replace-NavServerContainer
#>
function Replace-NavServerContainer {
    Param(
        [string]$imageName = ""
    )

    $SetupNavContainerScript = "C:\DEMO\SetupNavContainer.ps1"
    $setupDesktopScript = "C:\DEMO\SetupDesktop.ps1"
    $settingsScript = "C:\DEMO\settings.ps1"

    if (!((Test-Path $SetupNavContainerScript) -and (Test-Path $setupDesktopScript) -and (Test-Path $settingsScript))) {
        throw "The Replace-NavServerContainer is designed to work inside the Nav on Azure DEMO VMs"
    }

    if ("$imageName" -ne "") {
        ('$navDockerImage = "'+$imageName + '"') | Add-Content $settingsScript
    }

    Write-Host -ForegroundColor Green "Setup new Nav container"
    . $SetupNavContainerScript
    . $setupDesktopScript
}
Export-ModuleMember -Function Replace-NavServerContainer
