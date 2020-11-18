Describe 'ContainerInfo' {

    It 'Get-BcContainerCountry' {
        Get-BcContainerCountry -containerOrImageName $bcContainerName | Should -Be "W1"
        Get-BcContainerCountry -containerOrImageName $bcImageName | Should -Be "W1"
    }
    It 'Get-BcContainerDebugInfo' {
        $json = Get-BcContainerDebugInfo -containerName $bcContainerName | ConvertFrom-Json
        $json.'container.labels'.country | Should -Be "W1"
    }
    It 'Get-BcContainerEula' {
        Get-BcContainerEula -containerOrImageName $bcContainerName | Should -BeLike 'http*'
        Get-BcContainerEula -containerOrImageName $bcImageName | Should -BeLike 'http*'
    }
    It 'Get-BcContainerEventLog' {
        Get-BcContainerEventLog -containerName $bcContainerName -doNotOpen
        (Join-Path $bcMyPath "*.evtx") | should -Exist
    }
    It 'Get-BcContainerGenericTag' {
        ([System.Version](Get-BcContainerGenericTag -containerOrImageName $bcContainerName)) | Should -BeOfType [System.Version]
        ([System.Version](Get-BcContainerGenericTag -containerOrImageName $bcImageName)) | Should -BeOfType [System.Version]
    }
    It 'Get-BcContainerId' {
        $containerId = Get-BcContainerId -containerName $bcContainerName
        $json = docker inspect $containerId | ConvertFrom-Json
        $json.Config.Hostname | Should -be $bcContainerName
    }
    It 'Get-BcContainerImageLabels' {
        (Get-BCContainerImageLabels -imageName $bcImageName).platform | Should -Be $bcContainerPlatformVersion
    }
    It 'Get-BCContainerImageName' {
#        Get-BCContainerImageName -containerName $bcContainerName | Should -Be $bcImageName
    }
    It 'Get-BcContainerImageTags' {
        $imageTags = get-bccontainerImageTags -imageName mcr.microsoft.com/businesscentral
        if ($imageTags) {
            ($imageTags.Tags | Where-Object { $_.startsWith('10.0') }).Count | Should -BeGreaterThan 100
        }
        else {
            Set-ItResult -Inconclusive -Because 'Downloading generic image tags from mcr.microsoft.com/businesscentral failed'
        }
    }
    It 'Get-BcContainerIpAddress' {
        $ip = Get-BcContainerIpAddress -containerName $bcContainerName
        (Resolve-DnsName -Name $bcContainerName -Type A).IPAddress | Should -Be $ip
    }
    It 'Get-BcContainerLegal' {
        Get-BcContainerLegal -containerOrImageName $bcImageName | Should -BeLike 'http*'
    }
    It 'Get-BcContainerName' {
        $json = docker inspect $bcContainerName | ConvertFrom-Json
        Get-BcContainerName -containerId $json.ID | Should -Be $bcContainerName
    }
    It 'Get-BcContainerNavVersion' {
        $version = Get-BcContainerNavVersion -containerOrImageName $bcContainerName
        Get-BcContainerNavVersion -containerOrImageName $bcImageName | Should -Be $version
    }
    It 'Get-BcContainerOsVersion' {
#        $osVersion = Get-BcContainerOsVersion -containerOrImageName $bcImageName
#        $version = [Version]$OsVersion
#        Get-BcContainerOsVersion -containerOrImageName $bcContainerName | Should -be "$version"
    }
    It 'Get-BcContainerPath' {
        Get-BcContainerPath -containerName $bcContainerName -path $bcMyPath | Should -Be "c:\run\my"
    }
    It 'Get-BcContainerPlatformVersion' {
        Get-BcContainerPlatformVersion -containerOrImageName $bcContainerName | Should -Be $bcContainerPlatformVersion
        Get-BcContainerPlatformVersion -containerOrImageName $bcImageName | Should -Be $bcContainerPlatformVersion
        #Get-BcContainerPlatformVersion -containerOrImageName $navContainerName | Should -Be $navContainerPlatformVersion
        Get-BcContainerPlatformVersion -containerOrImageName $navImageName | Should -Be $navContainerPlatformVersion

    }
    It 'Get-BcContainers' {
        (Get-BcContainers).Count | Should -BeGreaterOrEqual 2
    }
    It 'Get-BcContainerServerConfiguration' {
        $config = Get-BCContainerServerConfiguration -ContainerName $bcContainerName
        $config.DatabaseServer | Should -Be 'localhost'
    }
    It 'Get-BcContainerSharedFolders' {
        $sharedFolders = Get-BcContainerSharedFolders -containerName $bcContainerName
        $hostMyPath = foreach ($Key in ($sharedFolders.GetEnumerator() | Where-Object {$_.Value -eq "c:\run\my"})) { $Key.name }
        $hostMyPath | Should -Be $bcMyPath
    }
    It 'Test-BcContainer' {
        Test-BcContainer -containerName $bcContainerName | Should -Be $true
        Test-BcContainer -containerName 'xxx' | Should -Be $false
    }
}
