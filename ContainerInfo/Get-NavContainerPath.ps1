<# 
 .Synopsis
  Get the container file system path of a host file
 .Description
  Enumerates the shared folders with the container and returns the container file system path for a file shared with the container.
 .Parameter containerName
  Name of the container for which you want to find the filepath
 .Parameter path
  Path of a file in the host file system
 .Parameter throw
  Include the throw switch to throw an exception if the folder isn't shared with the container
 .Example
  $containerPath = Get-BcContainerPath -containerName bcserver -path c:\programdata\bccontainerhelper\extensions\test2\my
#>
function Get-BcContainerPath {
    [CmdletBinding()]
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $path,
        [switch] $throw
    )

    Process {
        $containerPath = ""
        if ($path.StartsWith(":")) {
            $path =$path.Substring(1)
            $exist = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($path)
                Test-Path $path
            } -ArgumentList $path
            if ($exist) {
                $containerPath = $path
            }
            if ($throw -and "$containerPath" -eq "") {
                throw "The path $path does not exist in the container $containerName"
            }
        } else {
            $sharedFolders = Get-BcContainerSharedFolders -containerName $containerName
            $sharedFolders.GetEnumerator() | ForEach-Object {
                $Name = $_.Name.TrimEnd('\')
                $Value = $_.Value.TrimEnd('\')
                if ($path -eq $Name -or ($containerPath -eq "" -and $path.StartsWith($Name+"\", "OrdinalIgnoreCase"))) {
                    $containerPath = ($Value + $path.Substring($Name.Length))
                }
            }
            if ($throw -and "$containerPath" -eq "") {
                throw "The path $path is not shared with the container $containerName (nor is any of it's parent folders)"
            }
        }
        return $containerPath
    }
}
Set-Alias -Name Get-NavContainerPath -Value Get-BcContainerPath
Export-ModuleMember -Function Get-BcContainerPath -Alias Get-NavContainerPath
