﻿Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    . (Join-Path $PSScriptRoot '_CreateBcContainer.ps1')
}

AfterAll {
    . (Join-Path $PSScriptRoot '_RemoveBcContainer.ps1')
}

Describe 'Misc' {

    It 'Add-FontsToBcContainer' {
        $noOfFonts = Invoke-ScriptInBCContainer -containerName $bcContainerName -scriptblock { (Get-ChildItem -Path "c:\windows\fonts").Count }
        Add-FontsToBCContainer -containerName $bcContainerName -path (Join-Path (Join-Path $env:windir 'fonts') 'wingding.ttf')
        Invoke-ScriptInBCContainer -containerName $bcContainerName -scriptblock { (Get-ChildItem -Path "c:\windows\fonts").Count } | Should -BeGreaterThan $noOfFonts
    }
    It 'Copy-FileFromBcContainer' {
        $filename = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
        Copy-FileFromBCContainer -containerName $bcContainerName -containerPath "c:\windows\win.ini" -localPath $filename
        $filename | Should -Exist
        Remove-Item -Path $filename
    }
    It 'Copy-FileToBcContainer' {
        $filename = Join-Path 'c:\' ([Guid]::NewGuid().Guid)
        Copy-FileToBCContainer -containerName $bcContainerName -localPath "C:\Windows\Win.ini" -containerPath $filename
        $exists = Invoke-ScriptInBCContainer -containerName $bcContainerName -scriptblock { Param($filename)
            Test-Path $filename -PathType Leaf
            Remove-Item -Path $filename
        } -argumentList $filename
        $exists | Should -Be $true
    }
    It 'Get-BcArtifactUrl' {
        (Get-BCArtifactUrl -country "us").Startswith('https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/sandbox/') | Should -Be $true
        (Get-BCArtifactUrl -type OnPrem -select all).Count | Should -BeGreaterThan 3000
        Get-BCArtifactUrl -country "us" -version '16.2.13509.13700' -select Closest | Should -Be (Get-BCArtifactUrl -country "us" -version '16.2.13509.31578')
    }
    It 'Get-NavArtifactUrl' {
        (Get-NavArtifactUrl -nav 2017 -country 'dk' -select all).count | Should -BeGreaterThan 43
        Get-NavArtifactUrl -nav 2018 -cu 30 -country de | Should -Be 'https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/onprem/11.0.43274.0/de'
    }
    It 'Download-File' {
        #TODO
    }
    It 'Get-LocaleFromCountry' {
        Get-LocaleFromCountry -country DK | Should -Be 'da-DK'
    }
    It 'Get-NavVersionFromVersionInfo' {
        Get-NavVersionFromVersionInfo -versionInfo '11.0.23400.0' | Should -Be '2018'
        Get-NavVersionFromVersionInfo -versionInfo '13.0.12345.0' | Should -Be $null
    }
    It 'Import-PfxCertificateToBcContainer' {
        #TODO
    }
    It 'New/Remove-DesktopShortcut' {
# SYSTEM doesn't have a desktop - TODO use other
#        New-DesktopShortcut -Name 'mynotepad' -TargetPath 'c:\windows\notepad.exe' -shortcuts Desktop
#        Join-Path ([Environment]::GetFolderPath('Desktop')) 'mynotepad.lnk' | Should -Exist
#        Remove-DesktopShortcut -Name 'mynotepad'
#        Join-Path ([Environment]::GetFolderPath('Desktop')) 'mynotepad.lnk' | Should -Not -Exist
    }
    It 'Write-BcContainerHelperWelcomeText' {
        #TODO
    }

}
