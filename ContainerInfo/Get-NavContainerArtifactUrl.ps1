<# 
 .Synopsis
  Get the artifactUrl used to run a NAV/BC Container (or blank if artifacts wasn't used)
 .Description
  Get the artifactUrl used to run a NAV/BC Container (or blank if artifacts wasn't used)
  The artifactUrl can be used to run a new instance of a Container with the same version of NAV/BC
 .Parameter containerName
  Name of the container for which you want to get the image name
 .Example
  $artifactUrl = Get-NavContainerArtifactUrl -containerName navserver
  PS C:\>New-NavContainer -accept_eula -artifactUrl $artifactUrl -containerName test
#>
function Get-NavContainerArtifactUrl {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string] $containerName
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
Set-Alias -Name Get-BCContainerArtifactUrl -Value Get-NavContainerArtifactUrl
Export-ModuleMember -Function Get-NavContainerArtifactUrl -Alias Get-BCContainerArtifactUrl
