function New-NAVCumulativeUpdateISOFile
{
    <#
        .SYNOPSIS
        Creates an ISO file from a cumulative Update Download exe
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [System.String]
        $CumulativeUpdateFullPath,
        
        [Parameter(Mandatory=$false, Position=1)]
        [System.String]
        $TmpLocation = 'C:\Temp',
        
        [Parameter(Mandatory=$true, Position=2)]
        [System.String]
        $IsoDirectory,

        [Parameter(Mandatory=$false, Position=3)]
        [Switch]
        $Force,

        [Parameter(Mandatory=$false, Position=4)]
        [String] $FileNameSuffix

    )
    
    #Create Templocation is if doesn't exist yet
    IF (Test-Path $TmpLocation){        
        if (!($Force)){
            Start $TmpLocation
            if ((Confirm-YesOrNo -title "Remove $TmpLocation ?" -message "$TmpLocation already exists. Remove?") -ieq 'y') {
                $null = Remove-Item $TmpLocation -Recurse -Force 
            } else {
                Write-Host 'Operation aborted.'
                break
            }  
        } else {
            $null = Remove-Item $TmpLocation -Recurse -Force 
        }
    }
    $null = New-Item -ItemType directory -Path $TmpLocation 
    
    #Unzip the CU
    $DVDPath = Unzip-NAVCumulativeUpdateDownload -SourcePath $CumulativeUpdateFullPath -DestinationPath $TmpLocation 
    
    #Get Version info from the zipfile
    $VersionInfo = Get-NAVCumulativeUpdateDownloadVersionInfo -SourcePath $CumulativeUpdateFullPath
    
    #Create the ISO
    $ISOName = "$($VersionInfo.Product)_$($VersionInfo.Version)_$($VersionInfo.Build)_$($VersionInfo.Country)_$FileNameSuffix"
    $IsoFileName = Join-Path $ISODirectory "$ISOName.iso"
    $null = New-ISOFileFromFolder -FilePath $DVDPath -Name $ISOName -ResultFullFileName $IsoFileName

    $null = Remove-Item $TmpLocation -Recurse -Force -ErrorAction SilentlyContinue

    return (Get-Item $IsoFileName)
}

