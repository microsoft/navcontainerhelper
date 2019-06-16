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
        Remove-Item -Path $filename
    }
    It 'Copy-FileToNavContainer' {
        $filename = Join-Path 'c:\' ([Guid]::NewGuid().Guid)
        Copy-FileToBCContainer -containerName $bcContainerName -localPath "C:\Windows\Win.ini" -containerPath $filename
        $exists = Invoke-ScriptInBCContainer -containerName $bcContainerName -scriptblock { Param($filename)
            Test-Path $filename -PathType Leaf
            Remove-Item -Path $filename
        } -argumentList $filename
        $exists | Should -Be $true
    }
    It 'Download-File' {
        #TODO
    }
    It 'Get-LocaleFromCountry' {
        Get-LocaleFromCountry -country DK | Should -Be 'da-DK'
    }
    It 'Get-NavVersionFromVersionInfo' {
        Get-NavVersionFromVersionInfo -versionInfo '11.0.23400.0' | Should -Be '2018'
        Get-NavVersionFromVersionInfo -versionInfo '13.0.12345.0' | Should -Be ''
    }
    It 'Import-PfxCertificateToNavContainer' {
        #TODO
    }
    It 'New/Remove-DesktopShortcut' {
        New-DesktopShortcut -Name 'mynotepad' -TargetPath 'c:\windows\notepad.exe' -shortcuts Desktop
        Join-Path ([Environment]::GetFolderPath('Desktop')) 'mynotepad.lnk' | Should -Exist
        Remove-DesktopShortcut -Name 'mynotepad'
        Join-Path ([Environment]::GetFolderPath('Desktop')) 'mynotepad.lnk' | Should -Not -Exist
    }
    It 'Write-NavContainerHelperWelcomeText' {
        #TODO
    }

}
