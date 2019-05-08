<# 
 .Synopsis
  Download Nav App Runtime Package from Container
 .Description
  Downloads a Nav App runtime package to a shared folder and returns the filename of the app
 .Parameter containerName
  Name of the container from which you want to download a runtime package
 .Parameter appName
  Name of the app for which you want to download a runtime package
 .Parameter appVersion
  Version of the app for which you want to download a runtime package
 .Parameter tenant
  Tenant from which you want to download a runtime package
 .Parameter appFile
  Path to the location where you want the runtime package to be copied
 .Example
  $appFile = Get-NavContainerAppRuntimePackage -containerName test -appName "Image Analyzer"
#>
function Get-NavContainerAppRuntimePackage {
    Param(
        [string]$containerName = "navserver",
        [string]$appName,
        [Parameter(Mandatory=$false)]
        [string]$appVersion,
        [Parameter(Mandatory=$false)]
        [string]$Tenant,
        [Parameter(Mandatory=$false)]
        [string]$appFile = (Join-Path $extensionsFolder "$containerName\$appName.app")
    )

    $containerAppFile = Get-NavContainerPath -containerName $containerName -path $appFile
    if ("$containerAppFile" -eq "") {
        throw "The app filename ($appFile)needs to be in a folder, which is shared with the container $containerName"
    }

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($appName, $appVersion, $tenant, $appFile)

        $parameters = @{ 
            "ServerInstance" = "NAV"
            "Name" = $appName
            "Path" = $appFile
        }
        if ($appVersion)
        {
            $parameters += @{ "Version" = $appVersion }
        }
        if ($tenant)
        {
            $parameters += @{ "Tenant" = $tenant }
        }

        Get-NavAppRuntimePackage @parameters

        $appFile

    } -ArgumentList $appName, $appVersion, $tenant, $appFile
}
Export-ModuleMember -Function Get-NavContainerAppRuntimePackage
