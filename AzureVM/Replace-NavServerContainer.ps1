<# 
 .Synopsis
  Replace bcserver container with the same or a different image
 .Description
  This command is designed to be used in the Azure VMs, where the main container (mapped to public ip) is called bcserver.
  Running this command will replace the container with a new container with a different (or the same) image.
 .Parameter imageName
  imageName you want to use to replace the bcserver container (omit to recreate the same container)
 .Parameter alwaysPull
  Include this switch if you want to make sure that you pull latest version of the docker image
 .Parameter enableSymbolLoading
  Include this parameter if you want to change the enableSymbolLoading flag in the new container (default is to use the same setting as before)
 .Parameter includeCSIDE
  Include this parameter if you want to change the includeCSIDE flag in the new container (default is to use the same setting as before)
 .Parameter AadAccessToken
  Include this parameter if you want to change the AadAccessToken for the next deployment (accesstokens typically only have a lifetime of 1 hour)
 .Example
  Replace-NavServerContainer -imageName myimage:mytag
 .Example
  Replace-NavServerContainer -artifactUrl (Get-BcArtifactUrl -type onprem -country w1 -select latest)
 .Example
  Replace-NavServerContainer
#>
function Replace-BcServerContainer {
    Param (
        [string] $artifactUrl = "",
        [string] $imageName = "",
        [switch] $alwaysPull,
        [ValidateSet('Yes','No','Default')]
        [string] $enableSymbolLoading = 'Default',
        [ValidateSet('Yes','No','Default')]
        [string] $includeCSIDE = 'Default',
        [string] $aadAccessToken,
        [hashtable] $bcAuthContext
    )

    $SetupBcContainerScript = "C:\DEMO\Setup*Container.ps1"
    $setupDesktopScript = "C:\DEMO\SetupDesktop.ps1"
    $settingsScript = "C:\DEMO\settings.ps1"

    if (!((Test-Path $SetupBcContainerScript) -and (Test-Path $setupDesktopScript) -and (Test-Path $settingsScript))) {
        throw "The Replace-NavServerContainer is designed to work inside the ARM template VMs created by (ex. http://aka.ms/getbc)"
    }

    if ($artifactUrl -ne "" -and $imageName -ne "") {
        throw "You cannot call Replace-NavServerContainer with artifactUrl AND imageName"
    }

    $SetupBcContainerScript = (Get-Item $SetupBcContainerScript).FullName

    $newArtifactUrl = $artifactUrl
    Remove-Variable -Name 'artifactUrl'

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

    if ($bcAuthContext) {
        $bcAuthContext = Renew-BcAuthContext -bcAuthContext $bcAuthContext
        $jwtToken = Parse-JWTtoken -token $bcAuthContext.accessToken
        if ($jwtToken.aud -ne 'https://graph.windows.net') {
            Write-Host -ForegroundColor Yellow "The accesstoken was provided for $($jwtToken.aud), should have been for https://graph.windows.net"
        }
        $aadAccessToken = $bcAuthContext.AccessToken
    }

    if ($aadAccessToken) {
        $settings = Get-Content -path $settingsScript | Where-Object { !$_.Startswith('$Office365Password = ') }

        $secureOffice365Password = ConvertTo-SecureString -String $AadAccessToken -AsPlainText -Force
        $encOffice365Password = ConvertFrom-SecureString -SecureString $secureOffice365Password -Key $passwordKey
        $settings += ('$Office365Password = "'+$encOffice365Password+'"')
        Set-Content -Path $settingsScript -Value $settings
    
        . $settingsScript
    }

    $artifactUrlRef = get-variable -Name artifactUrl -ErrorAction SilentlyContinue
    if (-not ($artifactUrlRef)) { $artifactUrl = "" }

    if ($newArtifactUrl) {
        if ($newArtifactUrl -ne $artifactUrl) {
            $settings = Get-Content -path $settingsScript | Where-Object { ($_.Trim() -notlike '$navDockerImage = *') -and ($_.Trim() -notlike '$artifactUrl = *') }
            $settings += '$navDockerImage = ""'
            $settings += '$artifactUrl = "'+$newArtifactUrl+'"'
            Set-Content -Path $settingsScript -Value $settings
        }
    }
    elseif ($imageName) {
        if ("$imageName" -ne "$navDockerImage") {
            $settings = Get-Content -path $settingsScript | Where-Object { ($_.Trim() -notlike '$navDockerImage = *') -and ($_.Trim() -notlike '$artifactUrl = *') }
            $settings += '$navDockerImage = "'+$imageName + '"'
            $settings += '$artifactUrl = ""'
            Set-Content -Path $settingsScript -Value $settings
        }
        $imageName = Get-BestBcContainerImageName -imageName $imageName
        if ($alwaysPull) {
            Write-Host "Pulling docker Image $imageName"
            docker pull $imageName
        }
    }
    elseif ($navDockerImage) {
        $imageName = $navDockerImage.Split(',')[0]
        $imageName = Get-BestBcContainerImageName -imageName $imageName
        if ($alwaysPull) {
            Write-Host "Pulling docker Image $imageName"
            docker pull $imageName
        }
    }

    Write-Host -ForegroundColor Green "Setup new Container"
    . $SetupBcContainerScript
    . $setupDesktopScript
}
Set-Alias -Name Replace-NavServerContainer -Value Replace-BcServerContainer
Export-ModuleMember -Function Replace-BcServerContainer -Alias Replace-NavServerContainer
