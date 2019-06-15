. (Join-Path $PSScriptRoot 'HelperFunctions.ps1')

$modulePath = Join-Path $PSScriptRoot "..\..\NavContainerHelper.psd1"
Import-Module $modulePath -DisableNameChecking

Describe 'Pester Tests' {
    
    Context 'Info functions' {

        $imageName = Get-BestBCContainerImageName -ImageName "mcr.microsoft.com/businesscentral/onprem:1904-rtm-w1"
        $containerName = "test"
        $containerPath = Join-Path "C:\ProgramData\NavContainerHelper\Extensions" $containerName
        $myPath = Join-Path $containerPath "my"
        $credential = [PSCredential]::new("admin", (Get-RandomPasswordAsSecureString))

        New-BCContainer -accept_eula -accept_outdated -containerName $containerName -imageName $imageName -auth NavUserPassword -Credential $credential -updateHosts

        It 'Get-BcContainerCountry' {
            Get-BcContainerCountry -containerOrImageName $containerName | Should -Be "W1"
            Get-BcContainerCountry -containerOrImageName $imageName | Should -Be "W1"
        }
        It 'Get-BcContainerEula' {
            Get-BcContainerEula -containerOrImageName $containerName | Should -BeLike 'http*'
            Get-BcContainerEula -containerOrImageName $imageName | Should -BeLike 'http*'
        }
        It 'Get-BcContainerGenericTag' {
            ([System.Version](Get-BcContainerGenericTag -containerOrImageName $containerName)) | Should -BeOfType [System.Version]
            ([System.Version](Get-BcContainerGenericTag -containerOrImageName $imageName)) | Should -BeOfType [System.Version]
        }
        It 'Get-BcContainerEventLog' {
            Get-BcContainerEventLog -containerName $containerName -doNotOpen
            (Join-Path $myPath "*.evtx") | should -Exist
        }
        It 'Get-BcContainerId+Get-BcContainerName' {
            $containerId = Get-BcContainerId -containerName $containerName
            Get-BcContainerName -containerId $containerId | Should -Be $containerName
        }
        It 'Get-BCContainerImageName' {
            Get-BCContainerImageName -containerName $containerName | Should -Be $imageName
        }
        It 'Get-BcContainerIpAddress' {
            $ip = Get-BcContainerIpAddress -containerName $containerName
            (Resolve-DnsName -Name $containerName -Type A).IPAddress | Should -Be $ip
        }
        It 'Get-BcContainerSharedFolders' {
            $sharedFolders = Get-BcContainerSharedFolders -containerName $containerName
            $hostMyPath = foreach ($Key in ($sharedFolders.GetEnumerator() | Where-Object {$_.Value -eq "c:\run\my"})) { $Key.name }
            $hostMyPath | Should -Be $myPath
        }
        It 'Get-BcContainerNavVersion' {
            $version = Get-NavContainerNavVersion -containerOrImageName $containerName
            $image2 = Get-BestBCContainerImageName -imageName ($imageName.subString(0,$imageName.indexOf(':')+1)+$version.ToLowerInvariant())
            docker pull $image2
            Get-BcContainerNavVersion -containerOrImageName $image2 | Should -Be $version
            Get-BcContainerNavVersion -containerOrImageName $imageName | Should -Be $version
        }
    }
}  