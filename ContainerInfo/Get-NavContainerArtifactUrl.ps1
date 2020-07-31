<# 
 .Synopsis
  Get the artifactUrl used to run a NAV/BC Container (or blank if artifacts wasn't used)
 .Description
  Get the artifactUrl used to run a NAV/BC Container (or blank if artifacts wasn't used)
  The artifactUrl can be used to run a new instance of a Container with the same version of NAV/BC
 .Parameter containerName
  Name of the container for which you want to get the image name
 .Example
  $artifactUrl = Get-BcContainerArtifactUrl -containerName navserver
  PS C:\>New-BcContainer -accept_eula -artifactUrl $artifactUrl -containerName test
#>
function Get-BcContainerArtifactUrl {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName
    )

    Process {
        $inspect = docker inspect $containerName | ConvertFrom-Json
        $artifactUrlEnv = $inspect.config.Env | Where-Object { $_ -like "artifactUrl=*" }
        if ($artifactUrlEnv) {
            return $artifactUrlEnv.SubString("artifactUrl=".Length)
        }
        else {
            return ""
        }
    }
}
Set-Alias -Name Get-NavContainerArtifactUrl -Value Get-BcContainerArtifactUrl
Export-ModuleMember -Function Get-BcContainerArtifactUrl -Alias Get-NavContainerArtifactUrl
