Describe 'Misc' {

    It 'Add-FontsToNavContainer' {
        $noOfFonts = Invoke-ScriptInBCContainer -containerName $bcContainerName -scriptblock { (Get-ChildItem -Path "c:\windows\fonts").Count }
        Add-FontsToBCContainer -containerName $bcContainerName -path (Join-Path (Join-Path $env:windir 'fonts') 'wingding.ttf')
        Invoke-ScriptInBCContainer -containerName $bcContainerName -scriptblock { (Get-ChildItem -Path "c:\windows\fonts").Count } | Should -BeGreaterThan $noOfFonts
    }
    It 'Copy-FileFromNavContainer' {
        $filename = Join-Path $env:TEMP ([Guid]::NewGuid().Guid)
        Copy-FileFromBCContainer -containerName $bcContainerName -containerPath "c:\windows\win.ini" -localPath $filename
        $filename | Should -Exist
    }
    It 'Copy-FileToNavContainer' {
        Copy-FileToBCContainer -containerName $bcContainerName -localPath "C:\Windows\Win.ini" -containerPath 'c:\run\my\win.ini'
        (Join-Path -Path $bcMyPath 'win.ini') | Should -Exist
    }
    It 'Download-File' {
        #TODO
    }
    It 'Get-LocaleFromCountry' {
        Get-LocaleFromCountry -country DK | Should -Be 'da-DK'
    }
    It 'Get-NavVersionFromVersionInfo' {
        #TODO
    }
    It 'Import-PfxCertificateToNavContainer' {
        #TODO
    }
    It 'New-DesktopShortcut' {
        New-DesktopShortcut -Name 'mynotepad' -TargetPath 'c:\windows\notepad.exe' -shortcuts Desktop
        Join-Path ([Environment]::GetFolderPath('Desktop')) 'mynotepad.lnk' | Should -Exist
    }
    It 'Remove-DesktopShortcut' {
        Remove-DesktopShortcut -Name 'mynotepad'
        Join-Path ([Environment]::GetFolderPath('Desktop')) 'mynotepad.lnk' | Should -Not -Exist
    }
    It 'Write-NavContainerHelperWelcomeText' {
        #TODO
    }

}
