function Unzip-NAVCumulativeUpdateChangedObjects
{
    [CmdletBinding()]
    Param
    (
        # The full source-filepath of the file that should be unzipped
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)]
        [Alias('Fullname')] 
        $SourcePath,

        # The full Destionation-path where it should be unzipped
        [String]
        $DestinationPath,
        [Parameter(Mandatory=$true)]
        [ValidateSet('txt','fob')]
        $Type
    )
    process
    {
        Write-host "Unzipping Objects-file from $SourcePath to $DestinationPath" -ForegroundColor Green

        if (-not (Test-Path $DestinationPath)){
            $null = New-Item -Path $DestinationPath -ItemType directory
        }
        $null = Unblock-File $DestinationPath 
        try{
            $SourcePathZip = [io.path]::ChangeExtension($SourcePath,'zip')
            $null = Rename-Item $SourcePath $SourcePathZip

            $CUObjectsSourcePath = join-path $SourcePathZip 'APPLICATION'

            $helper = New-Object -ComObject Shell.Application
            $files = $helper.NameSpace($CUObjectsSourcePath).Items()

            $CUObjectFile = $files | where path -like "*CUObjects*.$Type"

            $resultfile = Join-Path $DestinationPath $CUObjectFile.Name

            $helper.NameSpace($DestinationPath).CopyHere($CUObjectFile, 0x14) | Out-Null
        }
        finally {
            if ($SourcePath -ne $SourcePathZip) {
                $null = Rename-Item $SourcePathZip $SourcePath
            }
        }

        Write-host "Created $resultfile" -ForegroundColor Green
        Get-Item $resultfile
    }
   }
