function Get-NAVCumulativeUpdateDownloadVersionInfo
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String] $SourcePath

    )

    Begin
    {
    }
    Process
    {
        $ZipFileName = Get-NAVCumulativeUpdateFileName -FullPathToZip $SourcePath -Filter '*.zip'
        $ChangeLogFileName = Get-NAVCumulativeUpdateFileName -FullPathToZip $SourcePath -Filter '*ChangeLog*' -Subfolder 'APPLICATION' 
        
        
        $regex = '(?<product>\w+?)\.(?<version>\d+?)\.'
        $MatchedRegEx = [regex]::Match($ZipFileName, $regex)

        $ResultProduct = $MatchedRegEx.Groups.Item('product').value
        $ResultVersion = $MatchedRegEx.Groups.Item('version').value

        
        $regex = '(?<product>\w+?)\.(?<version>\d+?\.\d+?)\.(?<build>\d+?)\.(?<country>\w+?)\.'
        $MatchedRegEx = [regex]::Match($ZipFileName, $regex)
        
        $ResultBuild = $MatchedRegEx.Groups.Item('build').value
        $ResultCountry = $MatchedRegEx.Groups.Item('country').value        
                  
        if ([string]::IsNullOrEmpty($ResultCountry)){
            $ChangeLogFileName = $ChangeLogFileName | Where-Object {$_ -Like 'Changelog*'}
            $ChangeLogFileName = "$ChangeLogFileName.txt"
            $regex = 'ChangeLog.(?<country>\w+?)\.(?<build>\d+?)\.txt'
            $MatchedRegEx = [regex]::Match($ChangeLogFileName, $regex)
        
            $ResultBuild = $MatchedRegEx.Groups.Item('build').value
            $ResultCountry = $MatchedRegEx.Groups.Item('country').value        
        }

        if ([string]::IsNullOrEmpty($ResultCountry)){
            write-error "'$($MatchedRegEx.Groups.Item('version').value)' is not a known version.  It would be nice if Microsoft would actually apply some standard naming conventions here :-/"
        }        

        $VersionInfo = New-Object System.Object
        $VersionInfo | Add-Member -MemberType NoteProperty -Name Product -Value $ResultProduct
        $VersionInfo | Add-Member -MemberType NoteProperty -Name Version -Value $ResultVersion
        $VersionInfo | Add-Member -MemberType NoteProperty -Name Build -Value $ResultBuild
        $VersionInfo | Add-Member -MemberType NoteProperty -Name Country -Value $ResultCountry
        $VersionInfo | Add-Member -MemberType NoteProperty -Name ZipFileName -Value $ZipFileName
        $VersionInfo | Add-Member -MemberType NoteProperty -Name ChangeLogFileName -Value $ChangeLogFileName
    }
    End
    {
        $VersionInfo
    }
}