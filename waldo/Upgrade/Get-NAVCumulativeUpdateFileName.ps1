function Get-NAVCumulativeUpdateFileName
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String] $FullPathToZip,
        [Parameter(Mandatory=$false)]
        [String] $Subfolder='',
        [Parameter(Mandatory=$true)]
        [String] $Filter
    )
    
    $SourcePathZip = [io.path]::ChangeExtension($FullPathToZip,'zip')
    Rename-Item $FullPathToZip $SourcePathZip
    
    try {
        $SourcePath = join-path $SourcePathZip $Subfolder

        $helper = New-Object -ComObject Shell.Application
        $files = $helper.NameSpace($SourcePath).Items()
        $filename = ($files | where path -like $Filter).name

    } finally {
        if ($FullPathToZip -ne $SourcePathZip) {
            Rename-Item $SourcePathZip $FullPathToZip
        }
    }
    


    return $filename
}

