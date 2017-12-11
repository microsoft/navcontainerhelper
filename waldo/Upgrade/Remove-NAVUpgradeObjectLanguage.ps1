Function Remove-NAVUpgradeObjectLanguage
{
    [CmdLetBinding()]
    param(
        [String] $Source,
        [String] $WorkingFolder,
        [String[]] $Languages
    )
    
    $FileObject = get-item $Source -ErrorAction Stop
    $ObjectsWithoutLanguages = (join-path $WorkingFolder "$($FileObject.BaseName)_WithoutLanguages.txt")    $LanguagesFolder = (Join-Path $WorkingFolder 'Languages')    write-host "Removing languages ($($Languages -join ', ')) from $Source" -ForegroundColor Green    if (!(Test-Path $LanguagesFolder)){        $null = New-Item -Path $LanguagesFolder -ItemType directory    }    foreach ($Language in $Languages){        $LanguageFile = (Join-Path $LanguagesFolder "$($FileObject.BaseName)_$($Language).txt")        Export-NAVApplicationObjectLanguage `            -Source $Source `            -Destination $LanguageFile `            -LanguageId $Language `            -Encoding UTF8    }        Remove-NAVApplicationObjectLanguage `        -Source $Source `        -Destination $ObjectsWithoutLanguages `        -LanguageId $Languages    

        
    return $ObjectsWithoutLanguages    
}