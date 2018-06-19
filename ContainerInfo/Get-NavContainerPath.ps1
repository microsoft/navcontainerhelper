<# 
 .Synopsis
  Get the container file system path of a host file
 .Description
  Enumerates the shared folders with the container and returns the container file system path for a file shared with the container.
 .Parameter containerName
  Name of the container for which you want to find the filepath
 .Parameter path
  Path of a file in the host file system
 .Example
  $containerPath = Get-NavContainerPath -containerName navserver -path c:\programdata\navcontainerhelper\extensions\test2\my
#>
function Get-NavContainerPath {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$true)]
        [string]$path,
        [switch]$throw
    )

    Process {
        $containerPath = ""
        if ($path.StartsWith(":")) {
            $path =$path.Substring(1)
            $session = Get-NavContainerSession -containerName $containerName -silent
            $exist = Invoke-Command -Session $session -ScriptBlock { Param($path)
                Test-Path $path
            } -ArgumentList $path
            if ($exist) {
                $containerPath = $path
            }
            if ($throw -and "$containerPath" -eq "") {
                throw "The path $path does not exist in the container $containerName"
            }
        } else {
            $sharedFolders = Get-NavContainerSharedFolders -containerName $containerName
            $sharedFolders.GetEnumerator() | ForEach-Object {
                if ($containerPath -eq "" -and ($path -eq $_.Name -or $path.StartsWith($_.Name+"\", "OrdinalIgnoreCase"))) {
                    $containerPath = ($_.Value + $path.Substring($_.Name.Length))
                }
            }
            if ($throw -and "$containerPath" -eq "") {
                throw "The path $path is not shared with the container $containerName (nor is any of it's parent folders)"
            }
        }
        return $containerPath
    }
}
Export-ModuleMember -function Get-NavContainerPath
