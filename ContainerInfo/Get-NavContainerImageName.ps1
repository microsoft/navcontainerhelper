<# 
 .Synopsis
  Get the name of the image used to run a Nav container
 .Description
  Get the name of the image used to run a Nav container
  The image name can be used to run a new instance of a Nav Container with the same version of Nav
 .Parameter containerName
  Name of the container for which you want to get the image name
 .Example
  $imageName = Get-NavContainerImageName -containerName navserver
  PS C:\>Docker run -e accept_eula=Y $imageName
#>
function Get-NavContainerImageName {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    Process {
        $inspect = docker inspect $containerName | ConvertFrom-Json
        return "$($inspect.Config.Image)"
    }
}
Export-ModuleMember -function Get-NavContainerImageName
